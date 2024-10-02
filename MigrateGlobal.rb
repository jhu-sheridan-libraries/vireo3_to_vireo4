require 'pg'

module VIREO
  # Data source on vireo3 server is /ebs/vireo/data/attachments
  # Data should be copied to vireo3 directory on vireo4 server /ebs/utswmed/attachments
  # Migration will read from /ebs/utswmed/attachments/ to /ebs/private

  # The following 5 fields need to be customized for your specific vireo3 and vireo4 instance

  # name of institution - this is all caps and used in MigrateOrg2 and MigrateSubmission5 (SiteSpecific.rb)
  # for organizational setup.
  # This requires corresponding changes in the relevant parts of those programs
  # if you are only migrating a single site you will need to specify those details elsewhere
  INSTITUTION = "JHU"

  # This is a list of the emails of the people you want to give admin privileges to
  ADMIN_EMAIL = ['jrm@jhu.edu']

  # This is the database name, username, and password for vireo3 database access
  CON_V3 = PG.connect :dbname => 'vireo3', :user => 'vireo', :password => 'vireo'

  # This is the database name, username, and password for vireo4 database access
  CON_V4 = PG.connect :dbname => 'vireo4', :user => 'vireo', :password => 'vireo'

  # This is the directory containing the 'attachments' directory containing your vireo3 files (theses, licenses)
  BASE_DIR_V3 = "/mnt/ETD/vireo_data_prod/"

  # Destination top directory for submitted documents, licenses, and other files.
  BASE_DIR_V4 = "/opt/vireo/data"

  # Set to false if you want to run the migration as a test and not have it write to vireo4
  REALRUN = true
end
