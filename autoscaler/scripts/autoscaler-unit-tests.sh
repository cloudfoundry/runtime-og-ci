#!/bin/bash
set -x
set -e

service postgresql start
psql postgres://postgres@127.0.0.1:5432 -c 'DROP DATABASE IF EXISTS autoscaler'
psql postgres://postgres@127.0.0.1:5432 -c 'CREATE DATABASE autoscaler'

cd app-autoscaler

POSTGRES_OPTS='--username=postgres --url=jdbc:postgresql://127.0.0.1/autoscaler --driver=org.postgresql.Driver'

mvn package
java -cp 'db/target/lib/*' liquibase.integration.commandline.Main $POSTGRES_OPTS --changeLogFile=api/db/api.db.changelog.yml update
java -cp 'db/target/lib/*' liquibase.integration.commandline.Main $POSTGRES_OPTS --changeLogFile=servicebroker/db/servicebroker.db.changelog.json update
java -cp 'db/target/lib/*' liquibase.integration.commandline.Main $POSTGRES_OPTS --changeLogFile=src/metricscollector/db/metricscollector.db.changelog.yml update
java -cp 'db/target/lib/*' liquibase.integration.commandline.Main $POSTGRES_OPTS --changeLogFile=src/eventgenerator/db/dataaggregator.db.changelog.yml update
java -cp 'db/target/lib/*' liquibase.integration.commandline.Main $POSTGRES_OPTS --changeLogFile=scheduler/db/scheduler.changelog-master.yaml update
java -cp 'db/target/lib/*' liquibase.integration.commandline.Main $POSTGRES_OPTS --changeLogFile=scheduler/db/quartz.changelog-master.yaml update

npm set progress=false

pushd api
npm install
npm test
popd

pushd servicebroker
npm install
npm test
popd

export GOPATH=$PWD
export PATH=$GOPATH/bin:$PATH
go install github.com/onsi/ginkgo/ginkgo

for f in cf db models metricscollector eventgenerator scalingengine
do
  pushd src/$f
  DBURL=postgres://postgres@localhost/autoscaler?sslmode=disable ginkgo -r -race -randomizeAllSpecs
  popd
done

pushd scheduler
mvn test
popd
