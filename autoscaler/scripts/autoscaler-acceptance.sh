#!/bin/bash
set -x -e

apt-get -y update
apt-get -y install dnsmasq
echo -e "\n\naddress=/.bosh-lite.com/$BOSH_LITE_IP" >> /etc/dnsmasq.conf
sed -i '1 i\nameserver 127.0.0.1' /etc/resolv.conf
echo 'starting dnsmasq'
dnsmasq

gem install cf-uaac --no-ri --no-rdoc
uaac target https://uaa.bosh-lite.com --skip-ssl-validation
uaac token client get admin -s admin-secret
set +e
uaac client add cf-autoscaler-client \
	--name cf-autoscaler \
    --authorized_grant_types client_credentials \
    --authorities cloud_controller.read,cloud_controller.admin \
    --secret cf-autoscaler-client-secret
set -e

mkdir bin
pushd bin
  curl -L 'https://cli.run.pivotal.io/stable?release=linux64-binary&source=github-rel' | tar xz
popd
export PATH=$PWD/bin:$PATH

cf api https://api.bosh-lite.com:443 --skip-ssl-validation
cf auth admin admin

set +e
cf create-org scaling-org
cf t -o scaling-org
cf create-space scaling-space
cf t -s scaling-space

cat > boshlite.json << EOF
[
  {
    "protocol": "tcp",
    "destination": "$BOSH_LITE_IP",
    "ports": "5984"
  }
]
EOF
cf create-security-group boshlite boshlite.json
cf bind-running-security-group boshlite
set -e

cf push autoscaling -p autoscaler-output/server-*.war -m 512M
cf push autoscalingapi -p autoscaler-output/api-*.war
cf push autoscalingbroker -p autoscaler-output/servicebroker-*.war

set +e
cf delete-service-broker -f CF-AutoScaler
set -e

cf create-service-broker CF-AutoScaler admin admin https://autoscalingbroker.bosh-lite.com
cf enable-service-access CF-AutoScaler

pushd app-autoscaler/src/acceptance
cat > integration_config.json <<EOF
{
  "api": "api.bosh-lite.com",
  "admin_user": "admin",
  "admin_password": "admin",
  "apps_domain": "bosh-lite.com",
  "skip_ssl_validation": true,
  "use_http": false,

  "service_name": "CF-AutoScaler",
  "api_url": "https://autoscalingapi.bosh-lite.com",
	"report_interval": 20
}
EOF

CONFIG=$PWD/integration_config.json ./bin/test_default -nodes=2

popd
