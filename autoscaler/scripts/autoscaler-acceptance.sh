#!/bin/bash
set -x -e

apt-get -y update
apt-get -y install dnsmasq
echo -e "\n\naddress=/.bosh-lite.com/$BOSH_TARGET" >> /etc/dnsmasq.conf
sed -i '1 i\nameserver 127.0.0.1' /etc/resolv.conf
echo 'starting dnsmasq'
dnsmasq

mkdir bin
pushd bin
  curl -L 'https://cli.run.pivotal.io/stable?release=linux64-binary&source=github-rel' | tar xz
popd
export PATH=$PWD/bin:$PATH

cf api https://api.bosh-lite.com:443 --skip-ssl-validation
cf auth admin admin

set +e
cf delete-service-broker -f CF-AutoScaler
set -e

cf create-service-broker CF-AutoScaler username password http://servicebroker-0.node.cf.internal:6101
cf enable-service-access autoscaler

export GOPATH=$PWD/app-autoscaler-release
pushd app-autoscaler-release/src/acceptance
cat > acceptance_config.json <<EOF
{
  "api": "api.bosh-lite.com",
  "admin_user": "admin",
  "admin_password": "admin",
  "apps_domain": "bosh-lite.com",
  "skip_ssl_validation": true,
  "use_http": false,

  "service_name": "CF-AutoScaler",
  "service_plan": "autoscaler-free-plan",
  "api_url": "http://servicebroker-0.node.cf.internal:6101",
	"report_interval": 20
}
EOF

CONFIG=$PWD/acceptance_config.json ./bin/test_default -nodes=2

popd
