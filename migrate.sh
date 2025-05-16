#!/bin/sh

# set script variables
DB_USER="vireo"
DATABASE="vireo4"

DATE_DIR="DateFixSql"
SCHEMA_CHANGE_DIR="428SchemaChangeSql"

# Create correct hashes for files and to convert admin_groups email hashmap from v3 to v4
javac HashMapFromHex.java
javac hash.java
# this is needed for encoding the deposit_location password from vireo3. Before this is compiled the secret Key must
# be set with setKey() in main().
javac DepLocEncode.java

echo "Performing Vireo 3 to Vireo 4 migration"
echo -n "Starting at "
date -d "now" +"%H:%M"
echo -n "The entire process will take about 90 minutes, should be done around "
date -d "now + 90 minutes" + "%H:%M"

# the original Ruby migration process in run.script
# echo "Saving the managed configuration table"
# ruby SaveManagedConfig.rb - this is done in prepare.sh

# perform initial ruby migration scripts
echo "Performing initial Ruby migration scripts"
echo "This part of the migration should take about 80 minutes."
echo "Initial migration"
ruby MigrateInit1.rb > init1.log
echo "Migrating organization"
ruby MigrateOrg2.rb > org2.log
echo "Migrating users"
ruby MigrateUsers3.rb > users3.log
echo "Migrating vocabulary"
ruby MigrateVocabularyWord4.rb > vocab4.log
echo "Migrating submissions (this will take a little over 70 minutes)"
ruby MigrateSubmission5.rb > submission5.log
echo "Migrating action log"
ruby MigrateActionLog6.rb > actionlog6.log
echo "Migrating custom actions"
ruby MigrateCustomActions7.rb > customactions7.log
echo "Final migration"
ruby MigrateFinal8.rb > final8.log
echo "Ruby scripts complete"

echo "Restoring the managed configuration table"
ruby RestoreManagedConfig.rb

# perform date fix scripts - omit final_add.sql, as this action is better done in the 4.2.8 schema change scripts
echo
echo "Performing the date fixes"
cd ${DATE_DIR} || exit
# psql -U ${DB_USER} -d ${DATABASE} < alter_nsfg.sql
echo "Performing the graduation date validator fixes"
psql -U ${DB_USER} -d ${DATABASE} < graduationDate_migrate_validators_1.sql
echo "Performing the graduation date data fixes"
psql -U ${DB_USER} -d ${DATABASE} < graduationDate_migrate_baddata_2.sql
echo "Performing the graduation date semester fixes"
psql -U ${DB_USER} -d ${DATABASE} < graduationDate_migrate_gradsem_3.sql
psql -U ${DB_USER} -d ${DATABASE} < graduationDate_migrate_gradsem_4.sql
echo "Performing the defense date fixes"
psql -U ${DB_USER} -d ${DATABASE} < defenseDate_migrate_5.sql
#echo "Performing the final date fixes"
#psql -U ${DB_USER} -d ${DATABASE} < final_add.sql
echo "Date fixes complete"
cd ..

echo
echo "Performing the 4.2.8 schema changes"
# perform 4.2.8 schema change scripts
cd ${SCHEMA_CHANGE_DIR} || exit
echo "Performing the submission action log column changes (0)"
psql -U ${DB_USER} -d ${DATABASE} < 428_submission_action_log_column_0.sql
echo "Performing the submission list column constraints changes (1)"
psql -U ${DB_USER} -d ${DATABASE} < 428_submission_list_column_constraints_1.sql
echo "Performing the submission list column data changes (2) changes"
psql -U ${DB_USER} -d ${DATABASE} < 428_submission_action_log_column_data_2.sql
echo "Performing the managed configuration changes (3) changes"
psql -U ${DB_USER} -d ${DATABASE} < 428_managed_configuration_lowercase_update_3.sql
echo "Performing the submission list column graduationsemester changes (4) changes"
psql -U ${DB_USER} -d ${DATABASE} < 428_submission_list_column_graduationsemester_list_4.sql
echo "Performing the submission list column submissiontype_list changes (5) changes"
psql -U ${DB_USER} -d ${DATABASE} < 428_submission_list_column_submissiontype_list_5.sql
echo "Performing the submission list column studentname  changes (6) changes"
psql -U ${DB_USER} -d ${DATABASE} < 428_submission_list_column_studentname_6.sql
echo "Performing the submission list column lastevent changes (7) changes"
psql -U ${DB_USER} -d ${DATABASE} < 428_submission_list_column_lastevent_7.sql
echo "Schema changes complete"
cd ..

# post processing
psql -U ${DB_USER} -d ${DATABASE} < post-process.sql

echo -n "Migration complete at "
date -d "now" +"%H:%M"