#!/bin/bash

set -x -e

CF_RELEASE_DIR="$PWD/cf-release"

source ~/.bashrc

bosh -n target $BOSH_TARGET lite
bosh login $BOSH_USERNAME $BOSH_PASSWORD

wget https://github.com/cloudfoundry-incubator/spiff/releases/download/v1.0.7/spiff_linux_amd64
mkdir bin
mv spiff_linux_amd64 bin/spiff
chmod 755 bin/spiff

export PATH=$PWD/bin:$PATH

pushd "${CF_RELEASE_DIR}" > /dev/null
  scripts/generate-bosh-lite-dev-manifest
popd > /dev/null

pushd diego-release
  USE_SQL='postgres' ./scripts/generate-bosh-lite-manifests
popd

cp $CF_RELEASE_DIR/bosh-lite/deployments/cf.yml "generate-manifest-artifacts/manifest.yml"
cp diego-release/bosh-lite/deployments/diego.yml "generate-manifest-artifacts/diego.yml"
