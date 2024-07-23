#!/bin/bash

set -ueExo pipefail

d=$(git rev-parse --show-toplevel)

# verify that the generated recursive proof is valid
bb write_vk -b $d/target/noir_safe_aggregation_circuit.json -o $d/target/ag_vk
bb verify -p $d/proofs/noir_safe_aggregation_circuit.proof -k $d/target/ag_vk
