require 'pg'
require 'set'
require 'open3'

require_relative 'MigrateGlobal.rb'

module VIREO
  module Map
    class << self
      def updateControlledVocabulary()
        # Truncate v4.vocabulary_word and v4.vocabulary_word_contacts
        vwcDelete = "TRUNCATE TABLE vocabulary_word, vocabulary_word_contacts RESTART IDENTITY;"
        v4_vwcD = VIREO::CON_V4.exec vwcDelete

# Update v4.vocabulary_word_contacts using
#	v3.committee_member, v3.committee_member_role_type, v3.committee_member_roles
# lh v3.committee_member retain id

=begin
        #for each v4.controlled_vocabulary find the correct v3 table to copy to v4.vocabulary_word
            INSERT INTO vocabulary_word (id,definition,identifier,name,controlled_vocabulary_id)
              VALUES(DEFAULT,depends_on_table,null,depends_on_table,v4.controlled_vocabulary.id)
          id = 1 Colleges			v3.college
          id = 2 Programs			v3.program
          id = 3 Departments		v3.department
          id = 4 Degrees			v3.degree
          id = 5 Majors			v3.major
          id = 6 Graduation Months	v3.graduation_month
          id = 7 Submission Types		v3.document_type
          id = 8 Subjects
          id = 9 Languages		v3.language
          id = 10 Committee Members	v3.committee_member, v3.committee_member_role_type, v3.committee_member_roles
          id = 11 Default Embargos	v3.embargo_type WHERE guarantor = 0
          id = 12 Proquest Embargos	v3.embargo_type WHERE guarantor = 1
          id = 13 Manuscript Allowed File Extensions
          id = 14 Administrative Groups	v3.administrative_groups
=end
        # for each v4.controlled_vocabulary find the correct v3 table to copy to v4.vocabulary_word
        cvSelect = "SELECT id,name FROM controlled_vocabulary;"
        v4_cvS = VIREO::CON_V4.exec cvSelect
        v4_cvS.each do |row|
          cv_id = row['id'].to_s
          cv_name = row['name'].to_s
          cv_name = VIREO::CON_V4.escape_string(cv_name)
          puts "CONTROLLED_VOCABULARY " + cv_id + " NAME " + cv_name
          if (cv_name == nil)
          # #THE FOLLOWING GET Colleges,Programs,Departments,Degrees,Majors FROM V3.
          ## SCHOOLS?
          # #IF THE ORG HAS CHANGED THEN GET THEM FROM V4.organization AND V4.organization_category
          elsif (cv_name == "Colleges")
            v3_S = VIREO::CON_V3.exec "SELECT name FROM college;"
            v3_S.each do |row|
              createVocabularyWord("College", "", row['name'],
                                   cv_id)
            end
          elsif (cv_name == "Programs")
            v3_S = VIREO::CON_V3.exec "SELECT name FROM program;"
            v3_S.each do |row|
              createVocabularyWord("Program", "", row['name'],
                                   cv_id)
            end
          elsif (cv_name == "Departments")
            v3_S = VIREO::CON_V3.exec "SELECT name FROM department;"
            v3_S.each do |row|
              createVocabularyWord("Academic Department", "",
                                   row['name'], cv_id)
            end
          elsif (cv_name == "Degrees")
            v3_S = VIREO::CON_V3.exec "SELECT name FROM degree;"
            v3_S.each do |row|
              createVocabularyWord("Degree", "", row['name'],
                                   cv_id)
            end
          elsif (cv_name == "Majors")
            v3_S = VIREO::CON_V3.exec "SELECT name FROM major;"
            v3_S.each do |row|
              createVocabularyWord("Major", "", row['name'],
                                   cv_id)
            end
          elsif (cv_name == "Graduation Months")
            puts "GRADMONTH "
          elsif (cv_name == "Submission Types")
            v3_S = VIREO::CON_V3.exec "SELECT name FROM document_type;"
            v3_S.each do |row|
              createVocabularyWord("Submission Type", "",
                                   row['name'], cv_id)
            end
          elsif (cv_name == "Subjects")
          elsif (cv_name == "Languages")
            v3_S = VIREO::CON_V3.exec "SELECT name FROM language;"
            v3_S.each do |row|
              createVocabularyWord("Language", "", row['name'],
                                   cv_id)
            end
          elsif (cv_name == "Committee Members")
