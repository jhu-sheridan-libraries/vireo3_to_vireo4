#!/bin/bash
# Clean out existing database and create a new empty one

# set script variables
DB_USER="vireo"
DATABASE="vireo4"

# echo "Saving the managed configuration table"
ruby SaveManagedConfig.rb

if psql ${DATABASE} -c '' 2>&1
then
	echo "Database ${DATABASE} exists, dropping."
	dropdb ${DATABASE}
fi
echo "Creating database ${DATABASE}"
createdb ${DATABASE}
psql -U ${DB_USER} -d ${DATABASE} -c "GRANT ALL PRIVILEGES ON DATABASE ${DATABASE} TO ${DB_USER};"