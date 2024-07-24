#!/bin/bash

set -ueExo pipefail

B=~/.nargo/backends/acvm-backend-barretenberg/backend_binary
D=$(git rev-parse --show-toplevel)

# verify that the generated recursive proof is valid
jq -r '.bytecode' $D/target/noir_safe_aggregation_circuit.json | base64 -d > $D/target/noir_safe_aggregation_circuit.gz
$B write_vk -b $D/target/noir_safe_aggregation_circuit.gz -o $D/target/ag_vk
#TODO pass proof as bin
#xxd -r -p $D/proofs/noir_safe_account_proof_circuit.proof $D/proofs/noir_safe_account_proof_circuit.proof.bin
$B verify -p $D/proofs/noir_safe_aggregation_circuit.proof -k $D/target/ag_vk
