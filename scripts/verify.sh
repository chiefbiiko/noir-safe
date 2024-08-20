#!/bin/bash

set -ueExo pipefail

B=~/.bb/bb
D=$(git rev-parse --show-toplevel)

$B verify -p $D/target/ag_proof.bin -k $D/target/ag_vk