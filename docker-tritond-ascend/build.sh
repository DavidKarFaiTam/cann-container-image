#!/bin/sh
#
# Script to build the docker image.
#
set -x

docker build \
    -t triton-dist-ascend:20260909 \
    -f Dockerfile .
