#!/bin/bash

set -ueExo pipefail

B=~/.nargo/backends/acvm-backend-barretenberg/backend_binary
D=$(git rev-parse --show-toplevel)

# blockhash=$(yq -r '.blockhash' $D/circuits/anchor/Prover.toml)
# challenge=$(yq -r '.challenge' $D/circuits/anchor/Prover.toml)
# echo ${blockhash#0x} > $D/proofs/noir_safe_aggregation_circuit.proof.out
# echo ${challenge#0x} >> $D/proofs/noir_safe_aggregation_circuit.proof.out
# cat $D/proofs/noir_safe_aggregation_circuit.proof >> $D/proofs/noir_safe_aggregation_circuit.proof.out
# xxd -r -p $D/proofs/noir_safe_aggregation_circuit.proof.out $D/proofs/noir_safe_aggregation_circuit.proof.out.bin
# $B verify -p $D/proofs/noir_safe_aggregation_circuit.proof.out.bin -k $D/target/ag_vk

# xxd -r -p $D/proofs/noir_safe_aggregation_circuit.proof $D/proofs/noir_safe_aggregation_circuit.proof.bin
# $B verify -p $D/proofs/noir_safe_aggregation_circuit.proof.bin -k $D/target/ag_vk

$B verify -p $D/target/ag_proof.bin -k $D/target/ag_vk