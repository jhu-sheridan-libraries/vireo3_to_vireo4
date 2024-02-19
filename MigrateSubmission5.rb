require 'pg'
require 'time'
require 'open3'
require 'fileutils'

require_relative 'MigrateGlobal.rb'
#require_relative 'SiteSpecific.rb'
require_relative 'SiteSpecific.rb'

=begin
mapSubmission:
  Create V4.submission from V3.submission, mapping V3.college,V3.department,V3.program to a V4.organization.  This also requires the creation of V4.submission_workflow_step and V4.submission_submission_workflow_steps entries.

  Most of the data in V3.submission is stored in V4.field_value and V4.submission_field_value entries via the updateSubmissionFV() method.

  The V4.submission fields approve_advisor, approve_advisor_date, approve_application, approve_application_date, approve_embargo, and approve_embargo_date are updated from V3.action_log.

  V4.submission_workflow_step and V4.submission_submission_workflow_steps are filled based on organization ancestors in V4.organization.

  V4.submission is further updated with assignee_id.

fieldValueExtras:
  Other V4.field_value and V4.submission_field_values entries are created based on contact info and address values.

fileUpload:
  For each V4.submission record the V3.attachment records are searched for documents.  Each of these documents are categorized by mime type (guessed) and are copied from the V3 data structure to a new V4.data structure under a path determined by the submitter's email address (as calculated by getJavaHash() which calls a java program.

  A V4.field_value and V4.submission_field_value entry is made for each file.

=end

