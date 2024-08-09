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

#NOTE
# wen declaring the aggregation circuit's an_pi input as public the proof has length 
# 2144 (proof) + 512 (accumulator) + 64 (an_pi)
# and below we are telling the backend that this proof is recursive (-r)
# so far so good - still, verification fails with exit code 1
# https://discord.com/channels/1113924620781883405/1219724105872576554/1222990099390791870
# https://github.com/AztecProtocol/barretenberg/blob/092944d708687e5834d56efbe0361c8ad20dd1b3/cpp/src/barretenberg/bb/main.cpp#L156
$B verify -r -p $D/target/ag_proof.bin -k $D/target/ag_vk