#FSS
            puts "FSS COMM MEMBER "+cv_id.to_s
            v3_S = VIREO::CON_V3.exec "SELECT displayorder,submission_id,firstname,middlename,lastname FROM committee_member;"
            v3_S.each do |row|
              # name = v3.committee_member.firstname+' '+v3.committee_member.middlename+' '+v3.committee_member.lastname
              displayOrder = row['displayorder'].to_s
              submissionId = row['submission_id'].to_s
              #fullname = row['firstname'].to_s + ' ' + row['middlename'].to_s + ' ' + row['lastname'].to_s
              fullname = row['lastname'].to_s + ', ' + row['firstname'].to_s + ' ' + row['middlename'].to_s
              fullname = VIREO::CON_V4.escape_string(fullname)
              if ((fullname != nil) && (fullname.length > 1))
                vw_id = createVocabularyWord( "Committee Members", "", fullname, cv_id)
                puts "    CM NAME "+fullname+" DISPLAYORDER "+displayOrder.to_s+" SUBID "+submissionId.to_s
                if (vw_id > 0)
                  #cm_email = getUserEmail(
                  #  row['firstname'].to_s, row['lastname'].to_s
                  #)
                  if(displayOrder.to_s=="1")
                     cm_email = getChairEmail(submissionId)
                     puts "    CM_EMAIL FROM SUBM " + cm_email
                  end
                  createVocabularyWordContacts(vw_id, cm_email)
                  puts "    COMMITTEE MEMBER NAME " + fullname
                end
              end
            end
