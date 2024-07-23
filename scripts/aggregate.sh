#!/bin/bash

set -ueExo pipefail

# https://github.com/noir-lang/noir/blob/master/examples/recursion/generate_recursive_proof.sh
#TODO run shard provers in parallel

d=$(git rev-parse --show-toplevel)

nargo execute --package noir_safe_storage_proof_circuit sp_witness
nargo execute --package noir_safe_account_proof_circuit ap_witness
# nargo prove --package noir_safe_storage_proof_circuit
# nargo prove --package noir_safe_account_proof_circuit
bb prove -b $d/target/noir_safe_storage_proof_circuit.json -w ./target/sp_witness.gz -o ./target/sp_proof
bb prove -b $d/target/noir_safe_account_proof_circuit.json -w ./target/ap_witness.gz -o ./target/ap_proof

# generate aggregation artifacts from the storage proof circuit
bb write_vk -b $d/target/noir_safe_storage_proof_circuit.json -o $d/target/sp_vk
bb vk_as_fields -k $d/target/sp_vk -o $d/target/sp_vk_as_fields
SP_VK_HASH=$(jq -r '.[0]' $d/target/sp_vk_as_fields)
SP_VK_AS_FIELDS=$(jq -r '.[1:]' $d/target/sp_vk_as_fields)
SP_FULL_PROOF_AS_FIELDS="$(bb proof_as_fields -p $d/proofs/sp_proof -k $d/target/sp_vk -o -)"
# storage proof circuit has 4 public inputs (excluding aggregation object)
SP_PUBLIC_INPUTS=$(echo $SP_FULL_PROOF_AS_FIELDS | jq -r '.[:4]')
SP_PROOF_AS_FIELDS=$(echo $SP_FULL_PROOF_AS_FIELDS | jq -r '.[4:]')

# generate aggregation artifacts from the account proof circuit
bb write_vk -b $d/target/noir_safe_account_proof_circuit.json -o $d/target/ap_vk
bb vk_as_fields -k $d/target/ap_vk -o $d/target/ap_vk_as_fields
AP_VK_HASH=$(jq -r '.[0]' $d/target/ap_vk_as_fields)
AP_VK_AS_FIELDS=$(jq -r '.[1:]' $d/target/ap_vk_as_fields)
AP_FULL_PROOF_AS_FIELDS="$(bb proof_as_fields -p $d/proofs/ap_proof -k $d/target/ap_vk -o -)"
# account proof circuit has 5 public inputs (excluding aggregation object)
AP_PUBLIC_INPUTS=$(echo $AP_FULL_PROOF_AS_FIELDS | jq -r '.[:5]')
AP_PROOF_AS_FIELDS=$(echo $AP_FULL_PROOF_AS_FIELDS | jq -r '.[5:]')

# aggregate
AGGREGATION_PROVER_TOML=$d/circuits/aggregation/Prover.toml
echo "sp_vk_hash = \"$SP_VK_HASH\"" > $AGGREGATION_PROVER_TOML
echo "sp_vk = $SP_VK_AS_FIELDS"  >> $AGGREGATION_PROVER_TOML
echo "sp_proof = $SP_PROOF_AS_FIELDS" >> $AGGREGATION_PROVER_TOML
echo "sp_pi = $SP_PUBLIC_INPUTS" >> $AGGREGATION_PROVER_TOML
echo "ap_vk_hash = \"$AP_VK_HASH\"" > $AGGREGATION_PROVER_TOML
echo "ap_vk = $AP_VK_AS_FIELDS"  >> $AGGREGATION_PROVER_TOML
echo "ap_proof = $AP_PROOF_AS_FIELDS" >> $AGGREGATION_PROVER_TOML
echo "ap_pi = $AP_PUBLIC_INPUTS" >> $AGGREGATION_PROVER_TOML

nargo execute --package noir_safe_aggregation_circuit ag_witness 
bb prove -b $d/target/noir_safe_aggregation_circuit.json -w ./target/ag_witness.gz -o ./target/ag_proof

# verify that the generated recursive proof is valid
bb write_vk -b ./target/noir_safe_aggregation_circuit.json -o ./target/ag_vk
bb verify -p ./target/ag_proof -k ./target/ag_vk

#TODO gen sol verifier