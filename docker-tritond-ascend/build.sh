#!/bin/sh
#
# Script to build the docker image.
#
set -x

docker build \
    -t triton-dist-ascend:20261020 \
    -f Dockerfile .
