## Vireo3 to Vireo4 migration

#### This document is a first pass and very much a work in progress.  Please help me refine it by asking for clarifications in any vireo open source public channel.  It will be periodically updated with bulk changes from a private repository.

#### This repository is designed to be used by ansible scripts but can be run manually.  Texas Digital Library uses ansible scripts for provisioning its hosted servers.  The scripts may become available in the future.  These instructions are for manual operation.

The migration software is a set of ruby methods to be run in sequence.  These methods perform a crosswalk between a populated vireo3 database and an initialized vireo4 database.

These instructions assume a server has been provisioned with all that is necessary to host vireo4 and apache and shibboleth and anything else needed.  It also assumes a copy of the vireo3 database and its associated file directory (containing dissertation PDF files, license files, etc) are accessible on the vireo4 server.


1.  Put the migration code on the vireo4 server:
```
git clone https://github.com/TexasDigitalLibrary/vireo3_to_vireo4.git
```

2.  Install ruby and gem 'pg'


3.  Create a local copy of the vireo3 database and its files on the server.  These locations will be specified in the MigrateGlobal.rb file in step 5. 


4.  Determine how to use the hierarchical expression of organizational structure in vireo4.  The mapping for departments/colleges/schools needs to be expressed in SiteSpecific.rb.  See that file for further instructions.


5.  Compile HashMapFromHex.java and hash.java - these are needed by the ruby program to create correct hashes for files and to convert admin_groups email hashmap from v3 to v4
```
  javac HashMapFromHex.java
  javac hash.java
```

Compile DepLocEncode.java - this is needed for encoding the deposit_location password from vireo3.
Before this is compiled the secret Key must be set with setKey (currently 'setKey("verysecretsecret)') in main().

This is the same value found in application.yaml security: secret:

```
  javac DepLocEncode.java
```


6.  Edit MigrateGlobal.rb - follow instructions in comments.  This needs to point to both databases and the vireo3 and vireo4 data directories among other things.  These directories should end with a '/' for unix/linux based systems.  This step must be performed before all subsequent steps are done.  MigrateGlobal.rb points to several directories, notably the path containing the vireo3 data files (licenses, Theses, etc.) and the vireo4 destination for those files.  This is typically something like "/ebs/yourinstitution/attachments/" for the vireo3 subdirectories (a directory for each submitter) and a '/ebs/vireo/' and '/ebs/vireo/private/' as a destination for vireo4 subdirectories for each submitter.  (The 'private/' subpath is hardcoded in the migration code.)  The name of the subdirectory in '/ebs/vireo/private/' is calculated by hash.java.


7.  Save existing configuration.
If you have made customizations of your current pre-migrated vireo4 database you can capture these changes.  Run:
```
ruby SaveManagedConfig.rb
```
and it will create a file named after the vireo4 database with a '.config' suffix.
To set these values in the new vireo4 once migrations are complete using RestoreManagedConfig.rb


8.  EXPERIMENTAL AND EVOLVING! If you use customized committee member types beyond advisor and committee member then that data must be captured.  This is done by running 
```
  ruby SystemJson.rb [copy_of_SYSTEM_Organization_Definition.json] SYSTEM_Organization_Definition.json_generated
  cp SYSTEM_Organization_Definition.json_generated src/main/resources/organization/SYSTEM_Organization_Definition.json
```
Which reads the vireo3 database and generates a new SYSTEM_Organization_Definition.json file which you can copy into src/main/resources/organization to replace the current file.
Also note that in order to export these custom values in proquest exports you may need an alternate vireo4 branch.  Currently this is 4.1.1_AddContributorVariants_1526 but could change.

```
ruby WriteCWasJson.rb
```
Write out controlled vocabularies in JSON format from a migrated vireo4 instance. 



9.  If you don't already have one, create a new blank vireo4 postgres database and give permissions to the role you will use to sign in (from within psql):
```
psql> CREATE DATABASE vireo4;
psql> GRANT ALL PRIVILEGES ON DATABASE vireo4 to vireo;
psql> \c vireo4;
```


10.  Edit src/main/resources/application.yaml to point to the new vireo4 database and then start vireo to build the schema.
```
  mvn clean spring-boot:run
```
This will also populate the vireo4 database with initial data.


11.  Perform the migration - each of the following must be run in the ordinal sequence expressed by the file name's last character before the prefix.
```
ruby MigrateInit1.rb > init1.log
ruby MigrateOrg2.rb > org2.log
ruby MigrateUsers3.rb > users3.log
ruby MigrateVocabularyWord4.rb > vocab4.log
ruby MigrateSubmission5.rb > submission5.log
ruby MigrateActionLog6.rb > actionlog6.log
ruby MigrateCustomActions7.rb > customactions7.log
ruby MigrateFinal8.rb > final8.log
```

Alternatively you can do:
```
source run.script &
```

12.  If you ran SaveManagedConfig.rb earlier then now is the time to run Restore Managed Config
```
  ruby RestoreManagedConfig.rb
```


13.  If you missed any people for admin privileges in MigrateGlobal.rb you can set them manually after signing in via psql:
```
UPDATE weaver_users SET role='ROLE_ADMIN' WHERE id = [users id];
```

To prevent further changes to database upon startup (from initializing files) set hibernate.ddl-auto to 'none' in src/main/resources/application.yaml

```
jpa:
  ...
  hibernate.ddl-auto: none
```


14.  FixProquestExport.rb: If your legacy data does not have the 'identifier' column set to an integer representing the number of months for an embargo value then FixProquestExport.rb will fix that for both Proquest and default embargos.  This is a common problem for exports using newer more strict versions of vireo4.

```
ruby FixProquestExport.rb 
```


