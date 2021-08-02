require 'pg'
# require 'open3'
# require 'fileutils'
# require 'time'

require_relative 'MigrateGlobal.rb'

module VIREO
  module Map
    class << self
      ######################
      def resetIdentitySequence(tablename)
        idsSelect = "SELECT MAX(id) FROM " + tablename + ";"
        v3_idsRS = VIREO::CON_V4.exec idsSelect
        v3_idsRS.each do |ids|
          newseq_value = ids['max'].to_i + 1
          alterSeq = "ALTER SEQUENCE " + tablename + "_id_seq RESTART WITH " + newseq_value.to_s + ";"
          v4_AS = VIREO::CON_V4.exec alterSeq
          return "{" + tablename + ":" + newseq_value.to_s + "}"
        end
      end
    end
  end
end

puts "ALTER SEQUENCE " + VIREO::Map.resetIdentitySequence("weaver_users").to_s
puts "ALTER SEQUENCE " + VIREO::Map.resetIdentitySequence("submission").to_s
puts "ALTER SEQUENCE " + VIREO::Map.resetIdentitySequence("embargo").to_s
puts "ALTER SEQUENCE " + VIREO::Map.resetIdentitySequence("action_log").to_s
puts "ALTER SEQUENCE " + VIREO::Map.resetIdentitySequence("custom_action_value").to_s
puts "ALTER SEQUENCE " + VIREO::Map.resetIdentitySequence("custom_action_definition").to_s
