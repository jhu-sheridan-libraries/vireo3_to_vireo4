require 'pg'
# require 'open3'
# require 'fileutils'
# require 'time'

require_relative 'MigrateGlobal.rb'

=begin
updateCustomActions:
  Creation of V4.custom_action_definition and V4.custom_action_value entries directly from V3.custom_action_definition and V3.custom_action_value entries.
=end

module VIREO
  module Map
    class << self
      ######################

      def allSubmissions()
        subList = []
        subSelect = "SELECT id FROM submission;"
        v4_subRS = VIREO::CON_V4.exec subSelect
        v4_subRS.each do |row|
          fixCustomActions(row['id'].to_s).to_s
          subList << row['id'].to_s
          puts row['id'].to_s
        end
        return subList
      end

      def getCADList()
        cadList = []
        cadSelect = "SELECT id FROM custom_action_definition;"
        v4_cadRS = VIREO::CON_V4.exec cadSelect
        v4_cadRS.each do |row|
          cadList << row['id'].to_s
        end
        return cadList;
      end

      def fixCustomActions(submission_id)
        cadList = getCADList()
        puts "CAD "+cadList.to_s
        haveList = []
        cavSelect = "SELECT cav.id,cav.value,cav.definition_id FROM custom_action_value cav, submission_custom_action_values scav WHERE cav.id = scav.custom_action_values_id AND scav.submission_id = '%s' ORDER BY cav.definition_id;" % [submission_id.to_s]
        v4_cavRS = VIREO::CON_V4.exec cavSelect
        v4_cavRS.each do |row|
          puts row.to_s
          haveList << row['definition_id'].to_s
        end
        puts "HAVE "+haveList.to_s
        needList = cadList - haveList
        puts "NEED "+needList.to_s

        scav_count = 0
        needList.each do |cad_id|
          cav_id = createCustomActionValue('f',cad_id.to_s)
          scav_count += createSubmissionCustomActionValues(submission_id.to_s, cav_id.to_s)
        end
      end


      def createCustomActionValue(value, definition_id)
          cav_id = "0"
          if (VIREO::REALRUN)
            cavInsert = "INSERT INTO custom_action_value (id,value,definition_id) VALUES(DEFAULT,'%s',%s) RETURNING id;" % [value,definition_id]
            begin
              v4_cavRS = VIREO::CON_V4.exec cavInsert
              cav_id = v4_cavRS[0]['id'].to_s
            rescue StandardError => e
              puts "\nFAILED CAV VALUE " + cavInsert + " ERR " + e.message;
            end
          end
          return cav_id
      end

      def createSubmissionCustomActionValues(submission_id, custom_action_values_id)
        scaFind = "SELECT submission_id, custom_action_values_id FROM submission_custom_action_values WHERE submission_id=%s AND custom_action_values_id=%s;" % [
          submission_id, custom_action_values_id
        ]

        v4_scaF = VIREO::CON_V4.exec scaFind
        if ((v4_scaF != nil) && (v4_scaF.count > 0))
          v4_scaF.each do |row|
            puts "V4 FOUND SubmissionCustomActionValues " + row.to_s
          end
          return 0
        else
          if (VIREO::REALRUN)
            scavInsert = "INSERT INTO submission_custom_action_values (submission_id,custom_action_values_id) VALUES(%s,%s);" % [submission_id, custom_action_values_id]
            begin
              # puts scavInsert.to_s
              v4_scavRS = VIREO::CON_V4.exec scavInsert
              return 1
            rescue StandardError => e
              puts "\nFAILED SCAV VALUE " + scavInsert + " ERR " + e.message;
              return -1
            end
          end
        end
        return 0
      end
    end
  end
end

# ##END CustomActions
#########################
#puts "TEST " + VIREO::Map.fixCustomActions('867').to_s
puts "TEST " + VIREO::Map.allSubmissions().to_s

