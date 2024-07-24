#!/bin/bash

set -ueExo pipefail

b=~/.nargo/backends/acvm-backend-barretenberg/backend_binary
d=$(git rev-parse --show-toplevel)

# verify that the generated recursive proof is valid
$b write_vk -b $d/target/noir_safe_aggregation_circuit.json -o $d/target/ag_vk
$b verify -p $d/proofs/noir_safe_aggregation_circuit.proof -k $d/target/ag_vk
