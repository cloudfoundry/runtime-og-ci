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
  CF_RELEASE_MANIFEST="${CF_RELEASE_DIR}/bosh-lite/deployments/cf.yml"

  version=`tail -2 releases/index.yml | grep " version: " | cut -f 2 -d "'"`
  bosh -n upload release releases/cf-$version.yml
  bosh -n -d "${CF_RELEASE_MANIFEST}" deploy

  bosh -n cleanup --all

popd > /dev/null
