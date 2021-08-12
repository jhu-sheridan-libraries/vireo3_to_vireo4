require 'pg'
require 'set'

require_relative 'MigrateGlobal.rb'

#  updateCustomActions:
#  Creation of V4.custom_action_definition and V4.custom_action_value entries directly from V3.custom_action_definition and V3.custom_action_value entries.

module VIREO
  module Map
    class << self
      def initializeSettings()
        setManagedConfiguration('hierarchical', 'true')
        setManagedConfiguration('submissions_open', 'true')
        setManagedConfiguration('allow_multiple_submissions', 'true')
      end

      def setManagedConfiguration(name, value)
        if (VIREO::REALRUN)
          begin
            hierSelect = "SELECT name FROM managed_configuration WHERE name = '" + name + "';"
            v4hierSel = VIREO::CON_V4.exec hierSelect
            if ((v4hierSel != nil) && (v4hierSel.count > 0))
              hierUpdate = "UPDATE managed_configuration SET value = '%s' WHERE name = '%s';" % [value, name]
              VIREO::CON_V4.exec hierUpdate
            else
              hierInsert = "INSERT INTO managed_configuration (id,name,type,value) VALUES (DEFAULT,'%s','%s','%s');" % [name,
                                                                                                                        'application', value]
              VIREO::CON_V4.exec hierInsert
            end
          rescue StandardError => e
            puts "HIER EXCEPTION " + e.message
          end
        end
      end

      def updateAbstractFieldProfile()
        afpSelect = "SELECT * from abstract_field_profile WHERE fp_type = 'Org';"
        v4_afpS = VIREO::CON_V4.exec afpSelect
        v4_afpS.each do |row|
          fp_type = "Sub"
          overrideable = ""
          controlled_vocabulary_id = row['controlled_vocabulary_id']
          puts "CVID " + controlled_vocabulary_id.to_s
          originating_workflow_step_id = ""
          createAbstractFieldProfile(fp_type, row['enabled'], row['flagged'], row['gloss'], row['hidden'], row['logged'],
                                     row['optional'], row['repeatable'], overrideable, row['controlled_vocabulary_id'], row['field_predicate_id'], row['input_type_id'], originating_workflow_step_id)
        end
      end

      def createAbstractFieldProfile(fp_type, enabled, flagged, gloss, hidden, logged, optional, repeatable, overrideable, controlled_vocabulary_id, field_predicate_id, input_type_id, originating_workflow_step_id)
        afpFind = "SELECT fp_type,gloss FROM abstract_field_profile WHERE fp_type='%s' AND gloss='%s';" % [fp_type,
                                                                                                           gloss]
        v4_afpF = VIREO::CON_V4.exec afpFind
        if ((v4_afpF != nil) && (v4_afpF.count > 0))
          v4_afpF.each do |row|
            puts "V4 FOUND EXISTING abstract_field_profile " + row.to_s
          end
          return 0
        else
          if (VIREO::REALRUN)
            #						afpInsert = "INSERT INTO abstract_field_profile (fp_type,id,enabled,flagged,gloss,hidden,logged,optional,repeatable,overrideable,controlled_vocabulary_id,field_predicate_id,input_type_id,originating_workflow_step_id) VALUES('%s',DEFAULT,'%s','%s','%s','%s','%s','%s','%s',%s,%s,%s,%s,'%s');" % [fp_type,enabled,flagged,gloss,hidden,logged,optional,repeatable,overrideable,controlled_vocabulary_id,field_predicate_id,input_type_id,originating_workflow_step_id.to_s]
            if ((controlled_vocabulary_id != nil) && (controlled_vocabulary_id.to_i > 0))
              afpInsert = "INSERT INTO abstract_field_profile (fp_type,id,enabled,flagged,gloss,hidden,logged,optional,repeatable,controlled_vocabulary_id,field_predicate_id,input_type_id) VALUES('%s',DEFAULT,'%s','%s','%s','%s','%s','%s','%s',%s,%s,%s);" % [
                fp_type, enabled, flagged, gloss, hidden, logged, optional, repeatable, controlled_vocabulary_id, field_predicate_id, input_type_id
              ]
            else
              afpInsert = "INSERT INTO abstract_field_profile (fp_type,id,enabled,flagged,gloss,hidden,logged,optional,repeatable,field_predicate_id,input_type_id) VALUES('%s',DEFAULT,'%s','%s','%s','%s','%s','%s','%s',%s,%s);" % [
                fp_type, enabled, flagged, gloss, hidden, logged, optional, repeatable, field_predicate_id, input_type_id
              ]
            end
            begin
              v4_afpRS = VIREO::CON_V4.exec afpInsert
              return 1
            rescue StandardError => e
              puts "\nFAILED ABSTRACT_FIELD_PROFILE " + afpInsert + " ERR " + e.message;
              return -1
            end
          end
        end
      end

      ######################
      # UpdateDepositLocation
      def updateDepositLocation()
        if (VIREO::REALRUN)
          deleteDepositLocation()
        end
        dlSelect = "SELECT * FROM deposit_location;"
        dl_count = 0
        v3_dlRS = VIREO::CON_V3.exec dlSelect
        displayorder = 0
        v3_dlRS.each do |dl|
          cdl = createDepositLocation(dl['displayorder'], dl['collection'], dl['depositor_name'], dl['name'], dl['onbehalfof'],
                                      dl['password'], dl['repository'], dl['timeout'], dl['username'], dl['packager'])
          if (cdl > 0)
            dl_count += 1
          end
        end
        return dl_count
      end

      def deleteDepositLocation()
        dlDelete = "TRUNCATE TABLE deposit_location RESTART IDENTITY;"
        v4_embD = VIREO::CON_V4.exec dlDelete
      end

      def createDepositLocation(position, collection, depositor_name, name, on_behalf_of, password, repository, timeout, username, packager)
        dlFind = "SELECT name,repository FROM deposit_location WHERE name='%s' AND repository='%s';" % [name,
                                                                                                        repository]
        password = '' # let admins/users put in the password directly
        v4_dlF = VIREO::CON_V4.exec dlFind
        if ((v4_dlF != nil) && (v4_dlF.count > 0))
          v4_dlF.each do |row|
            puts "V4 FOUND EXISTING DepositLocation " + row.to_s
          end
          return 0
        else
          if (VIREO::REALRUN)
            packager_id = findPackagerByName(packager)
            dlInsert = "INSERT INTO deposit_location (id,position,collection,depositor_name,name,on_behalf_of,password,repository,timeout,username,packager_id) VALUES(DEFAULT,%s,'%s','%s','%s','%s','%s','%s',%s,'%s',%s);" % [position.to_s, collection, depositor_name, name, on_behalf_of, password, repository, timeout.to_s, username, packager_id.to_s]
            begin
              v4_dlRS = VIREO::CON_V4.exec dlInsert
              return 1
            rescue StandardError => e
              puts "\nFAILED DEPOSIT_LOCATION " + dlInsert + " ERR " + e.message;
              return -1
            end
          end
        end
      end

      def findPackagerByName(packager)
        packager_id = 0
        pFind = "SELECT id FROM abstract_packager WHERE name='%s';" % [packager]
        v4_dlF = VIREO::CON_V4.exec pFind
        v4_dlF.each do |row|
          packager_id = row['id'].to_i
        end
        return packager_id
      end

      # #EmbargoType
      def updateEmbargoType()
        # EMBARGO_TABLE
        if (VIREO::REALRUN)
          deleteEmbargo()
        end
        etMaxPos = "SELECT max(position) FROM embargo;"
        v3_mpRS = VIREO::CON_V4.exec etMaxPos
        position = 0
        v3_mpRS.each do |mp|
          position = mp['max'].to_i
        end

        embSelect = "SELECT id,duration,guarantor,active,name,systemrequired,description FROM embargo_type;"
        emb_count = 0
        v3_etRS = VIREO::CON_V3.exec embSelect
        v3_etRS.each do |et|
          # puts " SYSREQ "+et['systemrequired'].to_s
          # if(et['systemrequired'] == 'f')
          puts "ET " + et.to_s
          guarantor = "DEFAULT"
          if (et['guarantor'].to_i == 1)
            guarantor = "PROQUEST"
          end
          position = position + 1
          cet = 0
          # if(et['id'].to_i > 0)
          cet = createEmbargoType(et['id'].to_s, position.to_s, et['description'], et['duration'].to_s,guarantor,et['active'].to_s, et['name'].to_s, et['systemrequired'])
          # end
          if (cet > 0)
            emb_count += 1
          end
          # else
          #	#puts "SYSTEM "+et['name'].to_s
          # end
        end
        return emb_count
      end

      def deleteEmbargo()
        embDelete = "TRUNCATE TABLE embargo RESTART IDENTITY;"
        v4_embD = VIREO::CON_V4.exec embDelete
      end

      def createEmbargoType(id, position, description, duration, guarantor, active, name, system_required)
        description = VIREO::CON_V4.escape_string(description)
        name = VIREO::CON_V4.escape_string(name)
        etFind = "SELECT name, guarantor, system_required FROM embargo WHERE name='%s' AND guarantor='%s' AND system_required='%s';" % [name, guarantor, system_required]
        v4_etF = VIREO::CON_V4.exec etFind
        if ((v4_etF != nil) && (v4_etF.count > 0))
          v4_etF.each do |row|
            puts "V4 FOUND EXISTING EmbargoTyp " + row.to_s
          end
          return 0
        else
          if (VIREO::REALRUN)
            etInsert = "INSERT INTO embargo (id,position,description,duration,guarantor,is_active,name,system_required) VALUES(%s,%s,'%s',%s,'%s','%s','%s','%s');" % [id, position, description, duration, guarantor, active, name, system_required]
            # if((duration==nil)||(duration.length<1))
            etInsert = "INSERT INTO embargo (id,position,description,guarantor,is_active,name,system_required) VALUES(%s,%s,'%s','%s','%s','%s','%s');" % [id, position, description, guarantor, active, name, system_required]
            # end
            puts etInsert
            begin
              v4_etRS = VIREO::CON_V4.exec etInsert
              return 1
            rescue StandardError => e
              puts "\nFAILED EMBARGO_TYPE VALUE " + etInsert + " ERR " + e.message;
              return -1
            end
          end
        end
      end

      def updateEmailTemplate()
        # EMAIL_TEMPLATE_TABLE
        etMaxPos = "SELECT max(position) FROM email_template;"
        v3_mpRS = VIREO::CON_V4.exec etMaxPos
        position = 0
        v3_mpRS.each do |mp|
          position = mp['max'].to_i
        end

        etSelect = "SELECT message,name,subject,systemrequired FROM email_template;"
        et_count = 0
        v3_etRS = VIREO::CON_V3.exec etSelect
        v3_etRS.each do |et|
          if (et['name'].to_s.start_with?("SYSTEM"))
          # puts "SYSTEM "+et['name'].to_s
          else
            position = position + 1
            subject = VIREO::CON_V4.escape_string(et['subject'])
            message = VIREO::CON_V4.escape_string(et['message'])

            cet = createEmailTemplate(position.to_s, message, et['name'], subject, et['systemrequired'])
            if (cet > 0)
              et_count += 1
            end
          end
        end
        return et_count
      end

      def createEmailTemplate(position, message, name, subject, systemrequired)
        etFind = "SELECT name, subject FROM email_template WHERE name='%s' AND subject='%s';" % [
          name, subject
        ]
        v4_etF = VIREO::CON_V4.exec etFind
        if ((v4_etF != nil) && (v4_etF.count > 0))
          v4_etF.each do |row|
            puts "V4 FOUND EXISTING EmailType " + row.to_s
          end
          return 0
        else
          if (VIREO::REALRUN)
            etInsert = "INSERT INTO email_template (id,position,message,name,subject,system_required) VALUES(DEFAULT,%s,'%s','%s','%s','%s');" % [position, message, name, subject, systemrequired]
            # puts etInsert
            begin
              v4_etRS = VIREO::CON_V4.exec etInsert
              return 1
            rescue StandardError => e
              puts "\nFAILED EMAIL_TEMPLATE VALUE " + etInsert + " ERR " + e.message;
              return -1
            end
          end
        end
      end

      def updateEmailWorkflowRule()
        ewrSelect = "SELECT id,associatedstate,displayorder,isdisabled,issystem,recipienttype,admingrouprecipientid,conditionid,emailtemplateid FROM email_workflow_rules;"
        ewr_count = 0
        v3_ewrRS = VIREO::CON_V3.exec ewrSelect
        v3_ewrRS.each do |ewr|
          puts "EWR "+ewr['id'].to_s+" STATE "+ewr['associatedstate'].to_s+" ET_ID "+ewr['emailtemplateid'].to_s
          is_disabled = ewr['isdisabled']
          is_system = ewr['issystem']
          email_recipient_id = ewr['admingrouprecipientid']
          email_template_id = ewr['emailtemplateid']
          submission_status_id = getSubmissionStatusId(ewr['associatedstate'].to_s)
          if(email_template_id != nil)
            createEmailWorkflowRule(is_disabled,is_system,email_recipient_id,email_template_id,submission_status_id)
          end
        end
      end

      def getSubmissionStatusId(associatedstate)
        v4_associatedstate = associatedstate.gsub(/[A-Z]/){|c| ' '+c}.strip
        puts "AAAA "+v4_associatedstate
        ssiFind = "SELECT id FROM submission_status WHERE name = '%s';" % [v4_associatedstate]
        v4_ssiRS = VIREO::CON_V4.exec ssiFind
        v4_ssiRS.each do |ss|
              return ss['id'].to_i
        end
      end

      def adminGroupCounterpart(email_recipient_id)
        #Check V3 for administrative_groups entry with the id = email_recipient_id
        #See if counterpart in V4: (abstract_email_recipient where v3.name = v4.name)
        #dtype = 'EmailRecipientContact'
        #If not, build it.
        #return V4 id
        agFind = "SELECT name FROM administrative_groups WHERE id = %s;" % [email_recipient_id.to_s]
        v3_agF = VIREO::CON_V3.exec agFind
        v3name = nil
        if ((v3_agF != nil) && (v3_agF.count > 0))
          v3_agF.each do |row|
            v3name = row['name']
            return createAbstractEmailRecipient(v3name)
          end
        end
        return 0
      end

      def createAbstractEmailRecipient(name)
        aerFind = "SELECT id,name FROM abstract_email_recipient WHERE name='%s';" % [name]
        v4_id = 0
        v4_aerF = VIREO::CON_V4.exec aerFind
        if ((v4_aerF != nil) && (v4_aerF.count > 0))
          v4_aerF.each do |row|
            puts "V4 FOUND EXISTING AbstractEmailRecipient " + row.to_s
            v4_id = row['id'].to_i
          end
          return v4_id
        else
          if (VIREO::REALRUN)
            aerInsert = "INSERT INTO abstract_email_recipient (dtype,id,name) VALUES('EmailRecipientContact',DEFAULT,'%s') RETURNING id;" % [name]
            puts "INSERT "+aerInsert
            begin
              v4_aerRS = VIREO::CON_V4.exec aerInsert
              v4_id = v4_aerRS[0]['id'].to_i;
              return v4_id
            rescue StandardError => e
              puts "\nFAILED ABSTRACT_EMAIL_RECIPIENT VALUE " + aerInsert + " ERR " + e.message;
              return -1
            end
          end
        end
      end

      def emailTemplateCounterpart(email_template_id)
        #Check V3 for email_template with the id = email_template_id
        #See if counterpart in V4: (email_template where v3.name = v4.name)
        #dtype = 'EmailRecipientContact'
        #If not, build it.
        #return V4 id
        agFind = "SELECT id,name FROM email_template WHERE id = %s;" % [email_template_id.to_s]
        v3_agF = VIREO::CON_V3.exec agFind
        v3name = nil
        if ((v3_agF != nil) && (v3_agF.count > 0))
          v3_agF.each do |row|
            v3name = row['name']
            return findEmailTemplate(v3name)
          end
        end
        return 0
      end

      def findEmailTemplate(name)
        aerFind = "SELECT id,name FROM email_template WHERE name='%s';" % [name]
        v4_id = 0
        puts "ET FIND "+aerFind
        v4_aerF = VIREO::CON_V4.exec aerFind
        if ((v4_aerF != nil) && (v4_aerF.count > 0))
          v4_aerF.each do |row|
            puts "V4 FOUND EXISTING AbstractEmailRecipient " + row.to_s
            v4_id = row['id'].to_i
          end
          return v4_id
        end
      end

      def createEmailWorkflowRule(is_disabled,is_system,email_recipient_id,email_template_id,submission_status_id)
        etFind = "SELECT email_template_id,submission_status_id from email_workflow_rule WHERE email_template_id='%s' AND submission_status_id='%s';" % [email_template_id.to_s,submission_status_id.to_s]
        v4_etF = VIREO::CON_V4.exec etFind
        if ((v4_etF != nil) && (v4_etF.count > 0))
          v4_etF.each do |row|
            puts "V4 FOUND EXISTING EmailWorkflowRule " + row.to_s
          end
          return 0
        else
          if (VIREO::REALRUN)
            v4_email_template_id = emailTemplateCounterpart(email_template_id)
            if(email_recipient_id == nil)
              etInsert = "INSERT INTO email_workflow_rule (id,is_disabled,is_system,email_template_id,submission_status_id) VALUES(DEFAULT,'%s','%s',%s,%s);" % [is_disabled,is_system,v4_email_template_id,submission_status_id]
            else
              v4_email_recipient_id = adminGroupCounterpart(email_recipient_id)
              etInsert = "INSERT INTO email_workflow_rule (id,is_disabled,is_system,email_recipient_id,email_template_id,submission_status_id) VALUES(DEFAULT,'%s','%s',%s,%s,%s);" % [is_disabled,is_system,v4_email_recipient_id.to_s,v4_email_template_id.to_s,submission_status_id]
              #etInsert = "INSERT INTO email_workflow_rule (id,is_disabled,is_system,email_recipient_id,email_template_id,submission_status_id) VALUES(DEFAULT,'%s','%s',%s,%s,%s);" % [is_disabled,is_system,email_recipient_id,email_template_id,submission_status_id]
            end
            puts "INSERT "+etInsert
            begin
              v4_etRS = VIREO::CON_V4.exec etInsert
              return 1
            rescue StandardError => e
              puts "\nFAILED EMAIL_WORKFLOW_RULE VALUE " + etInsert + " ERR " + e.message;
              return -1
            end
          end
        end
      end

      def updateDegrees()
        # PURGE DEFAULT DEGREES
        if (VIREO::REALRUN)
          deleteDegree()
        end
        # RECREATE V3 DEGREES
        dSelect = "SELECT displayorder,level,name FROM degree;"
        degLevel = {}
        v3_dRS = VIREO::CON_V3.exec dSelect
        degLevel = { 1 => "UNDERGRADUATE", 2 => "MASTERS", 3 => "DOCTORAL" }
