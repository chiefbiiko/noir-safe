#!/bin/bash

set -ueExo pipefail

#FROM https://github.com/noir-lang/noir/blob/master/examples/recursion/generate_recursive_proof.sh

#TODO run shard provers in parallel

b=~/.nargo/backends/acvm-backend-barretenberg/backend_binary
d=$(git rev-parse --show-toplevel)

###

nargo prove --package noir_safe_storage_proof_circuit
xxd -r -p $d/proofs/noir_safe_storage_proof_circuit.proof $d/proofs/noir_safe_storage_proof_circuit.proof.bin

SP_FULL_PROOF_AS_FIELDS="$($b proof_as_fields -p $d/proofs/noir_safe_storage_proof_circuit.proof.bin -k $d/target/sp_vk -o -)"
# storage proof circuit has 4 public inputs (excluding aggregation object)
SP_PUBLIC_INPUTS=$(echo $SP_FULL_PROOF_AS_FIELDS | jq -r '.[:4]')
SP_PROOF_AS_FIELDS=$(echo $SP_FULL_PROOF_AS_FIELDS | jq -r '.[4:]')

###

nargo prove --package noir_safe_account_proof_circuit
xxd -r -p $d/proofs/noir_safe_account_proof_circuit.proof $d/proofs/noir_safe_account_proof_circuit.proof.bin

AP_FULL_PROOF_AS_FIELDS="$($b proof_as_fields -p $d/proofs/noir_safe_account_proof_circuit.proof.bin -k $d/target/ap_vk -o -)"
# account proof circuit has 5 public inputs (excluding aggregation object)
AP_PUBLIC_INPUTS=$(echo $AP_FULL_PROOF_AS_FIELDS | jq -r '.[:5]')
AP_PROOF_AS_FIELDS=$(echo $AP_FULL_PROOF_AS_FIELDS | jq -r '.[5:]')

###

# aggregate
VK_TOML=$d/target/vk.toml
AGGREGATION_PROVER_TOML=$d/circuits/aggregation/Prover.toml
cat $VK_TOML > $AGGREGATION_PROVER_TOML
echo "sp_proof = $SP_PROOF_AS_FIELDS" >> $AGGREGATION_PROVER_TOML
echo "sp_pi = $SP_PUBLIC_INPUTS" >> $AGGREGATION_PROVER_TOML
echo "ap_proof = $AP_PROOF_AS_FIELDS" >> $AGGREGATION_PROVER_TOML
echo "ap_pi = $AP_PUBLIC_INPUTS" >> $AGGREGATION_PROVER_TOML

nargo prove --package noir_safe_aggregation_circuit