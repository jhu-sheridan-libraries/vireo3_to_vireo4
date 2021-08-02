require 'pg'

require_relative 'MigrateGlobal.rb'

#  mapActionLog:
#  This is a direct mapping from V3.actionlog to V4.action_log using slightly modified V4
#  keywords (V3's InReview is V4's UnderReview).

#  updateSubmissionStatus:
#  The V4.submission submission_status_id field is updated based on the most
#  recent V4.action_log entry.

module VIREO
  module Map
    class << self
      #########################
      # #ACTIONLOG
      def mapActionLog()
        # CREATE IN MEMORY MAP OF SUBMISSION_STATUS VALUES TO BUILD V4.actionlog WITH IDs

        submissionStatusSelect = "SELECT id,name FROM submission_status;"
        ssMap = Hash.new
        v3ssRS = VIREO::CON_V4.exec submissionStatusSelect
        v3ssRS.each do |row|
          name = row['name']
          compressedName = name.split(' ').join('').strip();
          if (compressedName == 'UnderReview')
            compressedName = 'InReview'
          end
          ssMap[compressedName] = row['id'].to_i
        end
        # DISPLAY FOR TEST
        # ssMap.each {|k,v| puts "K "+k+" V "+v.to_s}

        totalExpected = 0
        actionLogCount = 'SELECT COUNT(*) FROM actionlog;'
        v3alcRS = VIREO::CON_V3.exec actionLogCount
        begin
          v3alcRS.each do |row|
            totalExpected = row['count'].to_i
          end
        end

        completed = 0
        failed = 0
        actionlogSelect = "SELECT id,actiondate,entry,privateflag,submissionstate,attachment_id,person_id,submission_id FROM actionlog;"
        v3personRS = VIREO::CON_V3.exec actionlogSelect
        v3personRS.each do |row|
          begin
            person_id = 0;
            if (row['person_id'] != nil)
              person_id = row['person_id']
            end
            ss_id = ssMap[row['submissionstate'].strip()]
            al_id = createActionLog(row['id'], row['actiondate'], row['entry'], row['privateflag'], ss_id, person_id, row['submission_id']);
            if (al_id == -1)
              failed += 1
            else
              completed += 1
            end
          rescue StandardError => e
            failed += 1
            puts "EXCEPTION " + e.message
          end
          puts "TOTAL EXPECTED " + totalExpected.to_s + " COMPLETED " + completed.to_s + " FAILED " + failed.to_s
        end
        return { "completed": completed, "failed": failed }
      end

      def createActionLog(al_id, action_date, entry, private_flag, submission_status_id, user_id, action_logs_id)
        # UTILITY FOR BUILDING V4.ACTIONLOG
        entry = VIREO::CON_V4.escape_string(entry)

        actionlogFind = "SELECT id FROM action_log WHERE id = %s AND action_date='%s' AND action_logs_id='%s';" % [al_id,action_date, action_logs_id]
        v4_actionLogF = VIREO::CON_V4.exec actionlogFind
        if ((v4_actionLogF != nil) && (v4_actionLogF.count > 0))
          al_id = v4_actionLogF[0]['id'].to_i
          puts "  V4 FOUND ACTIONLOG " + al_id.to_s + " DATE " + action_date.to_s + " USER " + user_id.to_s + " STATUS " + submission_status_id.to_s
          return al_id
        else
          al_id_ret = 0
          if (VIREO::REALRUN)
            actionlogInsert = "INSERT INTO action_log VALUES(%s,'%s','%s','%s',%s,%s,%s) RETURNING id;" % [al_id, action_date, entry, private_flag, submission_status_id, user_id, action_logs_id]
            if (user_id == 0)
              actionlogInsert = "INSERT INTO action_log VALUES(%s,'%s','%s','%s',%s,null,%s) RETURNING id;" % [al_id, action_date, entry, private_flag, submission_status_id, action_logs_id]
            end
            begin
              v4_actionLogRS = VIREO::CON_V4.exec actionlogInsert
              al_id_ret = v4_actionLogRS[0]['id'].to_i;
            rescue StandardError => e
              puts "\nAL EXCEPTION " + actionlogInsert + " " + e.message
              al_id_ret = -1
            end
          end
          puts "  V4 CREATING ACTIONLOG " + al_id_ret.to_s + " DATE " + action_date.to_s + " USER " + user_id.to_s + " STATUS " + submission_status_id.to_s
          return al_id_ret
        end
      end

######################
# ##SubmissionStatus
      def updateSubmissionStatus()
        # HORRIBLY INEFFICIENT - RETHINK WITH GROUPBY OR INNER JOIN
        alSelect = "SELECT DISTINCT(action_logs_id) FROM action_log ORDER by action_logs_id ASC;"
        v4_alRS = VIREO::CON_V4.exec alSelect
        v4_alRS.each do |al|
          action_logs_id = al['action_logs_id']
          statSelect = "SELECT submission_status_id FROM action_log WHERE action_logs_id = %s ORDER BY id DESC LIMIT 1;" % [action_logs_id]
          v4_statRS = VIREO::CON_V4.exec statSelect
          v4_statRS.each do |stat|
            submission_status_id = stat['submission_status_id']
            # #ACTION_LOGS_ID IS THE SUBMISSION_ID
            #						puts "ACT  LOGS ID "+action_logs_id+" "+submission_status_id
            updateSubmissionStatusValue(action_logs_id, submission_status_id)
          end
        end
      end

      def updateSubmissionStatusValue(submission_id, submission_status_id)
        subUpdate = "UPDATE submission SET submission_status_id = %s WHERE id = %s;" % [submission_status_id,
                                                                                        submission_id]
        retval = 0
        begin
          v4_subRS = VIREO::CON_V4.exec subUpdate
        rescue StandardError => e
          retval = -1
          puts "EXCEPTION " + e.message
        end
        return retval
      end
      # ##END SubmissionStatus
      #########################
    end
  end
end

puts "ACTIONLOG " + VIREO::Map.mapActionLog().to_s
puts "UPDATE_SUBMISSION_STATUS " + VIREO::Map.updateSubmissionStatus().to_s
