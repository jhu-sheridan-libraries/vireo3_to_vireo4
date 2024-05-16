require 'pg'
require 'open3'

require_relative 'MigrateGlobal.rb'

module VIREO
  module Map
    class << self
      ######################
      def cycleThroughEmbargos(field_predicate_value)
        selFv = "SELECT fv.id,fv.value,fv.field_predicate_id FROM field_value fv, field_predicate fp WHERE fv.field_predicate_id = fp.id AND fp.value = '%s';" % [field_predicate_value]
        v4_fvRS = VIREO::CON_V4.exec selFv
        #BASED ON SELECT name FROM embargo WHERE guarantor = 'PROQUEST';
        v4_fvRS.each do |row|
          fv_months = 0
          fv_id = row['id']
          fv_value = row['value']
          if(fv_value.nil?)
          elsif(fv_value.start_with? '1')
            fv_months = 12
          elsif(fv_value.start_with? '2')
            fv_months = 24
          elsif(fv_value.start_with? '3')
            fv_months = 36
          elsif(fv_value.start_with? '4')
            fv_months = 48
          elsif(fv_value.start_with? '5')
            fv_months = 60

          elsif(fv_value.start_with? '6-month')
            fv_months = 6
          elsif(fv_value.start_with? 'Patent Hold')
            fv_months = 60
          elsif(fv_value.start_with? 'Journal Hold')
            fv_months = 60
          elsif(fv_value.start_with? 'Special')
            fv_months = 60
          elsif(fv_value.start_with? 'Indefinite')
            fv_months = 60
          elsif(fv_value.start_with? 'Permanent')
            fv_months = 60
          elsif(fv_value.start_with? 'Flexible')
            fv_months = 60
          elsif(fv_value.start_with? 'TTU Access Only')
            fv_months = 60
          elsif(fv_value.start_with? 'Closed Access')
            fv_months = 60
	#UTSWMED
          elsif(fv_value.start_with? 'None')
            fv_months = 0
          elsif(fv_value.start_with? 'No')
            fv_months = 0
          elsif(fv_value.start_with? 'Two')
            fv_months = 24
          elsif(fv_value.start_with? 'Permanent')
            fv_months = 60
          end

          fp_id = row['field_predicate_id']
          puts fv_value, fv_months
          fv_months_str = ""
          if fv_months >= 0
            fv_months_str = fv_months.to_s
          elsif(fv_months == 0)
            fv_months_str = "0"
          end
          updateFieldValueById(fv_id,"",fv_months_str,fp_id)
        end
      end

      def getFieldPredicateID(fp_value)
        selFp = "SELECT id FROM field_predicate WHERE value = '%s';" % [fp_value]
        v4_fpRS = VIREO::CON_V4.exec selFp
        fp_id = ""
        v4_fpRS.each do |row|
          fp_id = row['id'].to_s
        end
        return fp_id
      end

      def cycleThroughDegrees()
        fp_id = getFieldPredicateID("thesis.degree.name")
        selDeg = "SELECT d.name,dl.name AS level FROM degree d, degree_level dl order by d.id;"
        v4_degRS = VIREO::CON_V4.exec selDeg
        v4_degRS.each do |row|
          deg_name = row['name']
          deg_level = row['level']
          new_deg_code = "" 
          new_deg_def = "" 
          if(deg_name == nil)
          elsif (deg_name.start_with? "Master of Arts")
            new_deg_code = "M.A"
            new_deg_def = "masters" 
          elsif (deg_name.start_with? "Master of Education")
            new_deg_code = "MEd"
            new_deg_def = "masters" 
          elsif (deg_name.start_with? "Master of Fine Arts")
            new_deg_code = "MFA"
            new_deg_def = "masters" 
          elsif (deg_name.start_with? "Master of Music")
            new_deg_code = "MM"
            new_deg_def = "masters" 
          elsif (deg_name.start_with? "Master of Public Administration")
            new_deg_code = "MPA"
            new_deg_def = "masters" 
          elsif (deg_name.start_with? "Master of Science")
            new_deg_code = "M.S"
            new_deg_def = "masters" 
          elsif (deg_name.start_with? "Doctor of Philosophy")
            new_deg_code = "Ph.D"
            new_deg_def = "doctoral" 
          elsif (deg_name.start_with? "Doctor of Education")
            new_deg_code = "EdD"
            new_deg_def = "doctoral" 
          elsif (deg_name.start_with? "Master of Art")
            new_deg_code = "M.A"
            new_deg_def = "masters"
          elsif (deg_name.start_with? "Master of Bussiness Administration")
            new_deg_code = "MBA"
            new_deg_def = "masters"
          elsif (deg_name.start_with? "Master of Business Administration")
            new_deg_code = "MBA"
            new_deg_def = "masters"
          elsif (deg_name.start_with? "Doctor of Nursing Practice")
            new_deg_code = "DNP"
            new_deg_def = "masters"
          elsif (deg_name.start_with? "MBA")
            new_deg_code = "MBA"
            new_deg_def = "masters"
          elsif (deg_name.start_with? "MS")
            new_deg_code = "MS"
            new_deg_def = "masters"
          elsif (deg_name.start_with? "MA")
            new_deg_code = "MA"
            new_deg_def = "masters"
          elsif (deg_name.start_with? "AUD")
            new_deg_code = "AUD"
            new_deg_def = "doctoral"
          elsif (deg_name.start_with? "PHD")
            new_deg_code = "PHD"
            new_deg_def = "doctoral"
          elsif (deg_name.start_with? "MAT")
            new_deg_code = "MAT"
            new_deg_def = "masters"
          elsif (deg_name.start_with? "MFA")
            new_deg_code = "MFA"
            new_deg_def = "masters"
          elsif (deg_name.start_with? "MPA")
            new_deg_code = "MPA"
            new_deg_def = "masters"
          elsif (deg_name.start_with? "MPP")
            new_deg_code = "MPP"
            new_deg_def = "masters"
          elsif (deg_name.start_with? "MSCS")
            new_deg_code = "MSCS"
            new_deg_def = "masters"
          elsif (deg_name.start_with? "MSEE")
            new_deg_code = "MSEE"
            new_deg_def = "masters"
          elsif (deg_name.start_with? "MSTE")
            new_deg_code = "MSTE"
            new_deg_def = "masters"

          end
          if(new_deg_code.length > 0)
            updateDegreeCode(deg_name,new_deg_code)
            updateFieldValue(deg_name,new_deg_def,new_deg_code,fp_id)
          end
        end
      end

      def updateDegreeCode(deg_name,deg_code)
        if (VIREO::REALRUN)
          dcUpdate = "UPDATE degree SET degree_code = '%s' WHERE name = '%s';" % [deg_code,deg_name]
          begin
            v4_dcRS = VIREO::CON_V4.exec dcUpdate
          rescue StandardError => e
            puts "ERROR SETTING degree_code"
            puts dcUpdate
          end
        end
      end

      def updateFieldValueById(fv_id,fv_definition,fv_identifier,fp_id)
          fvUpdate = "UPDATE field_value SET definition = '%s', identifier = '%s' WHERE field_predicate_id = %s AND id = '%s';" % [fv_definition,fv_identifier,fp_id,fv_id]
            puts fvUpdate
          begin
            v4_fvRS = VIREO::CON_V4.exec fvUpdate
          rescue StandardError => e
            puts "ERROR SETTING field_value WITH definition and identifier for thesis.degree.name"
            puts fvUpdate
          end
      end


      def updateFieldValue(deg_name,fv_definition,fv_identifier,fp_id)
        if (VIREO::REALRUN)
          fvUpdate = "UPDATE field_value SET definition = '%s', identifier = '%s' WHERE field_predicate_id = %s AND value = '%s';" % [fv_definition,fv_identifier,fp_id,deg_name]
            puts fvUpdate
          begin
            v4_fvRS = VIREO::CON_V4.exec fvUpdate
          rescue StandardError => e
            puts "ERROR SETTING field_value WITH definition and identifier for thesis.degree.name"
            puts fvUpdate
          end
        end
      end

    end
  end
end

#VIREO::Map.cycleThroughDegrees()
VIREO::Map.cycleThroughEmbargos("default_embargos")
VIREO::Map.cycleThroughEmbargos("proquest_embargos")


