#!/bin/bash

set -ueExo pipefail

#FROM https://github.com/noir-lang/noir/blob/master/examples/recursion/generate_recursive_proof.sh

#TODO run shard provers in parallel

#NOTE assumes noir+nargo@v0.29.0 (install with `noirup -v v0.29.0`)
nargo --version

b=~/.nargo/backends/acvm-backend-barretenberg/backend_binary
d=$(git rev-parse --show-toplevel)

###

nargo prove --package noir_safe_storage_proof_circuit
xxd -r -p $d/proofs/noir_safe_storage_proof_circuit.proof $d/proofs/noir_safe_storage_proof_circuit.proof.bin

#WIP generate aggregation artifacts from the storage proof circuit
jq -r '.bytecode' $d/target/noir_safe_storage_proof_circuit.json | base64 -d > $d/target/noir_safe_storage_proof_circuit.gz
$b write_vk -b $d/target/noir_safe_storage_proof_circuit.gz -o $d/target/sp_vk
# $b write_vk -b $d/target/noir_safe_storage_proof_circuit.json -o $d/target/sp_vk
$b vk_as_fields -k $d/target/sp_vk -o $d/target/sp_vk_as_fields
SP_VK_HASH=$(jq -r '.[0]' $d/target/sp_vk_as_fields)
SP_VK_AS_FIELDS=$(jq -r '.[1:]' $d/target/sp_vk_as_fields)
SP_FULL_PROOF_AS_FIELDS="$($b proof_as_fields -p $d/proofs/noir_safe_storage_proof_circuit.proof.bin -k $d/target/sp_vk -o -)"
# storage proof circuit has 4 public inputs (excluding aggregation object)
SP_PUBLIC_INPUTS=$(echo $SP_FULL_PROOF_AS_FIELDS | jq -r '.[:4]')
SP_PROOF_AS_FIELDS=$(echo $SP_FULL_PROOF_AS_FIELDS | jq -r '.[4:]')

###

nargo prove --package noir_safe_account_proof_circuit
xxd -r -p $d/proofs/noir_safe_account_proof_circuit.proof $d/proofs/noir_safe_account_proof_circuit.proof.bin

#WIP generate aggregation artifacts from the account proof circuit
jq -r '.bytecode' $d/target/noir_safe_account_proof_circuit.json | base64 -d > $d/target/noir_safe_account_proof_circuit.gz
$b write_vk -b $d/target/noir_safe_account_proof_circuit.gz -o $d/target/ap_vk
$b vk_as_fields -k $d/target/ap_vk -o $d/target/ap_vk_as_fields
AP_VK_HASH=$(jq -r '.[0]' $d/target/ap_vk_as_fields)
AP_VK_AS_FIELDS=$(jq -r '.[1:]' $d/target/ap_vk_as_fields)
AP_FULL_PROOF_AS_FIELDS="$($b proof_as_fields -p $d/proofs/noir_safe_account_proof_circuit.proof.bin -k $d/target/ap_vk -o -)"
# account proof circuit has 5 public inputs (excluding aggregation object)
AP_PUBLIC_INPUTS=$(echo $AP_FULL_PROOF_AS_FIELDS | jq -r '.[:5]')
AP_PROOF_AS_FIELDS=$(echo $AP_FULL_PROOF_AS_FIELDS | jq -r '.[5:]')

###

# aggregate
AGGREGATION_PROVER_TOML=$d/circuits/aggregation/Prover.toml
echo "sp_vk_hash = \"$SP_VK_HASH\"" > $AGGREGATION_PROVER_TOML
echo "sp_vk = $SP_VK_AS_FIELDS"  >> $AGGREGATION_PROVER_TOML
echo "sp_proof = $SP_PROOF_AS_FIELDS" >> $AGGREGATION_PROVER_TOML
echo "sp_pi = $SP_PUBLIC_INPUTS" >> $AGGREGATION_PROVER_TOML
echo "ap_vk_hash = \"$AP_VK_HASH\"" >> $AGGREGATION_PROVER_TOML
echo "ap_vk = $AP_VK_AS_FIELDS"  >> $AGGREGATION_PROVER_TOML
echo "ap_proof = $AP_PROOF_AS_FIELDS" >> $AGGREGATION_PROVER_TOML
echo "ap_pi = $AP_PUBLIC_INPUTS" >> $AGGREGATION_PROVER_TOML

nargo prove --package noir_safe_aggregation_circuit