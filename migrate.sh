#!/bin/sh

#set script variables
DB_USER="vireo"
DATABASE="vireo4"

DATE_DIR="DateFixSql"
SCHEMA_CHANGE_DIR="428SchemaChangeSql"


echo "Performing Vireo 3 to Vireo 4 migration"

#the original Ruby migration process in run.script
#echo "Saving the managed configuration table"
#ruby SaveManagedConfig.rb

# perform initial ruby migration scripts
ruby MigrateInit1.rb > init1.log
ruby MigrateOrg2.rb > org2.log
ruby MigrateUsers3.rb > users3.log
ruby MigrateVocabularyWord4.rb > vocab4.log
ruby MigrateSubmission5.rb > submission5.log
ruby MigrateActionLog6.rb > actionlog6.log
ruby MigrateCustomActions7.rb > customactions7.log
ruby MigrateFinal8.rb > final8.log

echo "Restoring the managed configuration table"
#ruby RestoreManagedConfig.rb

#perform date fix scripts - omit final_add.sql, as this action is better done in the 4.2.8 schema change scripts
exgo "Performing the date fixes"
cd ${DATE_DIR} || exit
psql -U ${DB_USER} -d ${DATABASE} < alter_nsfg.sql
psql -U ${DB_USER} -d ${DATABASE} < graduationDate_migrate_validators_1.sql
psql -U ${DB_USER} -d ${DATABASE} < graduationDate_migrate_baddata_2.sql
psql -U ${DB_USER} -d ${DATABASE} < graduationDate_migrate_gradsem_3.sql
psql -U ${DB_USER} -d ${DATABASE} < graduationDate_migrate_gradsem_4.sql
psql -U ${DB_USER} -d ${DATABASE} < defenseDate_migrate_5.sql
#final_add.sql
cd ..

echo "Performing the 4.2.8 schema changes"
#perform 4.2.8 schema change scripts
cd ${SCHEMA_CHANGE_DIR} || exit
psql -U ${DB_USER} -d ${DATABASE} < 428_submission_action_log_column_0.sql
psql -U ${DB_USER} -d ${DATABASE} < 428_submission_list_column_constraints_1.sql
psql -U ${DB_USER} -d ${DATABASE} < 428_submission_action_log_column_data_2.sql
psql -U ${DB_USER} -d ${DATABASE} < 428_managed_configuration_lowercase_update_3.sql
psql -U ${DB_USER} -d ${DATABASE} < 428_submission_list_column_graduationsemester_list_4.sql
psql -U ${DB_USER} -d ${DATABASE} < 428_submission_list_column_submissiontype_list_5.sql
psql -U ${DB_USER} -d ${DATABASE} < 428_submission_list_column_studentname_6.sql
psql -U ${DB_USER} -d ${DATABASE} < 428_submission_list_column_lastevent_7.sql
cd ..
echo "Migration complete!"
