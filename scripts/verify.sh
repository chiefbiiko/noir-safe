#!/bin/bash

set -ueExo pipefail

B=~/.nargo/backends/acvm-backend-barretenberg/backend_binary
D=$(git rev-parse --show-toplevel)

# verify that the generated recursive proof is valid
$B write_vk -b $D/target/noir_safe_aggregation_circuit.json -o $D/target/ag_vk
$B verify -p $D/proofs/noir_safe_aggregation_circuit.proof -k $D/target/ag_vk
