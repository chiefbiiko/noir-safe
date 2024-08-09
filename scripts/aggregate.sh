#!/bin/bash

set -ueExo pipefail

#FROM https://github.com/noir-lang/noir/blob/master/examples/recursion/generate_recursive_proof.sh
#TODO run shard provers in parallel

B=~/.nargo/backends/acvm-backend-barretenberg/backend_binary
D=$(git rev-parse --show-toplevel)
VK_TOML=$D/target/vk.toml
AGGREGATION_PROVER_TOML=$D/circuits/aggregation/Prover.toml
# AGGREGATION_VERIFIER_TOML=$D/circuits/aggregation/Verifier.toml

###

# nargo prove --package noir_safe_storage_proof_circuit
# xxd -r -p $D/proofs/noir_safe_storage_proof_circuit.proof $D/proofs/noir_safe_storage_proof_circuit.proof.bin
# SP_FULL_PROOF_AS_FIELDS="$($B proof_as_fields -p $D/proofs/noir_safe_storage_proof_circuit.proof.bin -k $D/target/sp_vk -o -)"

nargo execute --package noir_safe_storage_proof_circuit sp_witness
$B prove -b $D/target/sp_circuit -w $D/target/sp_witness.gz -o $D/target/sp_proof.bin
SP_FULL_PROOF_AS_FIELDS="$($B proof_as_fields -p $D/target/sp_proof.bin -k $D/target/sp_vk -o -)"

###

# nargo prove --package noir_safe_account_proof_circuit
# xxd -r -p $D/proofs/noir_safe_account_proof_circuit.proof $D/proofs/noir_safe_account_proof_circuit.proof.bin
# AP_FULL_PROOF_AS_FIELDS="$($B proof_as_fields -p $D/proofs/noir_safe_account_proof_circuit.proof.bin -k $D/target/ap_vk -o -)"

nargo execute --package noir_safe_account_proof_circuit ap_witness
$B prove -b $D/target/ap_circuit -w $D/target/ap_witness.gz -o $D/target/ap_proof.bin
AP_FULL_PROOF_AS_FIELDS="$($B proof_as_fields -p $D/target/ap_proof.bin -k $D/target/ap_vk -o -)"

###

# nargo prove --package noir_safe_anchor_circuit

# # If program has any public inputs/return values these need to be prepended
# #SEE https://discord.com/channels/1113924620781883405/1113924622031798313/1182461084616118363
# blockhash=$(yq -r '.blockhash' $D/circuits/anchor/Prover.toml)
# challenge=$(yq -r '.challenge' $D/circuits/anchor/Prover.toml)
# echo ${blockhash#0x} > $D/proofs/noir_safe_anchor_circuit.proof.out
# echo ${challenge#0x} >> $D/proofs/noir_safe_anchor_circuit.proof.out
# cat $D/proofs/noir_safe_anchor_circuit.proof >> $D/proofs/noir_safe_anchor_circuit.proof.out

# xxd -r -p $D/proofs/noir_safe_anchor_circuit.proof.out $D/proofs/noir_safe_anchor_circuit.proof.out.bin
# AN_FULL_PROOF_AS_FIELDS="$($B proof_as_fields -p $D/proofs/noir_safe_anchor_circuit.proof.out.bin -k $D/target/an_vk -o -)"
# AN_PROOF_AS_FIELDS=$(echo $AN_FULL_PROOF_AS_FIELDS | jq -r '.[2:]')

nargo execute --package noir_safe_anchor_circuit an_witness
$B prove -b $D/target/an_circuit -w $D/target/an_witness.gz -o $D/target/an_proof.bin
AN_FULL_PROOF_AS_FIELDS="$($B proof_as_fields -p $D/target/an_proof.bin -k $D/target/an_vk -o -)"
AN_PROOF_AS_FIELDS="$(echo $AN_FULL_PROOF_AS_FIELDS | jq -r '.[2:]')"

###

blockhash=$(yq -r '.blockhash' $D/circuits/anchor/Prover.toml)
challenge=$(yq -r '.challenge' $D/circuits/anchor/Prover.toml)
cat $VK_TOML > $AGGREGATION_PROVER_TOML
echo "sp_proof = $SP_FULL_PROOF_AS_FIELDS
sp_pi = []
ap_proof = $AP_FULL_PROOF_AS_FIELDS
ap_pi = []
an_proof = $AN_PROOF_AS_FIELDS
an_pi = [\"$blockhash\", \"$challenge\"]
" >> $AGGREGATION_PROVER_TOML

# echo "an_pi = [\"$blockhash\", \"$challenge\"]" > $AGGREGATION_VERIFIER_TOML

# nargo prove --package noir_safe_aggregation_circuit

nargo execute --package noir_safe_aggregation_circuit ag_witness
$B prove -b $D/target/ag_circuit -w $D/target/ag_witness.gz -o $D/target/ag_proof.bin