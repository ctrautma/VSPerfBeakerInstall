#!/usr/bin/env bash

./Rhel7VSPerf.sh || echo "Error during RHel7vsperf script"; exit 1
./DevVSPerf.sh || echo "Error during dev environment setup"; exit 1
