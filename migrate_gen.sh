#! /bin/bash

set -eu

mysql -uroot -h 0.0.0.0 -P 13306 < ./ddl/default.sql

migrations=`find ddl/migration -type f -name \*.up.sql | wc -l`
if [ $migrations -ne "0" ]; then
  yes | migrate -path ddl/migration -database "mysql://root:@tcp(localhost:13306)/migration" up
fi

docker-compose exec db mysqldump -uroot \
  -d migration \
  --ignore-table="migration.schema_migrations" > dump.sql

diff=`schemadiff -t=false dump.sql ./ddl/init/1_main.up.sql`

if [ -n "$diff" ]; then
  echo $diff > ddl/migration/$(date +%s)_migration_gen.up.sql
fi

rm dump.sql
