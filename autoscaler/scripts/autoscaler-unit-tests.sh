#!/bin/bash
set -x
set -e

service postgresql start
psql postgres://postgres@127.0.0.1:5432 -c 'DROP DATABASE IF EXISTS autoscaler'
psql postgres://postgres@127.0.0.1:5432 -c 'CREATE DATABASE autoscaler'

cd app-autoscaler

mvn package
java -cp 'db/target/lib/*'  liquibase.integration.commandline.Main --username=postgres --changeLogFile=api/db/api.db.changelog.yml --url jdbc:postgresql://127.0.0.1/autoscaler --driver=org.postgresql.Driver update
java -cp 'db/target/lib/*'  liquibase.integration.commandline.Main --username=postgres --changeLogFile=servicebroker/db/servicebroker.db.changelog.yml --url jdbc:postgresql://127.0.0.1/autoscaler --driver=org.postgresql.Driver update

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

pushd src/metricscollector
ginkgo -r -race
popd
