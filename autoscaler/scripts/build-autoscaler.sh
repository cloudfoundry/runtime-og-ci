#!/bin/bash
set -x -e

OUTPUT_DIR=$PWD/autoscaler-output

pushd app-autoscaler

cat > profiles/sample.properties <<EOF
#CloudFoundry settings
cfUrl=api.bosh-lite.com
cfClientId=cf-autoscaler-client
cfClientSecret=cf-autoscaler-client-secret

#http basic authentication settings between the CF-Autoscaler components
internalAuthUsername=admin
internalAuthPassword=admin

# service broker settings
serviceName=cf-autoscaler
brokerUsername=admin
brokerPassword=admin

# Scaling server URLs and protocol settings
scalingServerURIList=https://autoscaling.bosh-lite.com
apiServerURI=https://autoscalingapi.bosh-lite.com

#couchdb settings
couchdbUsername=autoscaler
couchdbPassword=openopen
couchdbHost=$BOSH_LITE_IP
couchdbPort=5984
couchdbServerDBName=couchdb-scaling
couchdbBrokerDBName=couchdb-scalingbroker
couchdbMetricDBPrefix=couchdb-scalingmetric

#metrics settings
reportInterval=20
EOF

mvn clean package -Denv=sample -DskipTests=true
for d in api server servicebroker; do
  mv $d/target/*.war $OUTPUT_DIR
done

popd
