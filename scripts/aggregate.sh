#!/bin/bash

set -ueExo pipefail

#FROM https://github.com/noir-lang/noir/blob/master/examples/recursion/generate_recursive_proof.sh
#TODO run shard provers in parallel

B=~/.nargo/backends/acvm-backend-barretenberg/backend_binary
D=$(git rev-parse --show-toplevel)
VK_TOML=$D/target/vk.toml
AGGREGATION_PROVER_TOML=$D/circuits/aggregation/Prover.toml

###

nargo prove --package noir_safe_storage_proof_circuit
xxd -r -p $D/proofs/noir_safe_storage_proof_circuit.proof $D/proofs/noir_safe_storage_proof_circuit.proof.bin
SP_FULL_PROOF_AS_FIELDS="$($B proof_as_fields -p $D/proofs/noir_safe_storage_proof_circuit.proof.bin -k $D/target/sp_vk -o -)"

###

nargo prove --package noir_safe_account_proof_circuit
xxd -r -p $D/proofs/noir_safe_account_proof_circuit.proof $D/proofs/noir_safe_account_proof_circuit.proof.bin
AP_FULL_PROOF_AS_FIELDS="$($B proof_as_fields -p $D/proofs/noir_safe_account_proof_circuit.proof.bin -k $D/target/ap_vk -o -)"

###

nargo prove --package noir_safe_anchor_circuit
xxd -r -p $D/proofs/noir_safe_anchor_circuit.proof $D/proofs/noir_safe_anchor_circuit.proof.bin
AN_FULL_PROOF_AS_FIELDS="$($B proof_as_fields -p $D/proofs/noir_safe_anchor_circuit.proof.bin -k $D/target/an_vk -o -)"

###

cat $VK_TOML > $AGGREGATION_PROVER_TOML
echo "sp_proof = $SP_FULL_PROOF_AS_FIELDS
sp_pi = []
ap_proof = $AP_FULL_PROOF_AS_FIELDS
ap_pi = []
an_proof = $AN_FULL_PROOF_AS_FIELDS
an_pi = []
" >> $AGGREGATION_PROVER_TOML

nargo prove --package noir_safe_aggregation_circuit