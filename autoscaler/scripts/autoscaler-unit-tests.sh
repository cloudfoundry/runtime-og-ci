#!/bin/bash
set -x

cd app-autoscaler

mvn test -Denv=unittest
