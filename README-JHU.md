## Vireo 3 to Vireo 4 Migration - JHU localization
### General description

The process is as generally described in the README file. The skeleton of the process is to start with a current copy of 
our Vireo 3 production database and attachments directory containing all of our submission files. These are then 
transformed into a Vireo 4 database and a new asset store for the submission files.

In addition to the original Ruby scripts for this migration, there are two sets of scripts needed: one set to correct 
handling of dates in the database, and another to accommodate a schema change introduced in v4.2.8. These are run after
the Ruby scripts. All of this is handled in the migrate.sh script.

We have been done a lot of localization for JHU on a development Vireo 4 instance. This contains some changes to the 
managed_configuration in the Vireo4 database, which we must save as described in the README, and restore after the Vireo
4 database is generated.

One detail to look out for is that there is a hard-coded name for the owner of the Vireo 4 database in one of the scripts,
[428_submission_action_log_column_0.sql](428SchemaChangeSql/428_submission_action_log_column_0.sql) which grants 
permissions to that user - this should be checked.

### Performing the Migration
#### Description of Edits for JHU
As described in the README, we made edits to MigrateGlobal.rb to define the database names, user and password. This file
also specifies where to find the attachments directory from the Vireo 3 instance, and defines the location for the 
migrated submission files. We also edited SiteSpecific.rb to reflect that we are not using a hierarchical description 
for JHU, but instead are using just the university as a single organizational level, as all division use the same 
form and workflow.

To prepare for the migration then, we clone the [Sheridan Libraries fork of vireo3_to_vireo4](https://github.com/jhu-sheridan-libraries/vireo3_to_vireo4) 
and check out the JHU branch. After verifying that the details are correct, we then run the migrate.sh script there.

The idea is that we will (hopefully) end up with a Vireo 4 database and a directory of assets. The pkan is to dump the database
so that it can be pushed up to our database server, and to package the assets to be stored in their location as specified in the Vireo 4
server configuration.

