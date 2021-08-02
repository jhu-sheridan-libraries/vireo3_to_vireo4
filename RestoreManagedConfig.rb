require 'pg'
require 'set'

require_relative 'MigrateGlobal.rb'


module VIREO
  module Map
    data_file = 'managed_configuration.table'
    class << self
      def RestoreManagedConfig()
        indx = 0
        db_name = VIREO::CON_V4.db
        file = File.open(db_name + '.config')
        data_str = file.read
        mc = JSON.parse(data_str)
        mc.each do |row|
          indx += 1
          puts row.to_s
          createManagedConfiguration(row[0], row[1], row[2], row[3])
        end
        return indx
      end

      def createManagedConfiguration(id, name, type, value)
        mcFind = "SELECT name, type FROM managed_configuration WHERE name='%s' AND type='%s';" % [
          name, type
        ]
        v4_mcF = VIREO::CON_V4.exec mcFind
        if ((v4_mcF != nil) && (v4_mcF.count > 0))
          v4_mcF.each do |row|
            puts "V4 FOUND EXISTING managed_configuration " + row.to_s
          end
          return 0
        else
          if (VIREO::REALRUN)
            mcInsert = "INSERT INTO managed_configuration(id,name,type,value) VALUES(DEFAULT,'%s','%s','%s');" % [
              name, type, value
            ]
            begin
              v4_mcRS = VIREO::CON_V4.exec mcInsert
              return 1
            rescue StandardError => e
              puts "\nFAILED MANAGED_CONFIGURATION " + mcInsert + " ERR " + e.message;
              return -1
            end
          end
        end
      end
    end
  end
end
puts "Restore ManagedConfig " + VIREO::Map.RestoreManagedConfig().to_s