module VIREO
  DEST_SUBDIR = "private/"
  module Map
    class << self
      @@duplicateFieldPredicateList = [1, 2, 3, 5, 6, 7, 8, 34, 35]
      #######################
      def hasMultipleCoChairs()
        cochairSelect = "SELECT DISTINCT(roles) FROM committee_member_roles;"
        v3ccRS = VIREO::CON_V3.exec cochairSelect
        v3ccRS.each do |row|
          if (row['roles'] == 'Co-Chair')
            puts "CO CHAIR TRUE"
            return true
          end
        end
        puts "CO CHAIR FALSE"
        return false
      end

      def setRepeatInAbstractFieldProfile(pred_id, val)
        if (VIREO::REALRUN)
          afpUpdate = "UPDATE abstract_field_profile SET repeatable = '%s' WHERE field_predicate_id = %s;" % [val,
                                                                                                              pred_id.to_s]
          begin
            v4_afpRS = VIREO::CON_V4.exec afpUpdate
          rescue StandardError => e
            puts "ERROR SETTING Abstract_field_profile TO ALLOW MULTIPLE CO CHAIRS"
            puts afpUpdate
          end
        end
      end

      # #SUBMISSION
      def mapSubmission()
        # if(hasMultipleCoChairs())
        #	@@duplicateFieldPredicateList << 37
        #	setRepeatInAbstractFieldProfile(37,'t')
        # end
        puts "DUP PRED " + @@duplicateFieldPredicateList.to_s
        fpcommittee = "SELECT id FROM field_predicate WHERE value LIKE 'dc.contributor.%';"
        v4fpcRS = VIREO::CON_V4.exec fpcommittee
        begin
          v4fpcRS.each do |row|
            id = row['id'].to_i
            @@duplicateFieldPredicateList << id
            setRepeatInAbstractFieldProfile(id,'t')
          end
        end

        totalExpected = 0
        subCount = "SELECT COUNT(*) FROM submission;"
        v3scRS = VIREO::CON_V3.exec subCount
        begin
          v3scRS.each do |row|
            totalExpected = row['count'].to_i
          end
        end

        submissionSelect = "SELECT s.* FROM submission s;"
        completed = 0
        failed = 0
        v3submissionRS = VIREO::CON_V3.exec submissionSelect
        puts "V3 SUBMISSIONS LIST OF " + v3submissionRS.count.to_s + " SUBMISSIONS AT " + VIREO::INSTITUTION + " ==========================================="
        v3submissionRS.each do |row|
          begin
            organization_id = 1
            college = row['college']
            department = row['department']
            department_id = row['department_id']
            submitter_id = row['submitter_id']
            assignee_id = row['assignee_id']
            deposit_id = row['depositid']
            reviewernotes = row['reviewernotes']
            if(reviewernotes != nil)
              reviewernotes = VIREO::CON_V4.escape_string(reviewernotes)
            end
            documenttype = row['documenttype']
            degreelevel = row['degreelevel']
            degree = row['degreelevel']

            submission_date = row['submissiondate']
            approval_date = row['approvaldate']
            committeeapprovaldate = row['committeeapprovaldate']
            committeeembargoapprovaldate = row['committeeembargoapprovaldate']
            lastactionlogdate = row['lastactionlogdate']
            # #following set into submission_field_values
            licenseagreementdate = row['licenseagreementdate']
            defensedate = row['defensedate']
            # puts "APPR DATE "+approval_date.to_s
            # puts "COMM APPR DATE "+committeeapprovaldate.to_s

            puts "#############################################\n\n"
            if ((submission_date != nil) && (submission_date.length > 10))
              submission_date = submission_date.split(' ')[0].strip()
            end
            if ((approval_date != nil) && (approval_date.length > 10))
              approval_date = approval_date.split(' ')[0].strip()
            end
            puts "V3 SUBMISSION ID " + row['id'].to_s + " SUBDATE " + submission_date.to_s + " APPRDATE " + approval_date.to_s

            program = row['program']
            # program = ''#BECAUSE PEOPLE SET THIS FIELD ERRONEOUSLY IN THIS PARTICULAR SAMPLE DATA SET

            # #START SEARCH FROM MOST SPECIFIC ORGANIZATION AND MOVE UP UNTIL ONE IS LOCATED
            org = orgSearchByDegree(degreelevel, college, department, program)
            # puts "   ORG "+org.to_s

            organization_id = org['organization_id'].to_i
            submission_status_id = 1; # LAST SUB STATUS IN ACTIONLOG FOR THIS SUBMISSION

            submission_id = row['id'];
            if (organization_id.to_i <= 0)
              puts "  ERROR FAILED TO FIND ORG " + org.to_s + " COUNT " + actionLogCount(row['id'].to_i).to_s + " SUBM_ID " + submission_id.to_s
              # puts lastAction(submission_id)
              failed += 1
            else
              puts "  FOR ORG ID " + organization_id.to_s
              sub_id = createSubmission(submission_id, organization_id, submission_status_id, submitter_id, deposit_id,reviewernotes)
              puts "  JUST CREATED SUBMISSION WITH ID " + sub_id.to_s
              if (sub_id == -1)
                puts "CREATE SUB ERROR FOR V3 SUB ID " + submission_id.to_s
                failed += 1
              elsif (sub_id == 0)
                puts "FOUND EXISTING SUBMISSION ERROR FOR V3 SUB ID " + submission_id.to_s
              else
                completed += 1
                # puts "   CREATED SUBMISSION ID "+submission_id.to_s
                sub_id = updateSubmissionDates(submission_id, submission_date, approval_date)
                sub_id = updateSubmissionDatesFromActionlog(submission_id)
                # puts "   UPDATE SUB " +sub_id.to_s+" ROW "+row.to_s
                sub_id = updateSubmissionFV(submission_id, row)
                # puts "   UPDATE SUB FV "+sub_id.to_s
                sub_id = updateSubmissionWFS(submission_id, organization_id)
                # puts "   UPDATE SUB WFS "+sub_id.to_s
                if ((assignee_id != nil) && (assignee_id.length > 0))
                  # puts "   UPDATE SUB ASSIGNEE "+assignee_id.to_s
                  updateSubmissionAssignee(submission_id, assignee_id)
                else
                  puts "   UPDATE SUB ASSIGNEE NOT HAPPENING"
                end
                updateSubmissionMisc(submission_id)
              end
            end
            puts "################"
          rescue StandardError => e
            failed += 1
            puts "MAPSUB EXCEPTION " + e.message
          end
          puts "TOTAL EXPECTED " + totalExpected.to_s + " COMPLETED " + completed.to_s + " FAILED " + failed.to_s
        end
        return { "completed": completed, "failed": failed }
      end

      def updateSubmissionAssignee(submission_id, assignee_id)
        subUpdate = "UPDATE submission SET assignee_id = %s WHERE id = %s;" % [assignee_id, submission_id]
        # puts "SUB UPDATE ASSIGN "+subUpdate
        v4_subRS = VIREO::CON_V4.exec subUpdate
      end

      def createSubmission(id, organization_id, submission_status_id, submitter_id, deposit_id,reviewernotes)
        # UTILITY FOR BUILDING V4.SUBMISSION
        ## ONLY NEED TO LOOK FOR ID AS ALL FIELDS ARE IMMUTABLE EXCEPT SUBMISSION_STATUS_ID AND THAT IS SET IN MigrateActionLog.rb
        # puts "DEPOSITID "+deposit_id.to_s
        # submissionFind = "SELECT id,submission_date FROM submission WHERE organization_id=%s AND submitter_id=%s;" % [organization_id,submitter_id]
        # THE QUERY ABOVE MAY GET CONFUSED WITH A STUDENTS UNFINISHED SUBMISSION AND COULD CAUSE THEM PROBLEMS LATER
        submissionFind = "SELECT id,submission_date FROM submission WHERE id=%s AND organization_id=%s AND submitter_id=%s;" % [
          id, organization_id, submitter_id
        ]
        v4_submissionF = VIREO::CON_V4.exec submissionFind
        if ((v4_submissionF != nil) && (v4_submissionF.count > 0))
          # puts "SUBMISSION FIND "+submissionFind
          # v4_submissionF.each do |row|
          #	puts "V4 FOUND EXISTING SUBMISSION "+row.to_s
          #	if(row['id']==id)
          #		puts "NORMAL"
          #	else
          #		puts "FOUND DUPLICATE!!!!!!! "
          #	end
          # end
          return v4_submissionF[0]['id'].to_i
        else
          sub_id = -1
          if (VIREO::REALRUN)
            submissionInsert = "INSERT INTO submission (id,organization_id,submission_status_id,submitter_id,depositurl,reviewer_notes) VALUES(%s,%s,%s,%s,'%s','%s') RETURNING id;" % [
              id, organization_id, submission_status_id, submitter_id, deposit_id,reviewernotes ]
            puts "SUB " + submissionInsert.to_s
            begin
              v4_submissionRS = VIREO::CON_V4.exec submissionInsert
              if ((v4_submissionRS != nil) && (v4_submissionRS.count > 0))
                sub_id = v4_submissionRS[0]['id'].to_i
                puts "V4 CREATED SUBMISSION WITH ID " + sub_id.to_s
              end
            rescue StandardError => e
              puts "\nFAILED SUBMISSION " + submissionInsert + " ERR " + e.message;
              showOldSubDetails(id);
              sub_id = -1
            end
          else
            sub_id = 0
          end
          return sub_id
        end
      end

      def showOldSubDetails(id)
        oldsubSelect = "SELECT s.id,s.submitter_id,s.lastactionlogdate,s.documentabstract,s.documentkeywords,s.documenttitle FROM submission s WHERE s.id=%s;" % [id]
        completed = 0
        failed = 0
        begin
          v3oldsubRS = VIREO::CON_V3.exec oldsubSelect
          v3oldsubRS.each do |row|
            puts "V3 SUB " + row.to_s
          end
        rescue StandardError => e
          puts "OLD SUB EXCEPTION " + e.message
        end
      end

      def genInd()
        afp_max_id = 0
        wsafpList = "SELECT * FROM workflow_step_aggregate_field_profiles ORDER BY aggregate_field_profiles_id;"
        v4_fpF = VIREO::CON_V4.exec wsafpList
        # arr = Array.new(4,Array.new)
        ind1 = Array.new()
        ind2 = Array.new()
        ind3 = Array.new()
        ind4 = Array.new()
        afp_max_id = v4_fpF.count
        puts "AFP " + afp_max_id.to_s
        v4_fpF.each do |fp|
          ws_id = fp['workflow_step_id'].to_i
          afp_id = fp['aggregate_field_profiles_id'].to_i
          afp_order = fp['aggregate_field_profiles_order']
          puts "AFP WS " + (ws_id - 1).to_s + " << " + (afp_max_id.to_i + afp_id).to_s
          # arr[(ws_id-1).to_i] << (afp_max_id+afp_id).to_i
          if (ws_id == 1)
            ind1 << (afp_max_id + afp_id).to_i
          elsif (ws_id == 2)
            ind2 << (afp_max_id + afp_id).to_i
          elsif (ws_id == 3)
            ind3 << (afp_max_id + afp_id).to_i
          elsif (ws_id == 4)
            ind4 << (afp_max_id + afp_id).to_i
          end
        end
        return [ind1, ind2, ind3, ind4]
      end

      def updateSubmissionWFS(submission_id, organization_id)
        begin
          arr = genInd()
          ind_0 = arr[0]
          ind_1 = arr[1]
          ind_2 = arr[2]
          ind_3 = arr[3]

          # enter an array of records for each submission_workflow_step based on its index.
          # ind_0 = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18]
          # ind_1 = [19,20]
          # ind_2 = [21,22,23,24,25,26,27,28,29,30,31,32,32]
          # ind_3 = [33,34,35,36,37,38,39,40]

          # WORKING_PLAIN
          # ind_0 = [42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59]
          # ind_1 = [60,61]
          # ind_2 = [62,63,64,65,66,67,68,69,70,71,72,73,74]
          # ind_3 = [75,76,77,78,79,80,81,82]

          # CO_CHAIR
          # ind_0 = [43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60]
          # ind_1 = [61,62]
          # ind_2 = [63,64,65,66,67,68,69,70,71,72,73,74,75,76]
          # ind_3 = [77,78,79,80,81,82,83,84]

          # #get array of workflow_steps for organization_id or its parent
          wfsSelect = "SELECT id,instructions,name,overrideable FROM workflow_step WHERE originating_organization_id = 1;" % [organization_id]
          ## Eventually work up the hierarchy to find a valid org

          v4_wfsRS = VIREO::CON_V4.exec wfsSelect
          v4_wfsRS.each_with_index do |wfs, indx|
            # enter a copy of each workflow_step into submission_workflow_step for each submission
            swfsFind = "SELECT id FROM submission_workflow_step where instructions='%s' AND name='%s' AND overrideable='%s';" % [
              wfs['instructions'], wfs['name'], wfs['overrideable']
            ]
            v4_swfsF = VIREO::CON_V4.exec swfsFind
            swfs_id = 0
            if ((v4_swfsF != nil) && (v4_swfsF.count > 0))
              swfs_id = v4_swfsF[0]['id'].to_i
              puts "  V4 FOUND SWFS "+swfs_id.to_s
            else
              swfs_id = 0
              if (VIREO::REALRUN)
                swfsInsert = "INSERT INTO submission_workflow_step VALUES(DEFAULT,'%s','%s','%s') RETURNING id;" % [ wfs['instructions'], wfs['name'], wfs['overrideable'] ]
                v4_swfsRS = VIREO::CON_V4.exec swfsInsert
                puts "SWFS INSERT "+swfsInsert
		#FSS
                #swf_ids = v4_swfsRS[0]['id'].to_i
                swfs_id = v4_swfsRS[0]['id'].to_i
              end
              puts "  V4 CREATED SWFS "+swfs_id.to_s
            end

            if (swfs_id != 0)
              # enter a record for each submission and submission_workflow_step pair
              sswfsFind = "SELECT * FROM submission_submission_workflow_steps WHERE submission_id=%s AND submission_workflow_steps_id=%s AND submission_workflow_steps_order=%s;" % [
                submission_id.to_s, swfs_id.to_s, indx.to_s
              ]
              v4_sswfsF = VIREO::CON_V4.exec sswfsFind
              if ((v4_sswfsF != nil) && (v4_sswfsF.count > 0))
                sswfs_id = v4_sswfsF[0]['submission_id'].to_i
                puts "  V4 FOUND SSWFS For SubmissionID "+sswfs_id.to_s
              else
                if (VIREO::REALRUN)
                  sswfsInsert = "INSERT INTO submission_submission_workflow_steps VALUES(%s,%s,%s);" % [submission_id.to_s,
                                                                                                        swfs_id.to_s, indx.to_s]
                  puts "SSWFS INSERT "+sswfsInsert
                  v4_sswfsRS = VIREO::CON_V4.exec sswfsInsert
                  puts "V4 CREATED SSWFS INSERT "
                end
              end

              # Get last index in submission_workflow_step_aggregate_field_profiles
              swsafpiSelect = "SELECT MAX(submission_workflow_step_id) FROM submission_workflow_step_aggregate_field_profiles;"
              v4_swsafpiRS = VIREO::CON_V4.exec swsafpiSelect
              lastIndex = v4_swsafpiRS[0]['max'].to_i
              puts "LAST INDEX "+lastIndex.to_s
              # puts "DONE CREATING SSWS"

              # this can be more efficient -fix later
              if (indx == 0)
                ind_0.each_with_index do |afp, orderindx|
                  createSWSAFP(swfs_id, afp, orderindx)
                end
              end
              if (indx == 1)
                ind_1.each_with_index do |afp, orderindx|
                  createSWSAFP(swfs_id, afp, orderindx)
                end
              end
              if (indx == 2)
                ind_2.each_with_index do |afp, orderindx|
                  createSWSAFP(swfs_id, afp, orderindx)
                end
              end
              if (indx == 3)
                ind_3.each_with_index do |afp, orderindx|
                  createSWSAFP(swfs_id, afp, orderindx)
                end
              end
            end
          end
          return 0
        rescue StandardError => e
          puts "\nFAILED UPDATE WFS " + e.message;
          return -1
        end
      end

      def createSWSAFP(swfs_id, afp, orderindx)
        puts "SWSAFP AFP "+afp.to_s
        swsafpFind = "SELECT * FROM submission_workflow_step_aggregate_field_profiles WHERE submission_workflow_step_id=%s AND aggregate_field_profiles_id=%s AND aggregate_field_profiles_order=%s;" % [
          swfs_id.to_s, afp.to_s, orderindx.to_s
        ]
        puts "SWSAFP SELECT "+swsafpFind.to_s
        v4_swsafpF = VIREO::CON_V4.exec swsafpFind
        if ((v4_swsafpF != nil) && (v4_swsafpF.count > 0))
          swfs_id = v4_swsafpF[0]['submission_workflow_step_id'].to_i
          puts "    V4 FOUND SSWFAP For INDX " +orderindx.to_s+" SubmissionWorkflowStepID "+swfs_id.to_s
        else
          if (VIREO::REALRUN)
            swsafpInsert = "INSERT INTO submission_workflow_step_aggregate_field_profiles (submission_workflow_step_id,aggregate_field_profiles_id,aggregate_field_profiles_order) VALUES(%s,%s,%s);" % [
              swfs_id.to_s, afp.to_s, orderindx.to_s
            ]
            puts "    V4 CREATED SWSAFP FOR INDX "+orderindx.to_s
            v4_swsafpRS = VIREO::CON_V4.exec swsafpInsert
          end
        end
      end

      def updateSubmissionFV(submission_id, v3row)
        # BIRTH YEAR SHOULD INSTEAD COME FROM person.birthyear BUT IS SPARSELY POPULATED ANYWAY
        updateSFVUtility(submission_id, "birth_year", v3row['studentbirthyear']);
        updateSFVUtility(submission_id, "previously_published_material", v3row['publishedmaterial']);
        updateSFVUtility(submission_id, "dc.language.iso", v3row['documentlanguage']);
        updateSFVUtility(submission_id, "thesis.degree.college", v3row['college']);
        updateSFVUtility(submission_id, "thesis.degree.department", v3row['department']);
        updateSFVUtility(submission_id, "dc.description.abstract", v3row['documentabstract']);
        # updateSFVUtility(submission_id,"keywords",v3row['documentkeywords']);
        keywords = v3row['documentkeywords'];
        if (keywords != nil)
          kwa = keywords.split(";")
          kwa.each do |k|
            updateSFVUtility(submission_id, "keywords", k);
          end
        end
        updateSFVUtility(submission_id, "dc.title", v3row['documenttitle']);
        updateSFVUtility(submission_id, "thesis.degree.major", v3row['major']);
        updateSFVUtility(submission_id, "first_name", v3row['studentfirstname']);
        updateSFVUtility(submission_id, "last_name", v3row['studentlastname']);
        updateSFVUtility(submission_id, "middle_name", v3row['studentmiddlename']);
        updateSFVUtility(submission_id, "thesis.degree.program", v3row['program']);
        updateSFVUtility(submission_id, "local.etdauthor.orcid", v3row['orcid']);

        updateSFVUtility(submission_id, "defense_date", v3row['defensedate']);
        # license_agreement field_predicate_id:27
        # puts "SUB "+submission_id+" LIC AGR "+v3row['licenseagreementdate'].to_s+" UMI "+v3row['umirelease'].to_s

        if ((v3row['licenseagreeementdate'].to_s != nil) && (v3row['licenseagreementdate'].to_s.length > 1))
          updateSFVUtility(submission_id, "license_agreement", "true");
          puts "    LA TRUE"
        else
          updateSFVUtility(submission_id, "license_agreement", "false");
          puts "    LA FALSE"
        end
        # umi_publication field_predicate_id:28 (proquest)
        if (v3row['umirelease'].to_s == 't')
          updateSFVUtility(submission_id, "umi_publication", "true");
          puts "    UM TRUE"
        else
          updateSFVUtility(submission_id, "umi_publication", "false");
          puts "    UM FALSE"
        end

        updateSFVUtility(submission_id, "thesis.degree.name", v3row['degree']);

        graduationmonth = v3row['graduationmonth'].to_s
        graduationyear = v3row['graduationyear'].to_s
        # puts "GRADMONTH SUBID "+submission_id.to_s+" MO "+graduationmonth+" YR "+graduationyear
        if ((graduationmonth.length > 0) && (graduationyear.length > 3))
          graduationdatestr = Time.parse(graduationyear.to_s + "-" + (graduationmonth.to_i + 1).to_s + "-01").to_s
          graduationTS = graduationdatestr[0..10].strip!
          # presumably due to GMT and daylight savings time Dec,Jan,Feb,Mar need T06, all others T05
          if ((graduationmonth.to_i == 11) || (graduationmonth.to_i < 3))
            graduationTS = graduationTS + "T06:00:00.000Z"
          else
            graduationTS = graduationTS + "T05:00:00.000Z"
          end
          # puts "   GRADMONTH TS "+graduationTS
          updateSFVUtility(submission_id, "dc.date.issued", graduationTS)
        end
        updateSFVUtility(submission_id, "submission_type", v3row['documenttype'])

        wu_id = getInstId(v3row['submitter_id'])
        updateSFVUtility(submission_id, "institutional_id", wu_id)
      end

      def InstIdOnly()
        fixCount = "SELECT id,submitter_id FROM submission;"
        v4fixRS = VIREO::CON_V4.exec fixCount
        begin
          v4fixRS.each do |row|
            wu_id = getInstId(row['submitter_id'].to_i)
            updateSFVUtility(row['id'].to_i, "institutional_id", wu_id)
          end
        end
      end

      def getInstId(person_id)
        iiSelect = "SELECT institutionalidentifier FROM person WHERE id = '%s';" % [person_id]
        v3_iiRS = VIREO::CON_V3.exec iiSelect
        inst_id = nil
        v3_iiRS.each do |ii|
          inst_id = ii['institutionalidentifier']
        end
        return inst_id;
      end

      def updateSubmissionMisc(submission_id)
        # ADVISOR
        # pSelect = "SELECT cmr.roles,cm.firstname,cm.middlename,cm.lastname FROM committee_member cm, committee_member_roles cmr WHERE cmr.jpacommitteememberimpl_id = cm.id AND cm.submission_id = %s;" % [submission_id]
        pSelect = "SELECT cm.id,cm.firstname,cm.middlename,cm.lastname FROM committee_member cm WHERE cm.submission_id = %s;" % [submission_id]
        puts "SUB QUERY " + pSelect
        v3_pRS = VIREO::CON_V3.exec pSelect
        v3_pRS.each do |p|
          cm_id = p['id'].to_s
          firstname = p['firstname'].to_s
          middlename = p['middlename'].to_s
          lastname = p['lastname'].to_s
          roles = "Member"
          roleSelect = "SELECT roles FROM committee_member_roles WHERE jpacommitteememberimpl_id = %s LIMIT 1;" % [cm_id.to_s]
          v3_rRS = VIREO::CON_V3.exec roleSelect
          v3_rRS.each do |r|
            roles = r['roles']
          end

          puts "SUBID "+submission_id.to_s+" ADVISOR ROLE "+roles+" FN "+firstname+" LN "+lastname
          if (roles == nil)
          elsif (roles == 'Chair')
            updateSFVUtility(submission_id, "dc.contributor.advisor", lastname + ", " + firstname + " " + middlename)
          elsif (roles == 'Co-Chair')
            updateSFVUtility(submission_id, "dc.contributor.advisor.Co-Chair",
                             lastname + ", " + firstname + " " + middlename)
          elsif (roles == 'Member')
            updateSFVUtility(submission_id, "dc.contributor.committeeMember",
                             lastname + ", " + firstname + " " + middlename)
          else
            String new_field_predicate = getNewContributorRole(roles)
            updateSFVUtility(submission_id, new_field_predicate, "#{lastname}, #{firstname} #{middlename}")
          end
        end

        # DEFAULT_EMBARGO
        embSelect = "SELECT DISTINCT e.name,e.guarantor FROM embargo_type e, submission_embargotypes se WHERE e.id=se.embargotypeids AND se.submission_id = %s;" % [submission_id]
        # puts "EMBARGO SELECT "+embSelect;
        v3_embRS = VIREO::CON_V3.exec embSelect
        v3_embRS.each do |emb|
          embargo_name = emb['name'].to_s
          guarantor = emb['guarantor'].to_i
          # puts "DEF ID "+submission_id.to_s+" EMB NAME "+embargo_name+" GUAR "+guarantor.to_s
          if (guarantor == 0)
            updateSFVUtility(submission_id, "default_embargos", embargo_name)
          elsif (guarantor == 1)
            updateSFVUtility(submission_id, "proquest_embargos", embargo_name)
          elsif puts "ERROR/UNKNOWN EMBARGO TYPE GUARANTOR " + guarantor.to_s
          end
        end

        # SUBMISSION SUBJECTS
        ssSelect = "SELECT documentsubjects,documentsubjects_order from submission_subjects WHERE jpasubmissionimpl_id = %s ORDER BY documentsubjects_order;" % [submission_id]
        # puts "SUBMISSION SUBJECTS SELECT "+ssSelect;
        v3_ssRS = VIREO::CON_V3.exec ssSelect
        v3_ssRS.each do |ss|
          updateSFVUtility(submission_id, "dc.subject", ss['documentsubjects']);
        end
      end

      def getNewContributorRole(roles)
        puts "ANCR SHOULD BE ENTERED ONLY ONCE"
        String contigRoleString = roles.gsub(' ', '')
        puts "ANCR CONTIG " + contigRoleString
        String new_field_predicate = "dc.contributor"

        if (contigRoleString.include?("Advisor"))
          new_field_predicate += ".advisor."
        elsif (contigRoleString.include?("Director"))
          new_field_predicate += ".advisor."
        elsif (contigRoleString.include?("Chair"))
          new_field_predicate += ".advisor."
        elsif (contigRoleString.include?("Supervisor"))
          new_field_predicate += ".advisor."
        else
          new_field_predicate += ".committeeMember."
        end
        vp_id = 0
        new_field_predicate += contigRoleString
        return new_field_predicate;
      end

      def fieldValueExtras()
        # get data from v4 since address will already have been parsed
        fvSelect = "SELECT s.id, w.username, ci.email, cip.email AS permanent_email, ci.phone, cip.phone AS permanent_phone FROM submission s, weaver_users w, contact_info ci, contact_info cip WHERE s.submitter_id = w.id AND w.current_contact_info_id = ci.id AND w.permanent_contact_info_id = cip.id;"
        v4_fvRS = VIREO::CON_V4.exec fvSelect
        v4_fvRS.each do |fv|
          puts "\n\nCONTACT###############################"
          submission_id = fv['id'].to_s
          current_email = fv['email'].to_s
          permanent_email = fv['permanent_email'].to_s
          current_phone = fv['phone'].to_s
          permanent_phone = fv['permanent_phone'].to_s
          puts "SUBM ID " + submission_id + " CURR EMAIL " + current_email + " PERM EMAIL " + permanent_email + " CURR PHONE " + current_phone + " PERM PHONE " + permanent_phone
          updateSFVUtility(submission_id, "email", current_email)
          updateSFVUtility(submission_id, "permanent_email", permanent_email)
          updateSFVUtility(submission_id, "current_phone", current_phone)
          updateSFVUtility(submission_id, "permanent_phone", permanent_phone)
        end

        # #address in single text blob format
        fvaSelect = "SELECT s.id, p.currentpostaladdress, p.permanentpostaladdress FROM person p, submission s WHERE s.submitter_id = p.id;"
        v3_fvaRS = VIREO::CON_V3.exec fvaSelect
        v3_fvaRS.each do |fva|
          puts "\n\nADDRESS###############################"
          submission_id = fva['id'].to_s
          current_address = fva['currentpostaladdress'].to_s
          permanent_address = fva['permanentpostaladdress'].to_s
          puts "ID " + submission_id + " CURR ADDR " + current_address + " PERM ADDR " + permanent_address
          if ((current_address != nil) && (current_address.length > 0))
            updateSFVUtility(submission_id, "current_address", current_address)
          end
          if ((permanent_address != nil) && (permanent_address.length > 0))
            updateSFVUtility(submission_id, "permanent_address", permanent_address)
          end
        end
        return "DONE FieldValueExtras"
      end

      #########################
      # ##FileUpload
      # #V3 files are in /ebs/vireo/data/attachments/ with 4 deep subdirectories representing the 4 pairs of the first part of the file hash
      ##	Files are found by the submission_id on the attachment table.  The filename and mime type are in the name field separated by '|'
      # #V4 files uses java hashCode() on the email address to determine directory under:
      ##	documentPath = "/opt/vireo/"
      ##	dest_subdir = "private/'
      ##
      ##	license files are put in documentPath+hash_of_email_addr+"/"+System.currenTimeMillis()+"-"+filename+".txt"
      ##	as done in model/repo/impl/SubmissionRepoImpl.java
      ##
      ##	primary files are put in documentPath+hash_of_email_addr+"/"+System.currenTimeMillis()+"-"+lastname.upcase+"-"+"PRIMARY"+"-"+current_calendar_year+mime_type (e.g.".pdf")
      ##	as done in controller/SubmissionController.java
      ##	the url 'private/hash/[timestamp]-[name]-PRIMARY-[YEAR].pdf is stored in table field_value with field_predicate_id = 4
      ##
      ##
      ##
      # #if you need to cd into a dir with a '-' prefix use
      ##	cd -- "-19383038"
      ##
      # #type might correspond to field_predicate value
      ## type 0 - mods.xml sword.xml
      ## type 1 - primary
      ## type 2 -mpeg-4, ppt, mpg
      ## type 3 - license.txt
      ## type 4 - primary archived?
      ## type 5 - submission_log.csv
      ## type 6 - electronic thesis submission checklist
      ##
      ##
      ##
      ## show directory size
      ##		du -sh [dirname]
      ## show system space
      ##		df -hT
      ##

      def fileUpload()
        test_path = getJavaHash("nobody@example.com")
        if (test_path.to_i == -1)
          puts "hash.java needs to be compiled"
          return "hash.java needs to be compiled"
        end

        subSelect = "SELECT s.id,s.depositurl,w.email,w.last_name from submission s, weaver_users w WHERE s.submitter_id = w.id;"
        v4_subRS = VIREO::CON_V4.exec subSelect
        puts "V4 SUBMISSIONS LIST OF " + v4_subRS.count.to_s
        # puts "COPY FROM "+VIREO::BASE_DIR_V3+" TO "+VIREO::BASE_DIR_V4+"/"+VIREO::DEST_SUBDIR

        totalExpected = v4_subRS.count.to_i
        completed = 0

        v4_subRS.each do |sub|
          v4submission_id = sub['id']
          v4email = sub['email']
          v4lastname = sub['last_name']
          puts "\n======================================================"
          puts "TOTAL FILEUPLOAD EXPECTED SUBMISSIONS " + totalExpected.to_s + " STARTING " + completed.to_s
          puts "  V4 SUB ID " + sub['id'].to_s + " " + sub['depositurl'].to_s
          # find filename in V3 submission
          attachSelect = "SELECT submission_id,type,data,name,date from attachment WHERE submission_id = %s;" % [v4submission_id.to_s]
          v3_attachRS = VIREO::CON_V3.exec attachSelect
          v3_attachRS.each do |attach|
            type_string = attach['type'].to_s
            data_string = attach['data'].to_s
            name_string = attach['name'].to_s
            ds_array = data_string.split("|")
            doc_id = ds_array[0].to_s
            doc_mt = ds_array[1].to_s
            v3path = doc_id[0..1] + "/" + doc_id[2..3] + "/" + doc_id[4..5] + "/" + doc_id[6..7] + "/" + doc_id
            src_path = VIREO::BASE_DIR_V3 + v3path
            if (File.file?(src_path))
              src_date = File.mtime(src_path)
              src_size = File.size(src_path)
              puts "++++++++++"
              puts "V3 LOCAL SOURCE DATE " + src_date.to_s + " SIZE " + src_size.to_s + " FILE " + src_path.to_s
              dest_path = VIREO::DEST_SUBDIR + getJavaHash(v4email) + "/"
              begin
                FileUtils.mkdir_p(VIREO::BASE_DIR_V4 + dest_path)
              rescue StandardError => e
                puts "FILE MKDIR ERR " + e.message
              end

              dest_filename = nil
              dest_filename_type1base = nil
              if (type_string == "1")
                year_string = Date.today.year.to_s
                time_in_millis = DateTime.now.strftime('%Q').to_s
                file_suffix = getSuffixFromMimeType(doc_mt, name_string)
                dest_filename_type1base = "-" + v4lastname.upcase + "-" + "PRIMARY" + "-" + year_string + "-" + type_string + file_suffix
                dest_filename = time_in_millis + dest_filename_type1base
              else
                dest_filename = name_string
              end

              fieldPredicateString = "_doctype_unknown";
              if (type_string == "0")
                fieldPredicateString = "_doctype_administrative";
              elsif (type_string == "1")
                fieldPredicateString = "_doctype_primary";
              elsif (type_string == "2")
                fieldPredicateString = "_doctype_supplemental";
              elsif (type_string == "3")
                fieldPredicateString = "_doctype_license";
              elsif (type_string == "4")
                fieldPredicateString = "_doctype_archived";
              elsif (type_string == "5")
                fieldPredicateString = "_doctype_source";
              elsif (type_string == "6")
                fieldPredicateString = "_doctype_administrative";
              elsif (type_string == "7")
                fieldPredicateString = "_doctype_feedback";
              end

              puts "      LOCAL DEST_FILENAME " + dest_filename + " FIELDPRED " + fieldPredicateString
              begin
                look_for = File.join(VIREO::BASE_DIR_V4, dest_path, "*#{dest_filename}")
                if (type_string == "1")
                  look_for = File.join(VIREO::BASE_DIR_V4, dest_path, "*#{dest_filename_type1base}")
                end
                puts "LOOKING FOR " + look_for.to_s
                find_file = Dir[look_for]
                copy_file = false
                file_present = false
                if ((find_file != nil) && (find_file.count > 0))
                  find_file.each do |f|
                    found_file_date = File.mtime(f)
                    found_file_size = File.size(f)
                    found_file_name = File.basename(f)
                    file_present = true
                    puts "          FOUND: " + f.to_s
                    # puts "           SIZE FOUND: "+found_file_size.to_s+" SRC "+src_size.to_s
                    # puts "           DATE FOUND: "+found_file_date.to_s+" SRC "+src_date.to_s
                    if ((found_file_date < src_date) || (src_size != found_file_size))
                      puts "          !!!!OUTDATED"
                      copy_file = true
                    else
                      puts "          !!!!NOT OUTDATED"
                      puts "FOUND    NAME " + found_file_name
                      updateSFVUtility(
                        v4submission_id, fieldPredicateString, dest_path + found_file_name
                      );
                    end
                  end
                else
                  puts "         !!! NOT FOUND "
                  copy_file = true
                end
                puts "FILE COPY: " + src_path + " TO " + VIREO::BASE_DIR_V4 + dest_path + dest_filename + " FIELDPRED " + fieldPredicateString
                if (copy_file)
                  FileUtils.cp(src_path, VIREO::BASE_DIR_V4 + dest_path + dest_filename)
                  updateSFVUtility(v4submission_id, fieldPredicateString, dest_path + dest_filename);
                  file_present = true
                  puts "         !!! SO FILE COPIED "
                else
                  puts "         !!! NOT COPIED "
                end
              # if(file_present)
              #	updateSFVUtility(v4submission_id,fieldPredicateString,dest_path+dest_filename);
              # end
              rescue StandardError => e
                puts "FIELD PREDICATE STRING " + e.message
              end
              puts "----------"
            else
              # files often not found in testing as whole setup not present
              puts "++++++++++"
              puts "  V3 CANNOT FIND FILE AT " + src_path.to_s
              puts "----------"
            end
          end
          completed += 1
        end
        return "complete"
      end

      def getJavaHash(email_addr)
        # java's hashCode() uses a different algorithm than ruby hash so we call a java implementation
        cmd = "java hash %s" % [email_addr]
        # puts "CMD "+cmd
        stdout_str, stderr_str, status = Open3.capture3(cmd)
        if (status.success?)
          return stdout_str.to_s
        else
          return "-1"
        end
      end

      def getSuffixFromMimeType(doc_mt, name)
        # doc_mt.slice! "charset=utf-8"
        file_suffix = ".nil"
        if (doc_mt == nil)
          file_suffix = ".nil"
        elsif (doc_mt.start_with?("application/pdf"))
          file_suffix = ".pdf"
        elsif (doc_mt.start_with?("text/plain"))
          file_suffix = ".txt"
        elsif (doc_mt.start_with?("video/quicktime"))
          file_suffix = ".mov"
        elsif (doc_mt.start_with?("application/octet-stream"))
          # use suffix from doc
          sffx = name.split(".")
          if ((sffx != nil) && (sffx.size > 1))
            file_suffix = "." + sffx[1]
          else
            file_suffix = ".doc"
          end
        elsif (doc_mt.start_with?("application/mspowerpoint"))
          file_suffix = ".ppt"
        elsif (doc_mt.start_with?("image/jpeg"))
          file_suffix = ".jpeg"
        elsif (doc_mt.start_with?("image/jpg"))
          file_suffix = ".jpg"
        elsif (doc_mt.start_with?("video/mp4"))
          file_suffix = ".mp4"
        elsif (doc_mt.start_with?("video/mpeg"))
          file_suffix = ".mpg"
        elsif (doc_mt.start_with?("video/x-msvideo"))
          file_suffix = ".avi"
        elsif (doc_mt.start_with?("text/xml"))
          file_suffix = ".xml"
        elsif (doc_mt.start_with?("application/vnd.oasis.opendocument.text"))
          file_suffix = ".odt"
        elsif (doc_mt.start_with?("application/vnd.openxmlformats-officedocument.wordprocessingml.document"))
          file_suffix = ".docx"
        elsif (doc_mt.start_with?("application/zip"))
          file_suffix = ".zip"
        elsif (doc_mt.start_with?("application/excel"))
          file_suffix = ".xls"
        else
          file_suffix = ".UNK"
        end
        return file_suffix
      end
      # ##FileUpload
      #########################

      def updateSFVUtility(submission_id, fieldName, fieldValue)
        if (fieldValue == nil)
          puts "SFVU FN " + fieldName + " IS NULL FOR SUB ID " + submission_id.to_s
          fieldValue = "UNKNOWN"
          return
        else
          fieldValue = VIREO::CON_V4.escape_string(fieldValue)
        end

        pid = findPredicateId(fieldName)
        puts "SFVUTIL ID " + submission_id.to_s + " FN " + fieldName + " PRED_ID " + pid.to_s + " VAL " + fieldValue
        # _doctype_primary = 4
        puts "DUP PRED IN SFVU " + @@duplicateFieldPredicateList.to_s
        if (pid > 0)
          # SEE IF THERE IS A field_value AND submission ASSOCIATION FOR THE GIVEN pid
          fvid = findFieldValueId(submission_id, pid)
          if (fvid < 1)
            fvid = createFieldValue('null', 'null', fieldValue, pid, fieldName)
            puts "  FIELD DOES NOT ALREADY EXIST: create " + fvid.to_s
            if (fvid > 0)
              createSubmissionFieldValues(submission_id, fvid)
            end
          elsif (@@duplicateFieldPredicateList.include? pid)
            fvid = findFieldValueIdByValue(submission_id, pid, fieldValue)
            puts "  FIELD IS A DUPLICATE AS PERMITTED: find " + fvid.to_s
            if (fvid < 1)
              fvid = createFieldValue('null', 'null', fieldValue, pid, fieldName)
              puts "  FIELD IS < 1 : create " + fvid.to_s
              if (fvid > 0)
                createSubmissionFieldValues(submission_id, fvid)
              end
            end
          else
            puts "  FIELD CAN ONLY BE UPDATED NOT DUPLICATED"
            updateFieldValue(fvid, fieldValue)
          end
        end
      end

      def findFieldValueIdByValue(submission_id, pid, fieldValue)
        fvidSelect = "SELECT fv.id FROM field_value fv, submission_field_values sfv WHERE sfv.submission_id = %s AND sfv.field_values_id = fv.id AND fv.field_predicate_id = %s AND fv.value = '%s';" % [
          submission_id.to_s, pid.to_s, fieldValue
        ]
        begin
          v4_fvidRS = VIREO::CON_V4.exec fvidSelect
          return v4_fvidRS[0]['id'].to_i
        rescue
          return -1
        end
      end

      def findFieldValueId(submission_id, pid)
        fvidSelect = "SELECT fv.id FROM submission_field_values sfv,field_value fv WHERE sfv.field_values_id = fv.id AND fv.field_predicate_id = %s AND sfv.submission_id = %s;" % [
          pid, submission_id
        ]
        begin
          v4_fvidRS = VIREO::CON_V4.exec fvidSelect
          return v4_fvidRS[0]['id'].to_i
        rescue
          return -1
        end
      end

      def findPredicateId(field_name)
        predicateSelect = "SELECT id FROM field_predicate WHERE value = '%s';" % [field_name]
        begin
          v4_predRS = VIREO::CON_V4.exec predicateSelect
          return v4_predRS[0]['id'].to_i
        rescue
          return -1
        end
      end

      def updateFieldValue(field_value_id, newvalue)
        vf_id = 0
        if (VIREO::REALRUN)
          fvUpdate = "UPDATE field_value SET value = '%s' WHERE id = %s;" % [newvalue, field_value_id.to_s]
          begin
            v4_fvRS = VIREO::CON_V4.exec fvUpdate
            # puts "      V4 UPDATED FIELD VALUE ID "+v4_fvRS[0]['id'].to_s+" "+fvUpdate;
            vf_id = 1
          rescue StandardError => e
            puts "      TYPICALLY BECAUSE VALUE IS NOT UNIQUE VALUE:" + value
            puts "      V4 FAILED FIELD VALUE " + fvUpdate + " ERR " + e.message
            vf_id = -1
          end
        end
        return vf_id
      end

      def createFieldValue(definition, identifier, value, field_predicate_id, field_name)
        fvFind = "SELECT id FROM field_value WHERE value='%s' AND field_predicate_id=%s;" % [value, field_predicate_id]
        v4_fvF = VIREO::CON_V4.exec fvFind
        # valueDisp = value
        # if(valueDisp.length >75)
        #	valueDisp = valueDisp[0,24]
        # end
        puts "\t" + field_predicate_id.to_s + ": " + field_name

        # if((v4_fvF!=nil)&&(v4_fvF.count > 0))
        #	fv_id = v4_fvF[0]['id'].to_i
        #	puts "\t\tFOUND  field_value.value "+valueDisp
        #	return fv_id
        # else
        vf_id = 0
        if (VIREO::REALRUN)
          fvInsert = "INSERT INTO field_value (id,value,field_predicate_id) VALUES(DEFAULT,'%s',%s) RETURNING id;" % [value,
                                                                                                                      field_predicate_id]
          puts "FIELD_VALUE \t\t" + fvInsert
          begin
            v4_fvRS = VIREO::CON_V4.exec fvInsert
            puts "      V4 CREATED FIELD VALUE ID " + v4_fvRS[0]['id'].to_s + " " + fvInsert;
            vf_id = v4_fvRS[0]['id'].to_i
          rescue StandardError => e
            puts "      TYPICALLY BECAUSE VALUE IS NOT UNIQUE VALUE:" + value
            puts "      V4 FAILED FIELD VALUE " + fvInsert + " ERR " + e.message
            vf_id = -1
          end
        end
        return vf_id
        # end
      end

      def createSubmissionFieldValues(submission_id, field_values_id)
        sfvFind = "SELECT * FROM submission_field_values WHERE submission_id=%s AND field_values_id=%s;" % [submission_id,
                                                                                                            field_values_id]
        v4_sfvF = VIREO::CON_V4.exec sfvFind
        if ((v4_sfvF != nil) && (v4_sfvF.count > 0))
          sfv_id = v4_sfvF[0]['submission_id'].to_i
          puts "      V4 FOUND SUBMISSION_FIELD_VALUES  FOR SUBMISSION " + sfv_id.to_s
        else
          if (VIREO::REALRUN)
            sfvInsert = "INSERT INTO submission_field_values (submission_id,field_values_id) VALUES(%s,%s);" % [submission_id,
                                                                                                                field_values_id]
            begin
              v4_sfvRS = VIREO::CON_V4.exec sfvInsert
              puts "      " + sfvInsert
              puts "      V4 CREATED SUBMISSION_FIELD_VALUES FOR SUBMISSION"
            rescue StandardError => e
              puts "      V4 CREATE SUBMISSION_FIELD_VALUE FAILED " + sfvInsert + " ERR " + e.message;
            end
          end
        end
      end

      def updateSubmissionDates(submission_id, submission_date, approve_application_date)
        ret_sub_id = 0
        next_line = 0
        subUpdate = "UPDATE submission SET"
        valueList = Array.new
        if (submission_date != nil)
          subUpdate += " submission_date='%s'"
          valueList << submission_date
          next_line += 1
        end
        if (next_line > 0)
          subUpdate += ","
        end
        if (approve_application_date != nil)
          subUpdate += " approve_application = %s, approve_application_date='%s'"
          valueList << ['true', approve_application_date]
          next_line += 1
        else
          subUpdate += " approve_application= %s"
          valueList << ['false']
          next_line += 1
        end
        valueList << submission_id
        if (valueList.size > 1)
          subUpdate += " WHERE id= %s RETURNING id;"
          # puts "VALUES "+valueList.flatten.to_s
          queryText = subUpdate % valueList.flatten
          # puts "SUBUPDATE INTO V4 "+queryText
          v4_subupRS  = VIREO::CON_V4.exec queryText
          if ((v4_subupRS != nil) && (v4_subupRS.count > 0))
            ret_sub_id = v4_subupRS[0]['id'].to_i
          else
            ret_sub_id = 0
          end
          # puts "SUBUPDATE "+ret_sub_id.to_s+" WITH "+valueList.flatten.to_s
        end
        return ret_sub_id
      end

      def updateSubmissionDatesFromActionlog(submission_id)
        ret_sub_id = 0
        ap = actionProfileForSubmission(submission_id)
        next_line = 0
        subUpdate = "UPDATE submission SET"
        valueList = Array.new

        # puts "APPROVE_ADV 1 "+ap[:approve_advisor_date].to_s
        if (ap[:approve_advisor_date] != nil)
          subUpdate += " approve_advisor= %s, approve_advisor_date='%s'"
          valueList << [ap[:approve_advisor], ap[:approve_advisor_date]]
          next_line += 1
        else
          subUpdate += " approve_advisor= %s"
          valueList << ['false']
          next_line += 1
        end

        # puts "APPROVE_EMB 1 "+ap[:approve_embargo_date].to_s
        if (ap[:approve_embargo_date] != nil)
          if (next_line > 0)
            subUpdate += ","
          end
          subUpdate += " approve_embargo=%s, approve_embargo_date='%s'"
          valueList << [ap[:approve_embargo], ap[:approve_embargo_date]]
          next_line += 1
        else
          if (next_line > 0)
            subUpdate += ","
          end
          subUpdate += " approve_embargo=%s"
          valueList << ['false']
          next_line += 1
        end

        valueList << submission_id
        if (valueList.size > 1)
          subUpdate += " WHERE id= %s RETURNING id;"
          # puts "VALUES "+valueList.flatten.to_s
          queryText = subUpdate % valueList.flatten
          puts "SUBUPDATE INTO V4 " + queryText
          v4_subupRS = VIREO::CON_V4.exec queryText
          if ((v4_subupRS != nil) && (v4_subupRS.count > 0))
            ret_sub_id = v4_subupRS[0]['id'].to_i
          else
            ret_sub_id = 0
          end
          # puts "SUBUPDATE V4 RET "+ret_sub_id.to_s
        end
        return ret_sub_id
      end

      def actionLogCount(submission_id)
        count = 0
        begin
          alCount = "SELECT count(*) FROM actionlog WHERE submission_id= %s;" % [submission_id]
          # puts "ALC "+alCount.to_s
          v3alRS = VIREO::CON_V3.exec alCount
          count = v3alRS[0]['count']
        rescue StandardError => e
          puts "ACTIONLOG COUNT EXCEPTION " + e.message
        end
        return count;
      end

      def lastAction(submission_id)
        result = nil
        begin
          laSelect = "SELECT actiondate,submissionstate,entry FROM actionlog WHERE submission_id = %s ORDER BY actiondate DESC;" % [submission_id]

          # puts "LAST ACTION "+laSelect.to_s
          v3laRS = VIREO::CON_V3.exec laSelect
          result = v3laRS[0]
        # puts "LAST ACTION "+result.to_s
        rescue StandardError => e
          puts "ACTIONLOG COUNT EXCEPTION " + e.message
        end
        return result
      end

      def actionProfileForSubmission(submission_id)
        approve_advisor = false
        approve_advisor_date = nil
        approve_application = false
        approve_application_date = nil
        approve_embargo = false
        approve_embargo_date = nil
        begin
          alSelect = "SELECT submissionstate,actiondate FROM actionlog WHERE submission_id= %s;" % [submission_id]
          v3alsRS = VIREO::CON_V3.exec alSelect
          v3alsRS.each do |row|
            ss = row['submissionstate']
            dt = row['actiondate']
            case ss
            when "Approved"
              approve_advisor = true
              approve_advisor_date = dt
            when "PendingPublication"
              approve_embargo = true
              approve_embargo_date = dt
            when "Published"
            when "Withdrawn"
            else
            end
          end
        rescue StandardError => e
          puts "ACTIONLOG COUNT EXCEPTION " + e.message
        end
        return { "submission_id": submission_id, "approve_advisor": approve_advisor, "approve_advisor_date": approve_advisor_date,
                 "approve_application": approve_application, "approve_application_date": approve_application_date, "approve_embargo": approve_embargo, "approve_embargo_date": approve_embargo_date }
      end

      def orgSearchByDegree(degreelevel, college, department, program)
        # Since vireo4 now lets administrators design hierarchical organizational structures from which other
        # organizations can inherit, many institutions reconfigure the way vireo represents their organization
        # over what was expressed in vireo3.

        # Because of this, the mapping between an organization and a degree level and other attributes
        # cannot be automatically determined.  The mappings must be expressed here by the person setting up
        # a migration.

        # return id's from organization table
        # org = {}
        # 2: Graduate School, 3:Honors College
        # if(degreelevel == nil)
        #	org['organization_id'] = "1"
        # elsif(degreelevel.to_s == "1")
        #	org['organization_id'] = "3"
        # elsif(degreelevel.to_s == "2")
        #	org['organization_id'] = "2"
        # elsif(degreelevel.to_s == "3")
        #	org['organization_id'] = "2"
        # else
        #	org['organization_id'] = "1"
        # end
        # return org
        #return siteSpecificOrgSearch(degreelevel, college, department, program)
        return siteSpecificOrgSearch(degreelevel, college, department, program)
      end

      def getOrgCategory()
        # #THIS METHOD REDUNDANT WITH SAME NAMED METHOD IN MigrateOrg2.rb

        orgCatSelect = "SELECT id,name FROM organization_category;"
        v4orgCatRS = VIREO::CON_V4.exec orgCatSelect
        orgCat = Hash.new
        v4orgCatRS.each do |oc|
          begin
            orgCat[oc['id']] = oc['name'].to_s
          rescue StandardError => e
            puts "COLL EXCEPTION " + e.message
          end
        end
        return orgCat
      end

      # THIS EVOLVED RATHER THAN BEING DEVISED - IT NEEDS TO BE REBUILT
      def findOrganization(name, category_id)
        # puts "\nNAME "+name+" CAT "+category_id.to_s
        result = {}
        name = VIREO::CON_V4.escape_string(name)
        organizationSearch = "SELECT id,category_id FROM organization WHERE name = '%s' AND category_id = %s;" % [name,
                                                                                                                  category_id]
        # puts "   "+organizationSearch
        v4orgRS = VIREO::CON_V4.exec organizationSearch
        result['name'] = name
        result['category'] = category_id
        v4orgRS.each do |row|
          # puts "ROW "+row.to_s
          result['organization_id'] = row['id']
        end
        # puts "RES "+result.to_s
        return result
      end

      # END submission
      ########################
    end
  end
end

puts "\n\nSUBMISSIONS BEGIN =====================================\n"
puts "SUBMISSION " + VIREO::Map.mapSubmission().to_s
puts "SUBMISSIONS END =====================================\n"
puts "\n\nFIELD VALUE EXTRAS BEGIN =====================================\n"
puts "FIELD_VALUE_EXTRAS " + VIREO::Map.fieldValueExtras().to_s
puts "FIELD VALUE EXTRAS END =====================================\n"

puts "\n\nSUBMISSIONS AND FILE UPLOADS BEGIN =====================================\n"
puts "VIREO::Map.fileUpload() " + VIREO::Map.fileUpload().to_s
puts "SUBMISSIONS AND FILE UPLOADS END =====================================\n"


# puts "\n\nINSTITUTIONAL ID BEGIN=====================================\n"
# puts "VIREO::Map.InstIdOnly() "+VIREO::Map.InstIdOnly().to_s
# puts "\n\nINSTITUTIONAL ID END=====================================\n"
