require 'json'
require_relative 'MigrateGlobal.rb'

# Preprocessor to add custom advisor and committeeMember entries into
# src/main/resources/organization/SYSTEM_Organization_Definition.json

# This program takes 2 required parameters:
#	input filename - the existing vireo4's SYSTEM_Organization_Definition.json
#	output filename - some new file which will replace SYSTEM_Organization_Definition.json
# And one optional parameter:
#	log file - file logging the operation of this program

# This is used by ansible to read a copy of SYSTEM_Organization_Definition.json in its working directory
# It generates a local new SYSTEM_Organization_Definition.json_generated which is subsequently
# copied into the original location of SYSTEM_Organization_Definition.json

module VIREO
  module Map
    class << self
      def addFieldPredicateToConfig(inFileName, outFileName, logFileName)
        logFile = File.open(logFileName, 'w')
        roleList = listV3Roles()
        inFile = File.read(inFileName)
        file_data = JSON.parse(inFile)
        file_data['originalWorkflowSteps'].each do |wfs|
          wfs['originalFieldProfiles'].each_with_index do |fp, indx|
            if (fp['fieldPredicate']['value'] == "dc.contributor.advisor")
              roleList.each do |key, value|
                # puts "K "+key+" V "+value
                if (value.include? "advisor")
                  logFile.write("ADVISOR: " + key + " " + value + "\n")
                  # new_advisor = advisorTemplate(key)
                  new_advisor = advisorTemplate(key, value)
                  wfs['originalFieldProfiles'].insert((indx + 1).to_i, new_advisor)
                end
              end
            elsif (fp['fieldPredicate']['value'] == "dc.contributor.committeeMember")
              roleList.each do |key, value|
                puts "K " + key + " V " + value
                if (value.include? "committeeMember")
                  logFile.write("MEMBER: " + key + " " + value + "\n")
                  # new_member = memberTemplate(key)
                  new_member = memberTemplate(key, value)
                  wfs['originalFieldProfiles'].insert((indx + 1).to_i, new_member)
                end
              end
            end
          end
        end
        # displayCurrent(file_data)
        # puts JSON.pretty_generate(file_data).to_s
        File.write(outFileName, JSON.pretty_generate(file_data))
      end

      def listV3Roles()
        rolesSelect = "SELECT DISTINCT(roles) FROM committee_member_roles;"
        roleList = Hash.new
        v3_rS = VIREO::CON_V3.exec rolesSelect
        if ((v3_rS != nil) && (v3_rS.count > 0))
          v3_rS.each do |row|
            roleName = row['roles']
            puts "    ROLE " + roleName.to_s
            if (["Advisor", "Committee Member"].include?(roleName))
            else
              roleList.merge!(getRoleCanonicalNameAndType(roleName))
            end
          end
        end
        return roleList
      end

      def getRoleCanonicalNameAndType(roleName)
        String contigRoleString = roleName.gsub(' ', '')
        String new_field_predicate = "dc.contributor"

        if (contigRoleString.include?("Advisor"))
          new_field_predicate += ".advisor."
        elsif (contigRoleString.include?("Director"))
          new_field_predicate += ".advisor."
        elsif (contigRoleString.include?("Chair"))
          new_field_predicate += ".advisor."
        elsif (contigRoleString.include?("Co-Chair"))
          new_field_predicate += ".advisor."
        elsif (contigRoleString.include?("Supervisor"))
          new_field_predicate += ".advisor."
        else
          new_field_predicate += ".committeeMember."
        end
        return Hash[roleName => new_field_predicate + contigRoleString]
        # return Hash[contigRoleString => new_field_predicate]
      end

      def advisorTemplate(member_name, fp_value)
        new_advisor = eval('{"fieldPredicate"=>{"value"=>"#{fp_value}", "documentTypePredicate"=>false}, "originatingWorkflowStep"=>{"name"=>"Document Information"}, "inputType"=>{"name"=>"INPUT_CONTACT_SELECT"}, "repeatable"=>false, "overrideable"=>true, "enabled"=>true, "optional"=>false, "flagged"=>false, "logged"=>false, "usage"=>"", "help"=>"Select the name and email address for your committee #{member_name}.", "gloss"=>"#{member_name}", "controlledVocabulary"=>{"name"=>"Committee Members", "isEntityProperty"=>false}}')
      end

      def memberTemplate(member_name, fp_value)
        new_member = eval(' {"fieldPredicate"=>{"value"=>"#{fp_value}", "documentTypePredicate"=>false}, "originatingWorkflowStep"=>{"name"=>"Document Information"}, "inputType"=>{"name"=>"INPUT_CONTACT"}, "repeatable"=>true, "overrideable"=>true, "enabled"=>true, "optional"=>false, "flagged"=>false, "logged"=>false, "usage"=>"", "help"=>"Enter the names and email addresses of your non-chairing #{member_name} committee members.", "gloss"=>"Non-Chairing #{member_name} ", "controlledVocabulary"=>{"name"=>"Committee Members", "isEntityProperty"=>false}}')
      end

      def displayCurrent(file_data)
        file_data['originalWorkflowSteps'].each do |wfs|
          wfs['originalFieldProfiles'].each_with_index do |fp, indx|
            # puts "\n\n"+fp.to_s
            if (fp['fieldPredicate']['value'].include? "dc.contributor")
              puts "\n\n" + fp.to_s
              puts "INDX " + indx.to_s
            end
          end
        end
      end
    end
  end
end

input_array = ARGV
if (input_array != nil)
  inFileName = input_array[0].to_s
  outFileName = input_array[1].to_s
  logFileName = input_array[2].to_s
  if ((inFileName != nil) && (inFileName.length > 0) && (outFileName != nil) && (outFileName.length > 0))
    if ((logFileName == nil) || (logFileName.length < 1))
      logFileName = "./SystemJson.log"
    end
    puts "IN " + inFileName + " OUT " + outFileName
    VIREO::Map.addFieldPredicateToConfig(inFileName, outFileName, logFileName)
  else
    puts "USAGE: ruby SystemJson.rb <original system_organization_definition file> <output file containing new system_organization_definitions> <optional logfile>"
    puts "  ROLE LIST"
    VIREO::Map.listV3Roles()
  end
else
  puts "USAGE: ruby SystemJson.rb <original system_organization_definition file> <output file containing new system_organization_definitions> <optional logfile>"
  puts "  ROLE LIST"
  VIREO::Map.listV3Roles()
end