#FSS
          elsif (cv_name == "Default Embargos")
            v3_S = VIREO::CON_V3.exec "SELECT name FROM embargo_type WHERE guarantor = 0;"
            v3_S.each do |row|
              createVocabularyWord("Default Embargo", "",
                                   row['name'], cv_id)
            end
          elsif (cv_name == "Proquest Embargos")
            v3_S = VIREO::CON_V3.exec "SELECT name FROM embargo_type WHERE guarantor = 1;"
            v3_S.each do |row|
              createVocabularyWord("Proquest Embargo", "",
                                   row['name'], cv_id)
            end
          elsif (cv_name == "Manuscript Allowed File Extensions")
          elsif (cv_name == "Administrative Groups")
            listAdminGroupEmail()
          end
        end
        return v4_cvS.count.to_s
      end

      def getChairEmail(submission_id)
        chairEmailFind = "SELECT committeecontactemail FROM submission WHERE id =%s;" % [submission_id]
        v4_emailF = VIREO::CON_V3.exec chairEmailFind
        chairEmail = ""
        v4_emailF.each do |row|
          chairEmail = row['committeecontactemail'].to_s
        end
        return chairEmail 
      end

      def getUserEmail(firstname, lastname)
        firstname = VIREO::CON_V4.escape_string(firstname)
        lastname = VIREO::CON_V4.escape_string(lastname)
        emailFind = "SELECT email FROM weaver_users WHERE first_name='%s' AND last_name='%s';" % [firstname, lastname]
        puts emailFind
        v4_emailF = VIREO::CON_V4.exec emailFind
        emailAddr = ""
        v4_emailF.each do |row|
          emailAddr = row['email'].to_s
        end
        return emailAddr
      end

      def updateControlledVocabularyFromOrganization()
        orgFind = "SELECT name,category_id FROM organization;"
        v4_orgF = VIREO::CON_V4.exec orgFind
        v4_orgF.each do |row|
          org_name = row['name'].to_s
          cat_id = row['category_id'].to_i
          if (cat_id == 1)
            createVocabularyWord("College", "", org_name, cat_id)
          elsif (cat_id == 2)
            createVocabularyWord("Program", "", org_name, cat_id)
          elsif (cat_id == 3)
            createVocabularyWord("Academic Department", "", org_name, cat_id)
          elsif (cat_id == 4)
            createVocabularyWord("Degree", "", org_name, cat_id)
          elsif (cat_id == 5)
            createVocabularyWord("Major", "", org_name, cat_id)
          end
        end
      end

      def createVocabularyWord(definition, identifier, name, controlled_vocabulary_id)
        vw_id_ret = 0
        definition = VIREO::CON_V4.escape_string(definition)
        name = VIREO::CON_V4.escape_string(name)
        vwFind = "SELECT id,definition, name, controlled_vocabulary_id FROM vocabulary_word WHERE definition='%s' AND name='%s' AND controlled_vocabulary_id=%s;" % [ definition, name, controlled_vocabulary_id ]
        v4_vwF = VIREO::CON_V4.exec vwFind
        if ((v4_vwF != nil) && (v4_vwF.count > 0))
          v4_vwF.each do |row|
            vw_id_ret = row['id'].to_i
            puts "FSS CREATE_VOCAB_WORD V4 FOUND EXISTING vocabulary_word " + row.to_s
          end
        else
          if (VIREO::REALRUN)
            vwInsert = "INSERT INTO vocabulary_word (id,definition,identifier,name,controlled_vocabulary_id) VALUES(DEFAULT,'%s','%s','%s',%s) RETURNING id;" % [ definition, identifier, name, controlled_vocabulary_id ]
            # VALUES(DEFAULT,depends_on_table,null,depends_on_table,v4.controlled_vocabulary.id)
            begin
              v4_vwRS = VIREO::CON_V4.exec vwInsert
              vw_id_ret = v4_vwRS[0]['id'].to_i;
              puts "FSS CREATE_VOCAB_WORD V4 CREATED NEW vocabulary_word " + v4_vwRS[0].to_s
            rescue StandardError => e
              puts "\nFAILED VOCABULARY_WORD " + vwInsert + " ERR " + e.message;
              vw_id_ret = -1
            end
          end
        end
        return vw_id_ret
      end

      def createVocabularyWordContacts(vocabulary_word_id, contacts)
        if(contacts.nil?)
          return 0
        end
        contacts = VIREO::CON_V4.escape_string(contacts)
        vwcFind = "SELECT vocabulary_word_id, contacts FROM vocabulary_word_contacts WHERE vocabulary_word_id=%s AND contacts='%s';" % [ vocabulary_word_id, contacts ]

        v4_vwcF = VIREO::CON_V4.exec vwcFind
        if ((v4_vwcF != nil) && (v4_vwcF.count > 0))
          v4_vwcF.each do |row|
            puts "V4 FOUND EXISTING vocabulary_word_contacts " + row.to_s
          end
          return 0
        else
          if (VIREO::REALRUN)
            vwcInsert = "INSERT INTO vocabulary_word_contacts (vocabulary_word_id,contacts) VALUES(%s,'%s');" % [
              vocabulary_word_id, contacts
            ]
            begin
              v4_vwcRS = VIREO::CON_V4.exec vwcInsert
              return 1
            rescue StandardError => e
              puts "\nFAILED VOCABULARY_WORD_CONTACTS " + vwcInsert + " ERR " + e.message;
              return -1
            end
          end
        end
      end

      def listAdminGroupEmail()
        agSelect = "SELECT displayorder,name,encode(emails::bytea,'hex') as email FROM administrative_groups;"
        v3agRS = VIREO::CON_V3.exec agSelect
        begin
        v3agRS.each do |row|
          emailHex = row['email'].to_s
          # puts "EMAIL "+emailHex
          emailStr = emailHex.gsub(/../) { |pair| pair.hex.chr }
          # puts " CONV "+emailStr
          File.write('hashmap_output.tmp', emailStr)
          emailList = getJavaHashMapFromString('hashmap_output.tmp')
          # puts " EMAILLIST "+emailList
          emailList = JSON.parse(emailList)
          # puts " EMAILLIST "+emailList.to_s
          insertIntoV4(row['displayorder'], row['name'], emailList)
        end
        rescue StandardError => e
          puts "ERROR listAdminGroupEmail "+e.message
        end
      end

      def getJavaHashMapFromString(hmeParam)
        cmd = "java HashMapFromHex %s" % [hmeParam]
        # puts "CMD "+cmd
        stdout_str, stderr_str, status = Open3.capture3(cmd)
        if (status.success?)
          return stdout_str.to_s
        else
          return "[]"
        end
      end

      def insertIntoV4(dispOrder, name, emailList)
        # puts "DO "+dispOrder.to_s+" NAME "+name+" EMAIL "+emailList.to_s
        emailList.each do |email|
          puts "EMAIL " + email
          # INSERT INTO vocabulary_word (definition,name,controlled_vocabulary_id) VALUES (name,,name?,14);
          vocabulary_word_id = createVocabularyWord("Administrative Groups", "", name, 14)
          if (vocabulary_word_id > 0)
            createVocabularyWordContacts(vocabulary_word_id, email)
          end
        end
      end
    end
  end
end

puts "UPDATE CONTROLLED VOCABULARY " + VIREO::Map.updateControlledVocabulary().to_s
puts "UPDATE CONTROLLED VOCABULARY FROM ORGANIZATION " + VIREO::Map.updateControlledVocabularyFromOrganization().to_s
