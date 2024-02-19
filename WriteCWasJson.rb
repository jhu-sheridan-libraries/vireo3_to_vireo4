require 'json'
require_relative 'MigrateGlobal.rb'


module VIREO
  module Map
    class << self
      def writeVW(vc_id,jsonFileName,csvFileName)
        cvSelect = "SELECT name FROM controlled_vocabulary WHERE id = %s;" % [vc_id.to_s]
       
        csvLine = "name,definition,identifier,contacts\n" 
        cvName = ""
        v4_cvS = VIREO::CON_V4.exec cvSelect 
        v4_cvS.each do |row|
          cvName = row['name'].to_s
        end
        gen_dict = []
        vwSelect = "SELECT DISTINCT id,name,definition,identifier FROM vocabulary_word WHERE controlled_vocabulary_id = %s ORDER BY id;" % [vc_id.to_s]

        v4_rS = VIREO::CON_V4.exec vwSelect 
        v4_rS.each do |row|
          newrow = {}
          newrow[:name] = row['name'].to_s
          newrow[:definition] = row['definition'].to_s
          newrow[:identifier] = row['identifier'].to_s
          gen_dict << newrow

          nameTxt = row['name'].to_s
          if(nameTxt.include?(","))
            nameTxt = '"'+nameTxt+'"'
          end

          definitionTxt = row['definition'].to_s
          if(definitionTxt.include?(","))
            definitionTxt = '"'+definitionTxt+'"'
          end

          csvLine += nameTxt+","+definitionTxt+","+row['identifier'].to_s+",,\n"
        end

        doc_data = {"name": cvName,"isEntityProperty":false, dictionary:gen_dict};
        File.write(jsonFileName, JSON.pretty_generate(doc_data))
        File.write(csvFileName, csvLine)
        return JSON.pretty_generate(doc_data)
      end
    end
  end
end

#/controlled_vocabularies
puts VIREO::Map.writeVW(1,"Colleges.json","Colleges.csv").to_s
puts VIREO::Map.writeVW(2,"Programs.json","Programs.csv").to_s
puts VIREO::Map.writeVW(3,"Departments.json","Departments.csv").to_s
puts VIREO::Map.writeVW(5,"Majors.json","Majors.csv").to_s
puts VIREO::Map.writeVW(7,"SubmissionTypes.json","SubmissionTypes.csv").to_s
puts VIREO::Map.writeVW(10,"CommitteeMembers.json","CommitteeMembers.csv").to_s
puts VIREO::Map.writeVW(13,"ManuscriptAllowedMimeTypes.json","ManuscriptAllowedMimeTypes.csv").to_s
puts VIREO::Map.writeVW(14,"AdministrativeGroups.json","AdministrativeGroups.csv").to_s

#/degrees/SYSTEM_Degrees.json
###CANNOT BE CSV EXPORTED
puts VIREO::Map.writeVW(4,"Degrees.json","Degrees.csv").to_s

#/graduation_months/SYSTEM_Graduation_Months.json
###CANNOT BE CSV EXPORTED
puts VIREO::Map.writeVW(6,"Graduation_Months.json","Graduation_Months.csv").to_s

#/??
puts VIREO::Map.writeVW(8,"Subjects.json","Subjects.csv").to_s

#/languages/SYSTEM_Languages.json
###CANNOT BE CSV EXPORTED
puts VIREO::Map.writeVW(9,"Languages.json","Subjects.csv").to_s

#/embargoes/SYSTEM_Embargo_Definitions.json BOTH DEFAULT and PROQUEST
###CANNOT BE CSV EXPORTED
puts VIREO::Map.writeVW(11,"Embargoes_default.json","Embargoes_default.csv").to_s
###CANNOT BE CSV EXPORTED
puts VIREO::Map.writeVW(12,"Embargoes_proquest.json","Embargoes_proquest.csv").to_s