=begin
        v3_dRS.each do |d|
          degLevel.store(d['level'].to_i,d['name'].split()[0].upcase)
        end
=end

        dl_count = createDegreeLevel(degLevel)

        d_count = 0
        position = 0
        v3_dRS.each do |d|
          position += 1
          cd = createDegree(position.to_s, d['name'], d['level'].to_s)
          if (cd > 0)
            d_count += 1
          end
        end
        return { "degree_level": dl_count, "degree": d_count }
      end

      def createDegreeLevel(degreeLevel)
        dl_count = 0
        degreeLevel.sort.each do |position, name|
          if (VIREO::REALRUN)
            dlInsert = "INSERT INTO degree_level(id,position,name) VALUES(DEFAULT,%s,'%s');" % [position.to_s, name]
            begin
              v4_dlRS = VIREO::CON_V4.exec dlInsert
              dl_count += 1
            rescue StandardError => e
              puts "\nFAILED DEGREE_LEVEL VALUE " + dlInsert + " ERR " + e.message;
            end
          end
        end
        return dl_count
      end

      def deleteDegree()
        degDelete = "TRUNCATE TABLE degree,degree_level RESTART IDENTITY;"
        v4_degD = VIREO::CON_V4.exec degDelete
      end

      def createDegree(position, name, level_id)
        etFind = "SELECT name, level_id FROM degree WHERE name='%s' AND level_id =%s;" % [name,level_id]
        v4_etF = VIREO::CON_V4.exec etFind
        if ((v4_etF != nil) && (v4_etF.count > 0))
          v4_etF.each do |row|
            puts "V4 FOUND EXISTING degree " + row.to_s
          end
          return 0
        else
          if (VIREO::REALRUN)
            etInsert = "INSERT INTO degree(id,position,name,level_id) VALUES(DEFAULT,%s,'%s',%s);" % [position, name,level_id]
            # puts etInsert
            begin
              v4_etRS = VIREO::CON_V4.exec etInsert
              return 1
            rescue StandardError => e
              puts "\nFAILED DEGREE VALUE " + etInsert + " ERR " + e.message;
              return -1
            end
          end
        end
      end

      def updateDegreeCodes()
        degSelect = "SELECT id,name FROM degree;"
        v4_deg = VIREO::CON_V4.exec degSelect
        v4_deg.each do |deg|
          puts deg['name']
          dcn = 'degree_code_' + deg['name'].strip.downcase.gsub(/\s/, '_')
          puts "NAME " + deg['name'] + " DCN " + dcn
          dcFind = "SELECT name, value FROM configuration WHERE name LIKE '%s'" % [dcn]
          v3_dc = VIREO::CON_V3.exec dcFind
          # puts "FIND "+dcFind
          if ((v3_dc != nil) && (v3_dc.count > 0))
            v3_dc.each do |dc|
              degreeUpdate = "UPDATE degree SET degree_code='%s' WHERE id=%s;" % [dc['value'], deg['id'].to_s]
              puts "   DEGUPDATE " + degreeUpdate
              if (VIREO::REALRUN)
                VIREO::CON_V4.exec degreeUpdate
              end
            end
          end
        end
      end
    end
  end
end
# ##END Misc

puts "ADD INITIAL SETTINGS " + VIREO::Map.initializeSettings().to_s
puts "ADDED DEPOSIT LOCATION " + VIREO::Map.updateDepositLocation().to_s
puts "ADDED EMBARGO TYPES " + VIREO::Map.updateEmbargoType().to_s
puts "ADDED EMAIL TEMPLATES " + VIREO::Map.updateEmailTemplate().to_s
puts "ADDED EMAIL WORKFLOW RULES "+VIREO::Map.updateEmailWorkflowRule().to_s
puts "ADDED DEGREES " + VIREO::Map.updateDegrees().to_s
puts "UPDATE DEGREE CODES " + VIREO::Map.updateDegreeCodes().to_s
puts "UPDATE ABSTRACT FIELD PROFILE" + VIREO::Map.updateAbstractFieldProfile().to_s
