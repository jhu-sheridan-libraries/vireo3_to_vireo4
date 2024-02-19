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
      # #CustomActions
      def updateCustomActions()
        cad_count = 0
        cadSelect = "SELECT id,displayorder,isstudentvisible,label FROM custom_action_definition;"
        v3_cadRS = VIREO::CON_V3.exec cadSelect
        v3_cadRS.each do |cad|
          puts "CAD " + cad['label'].to_s
          cad_count += createCustomActionDefinition(cad['id'].to_s, cad['displayorder'].to_s, cad['isstudentvisible'].to_s,
                                                    cad['label'].to_s)
        end

        scav_count = 0
        cavSelect = "SELECT id,value,definition_id,submission_id FROM custom_action_value;"
        v3_cavRS = VIREO::CON_V3.exec cavSelect
        v3_cavRS.each do |cav|
          # puts "\n/* CUST_ACT_VAL "+cav['value'].to_s+" SUBMISSION_ID "+cav['submission_id'].to_s+" CUST_ACT_VAL_ID "+cav['id'].to_s+" */"
          createCustomActionValue(cav['id'].to_s, cav['value'].to_s, cav['definition_id'].to_s)
          scav_count += createSubmissionCustomActionValues(cav['submission_id'].to_s, cav['id'].to_s)
        end
        return { "custom_definitions": cad_count, "submission_custom_action_values": scav_count }
      end

      def customActionDefinitionPositionCorrection()
        correctCAD = "UPDATE custom_action_definition SET position = ((position/10)+1);"
        v4_ccadF = VIREO::CON_V4.exec correctCAD
        return "1"
      end

      def createCustomActionDefinition(id, position, is_student_visible, label)
        label = VIREO::CON_V4.escape_string(label)
        cadFind = "SELECT label FROM custom_action_definition WHERE label = '%s';" % [label]
        v4_cadF = VIREO::CON_V4.exec cadFind
        if ((v4_cadF != nil) && (v4_cadF.count > 0))
          v4_cadF.each do |row|
            puts "V4 FOUND CustomActionDefinition " + row.to_s
          end
          return 0
        else
          if (VIREO::REALRUN)
            cadInsert = "INSERT INTO custom_action_definition (id,position,is_student_visible,label) VALUES(%s,%s,'%s','%s');" % [
              id, position, is_student_visible, label
            ]
            begin
              v4_cadRS = VIREO::CON_V4.exec cadInsert
              return 1
            rescue StandardError => e
              puts "\nFAILED CAD VALUE " + cadInsert + " ERR " + e.message;
              return -1
            end
          end
        end
      end

      def createCustomActionValue(id, value, definition_id)
        cavFind = "SELECT value FROM custom_action_value WHERE id= %s AND definition_id = %s;" % [id, definition_id]
        v4_cavF = VIREO::CON_V4.exec cavFind
        if ((v4_cavF != nil) && (v4_cavF.count > 0))
          v4_cavF.each do |row|
            puts "V4 FOUND CustomActionValue " + row.to_s
          end
          return 0
        else
          if (VIREO::REALRUN)
            cavInsert = "INSERT INTO custom_action_value (id,value,definition_id) VALUES(%s,'%s',%s);" % [id, value,
                                                                                                          definition_id]
            begin
              # puts cavInsert.to_s
              v4_cavRS = VIREO::CON_V4.exec cavInsert
              return 1
            rescue StandardError => e
              puts "\nFAILED CAV VALUE " + cavInsert + " ERR " + e.message;
              return -1
            end
          end
        end
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
            scavInsert = "INSERT INTO submission_custom_action_values (submission_id,custom_action_values_id) VALUES(%s,%s);" % [
              submission_id, custom_action_values_id
            ]
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
      end
    end
  end
end
# ##END CustomActions
#########################
# puts "ONLY UPDATE CUSTOM ACTIONS UPON FIRST MIGRATION - SUBSEQUENT MIGRATIONS SHOULD DEFER TO VIREO4 CHANGES"
puts "ADDED CUSTOM ACTIONS " + VIREO::Map.updateCustomActions().to_s
puts "CORRECT CustomActionDefinition position " + VIREO::Map.customActionDefinitionPositionCorrection().to_s
