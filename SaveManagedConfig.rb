require 'pg'
require 'set'
require 'time'

require_relative 'MigrateGlobal.rb'


module VIREO
  module Map
    data_file = 'managed_configuration.table'
    class << self
      def SaveManagedConfig()
        db_name = VIREO::CON_V4.db
        mc_list = []
        mcSelect = "SELECT id,name,type,value FROM managed_configuration;"
        v4_mcS = VIREO::CON_V4.exec mcSelect
        v4_mcS.each do |row|
          mc_row = []
          mc_id = row['id'].to_s
          mc_row << mc_id
          mc_name = row['name'].to_s
          mc_row << mc_name
          mc_type = row['type'].to_s
          mc_row << mc_type
          mc_value = VIREO::CON_V4.escape_string(row['value'].to_s)
          mc_row << mc_value
          # puts mc_row
          mc_list << mc_row
        end
        puts mc_list.to_s
        File.write(db_name + '.config', mc_list.to_s)
        File.write('../'+db_name + Time.now.utc.iso8601+'.config', mc_list.to_s)
      end
    end
  end
end
puts "Save ManagedConfig " + VIREO::Map.SaveManagedConfig().to_s
