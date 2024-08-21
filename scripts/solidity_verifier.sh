#!/bin/bash

set -ueExo pipefail

B=~/.bb/bb
D=$(git rev-parse --show-toplevel)

cp $D/target/ag_vk $D/target/vk
$B contract -o $D/contract/UltraVerifier.sol

# PROOF_PATH=$D/target/ag_proof.bin

NUM_PUBLIC_INPUTS=2
PUBLIC_INPUT_BYTES=$((32 * $NUM_PUBLIC_INPUTS))
# HEX_PUBLIC_INPUTS=$(head -c $PUBLIC_INPUT_BYTES $PROOF_PATH | od -An -v -t x1 | tr -d $' \n')
blockhash=$(yq -r '.blockhash' $D/circuits/anchor/Prover.toml)
challenge=$(yq -r '.challenge' $D/circuits/anchor/Prover.toml)
HEX_PROOF=$(tail -c +$(($PUBLIC_INPUT_BYTES + 1)) $D/target/ag_proof.bin | od -An -v -t x1 | tr -d $' \n')
echo "HEX_PROOF len ${#HEX_PROOF}"
anvil --disable-block-gas-limit --code-size-limit 144444 & #140131
anvil_pid=$!

DEPLOY_INFO=$(forge create --contracts $D/contract UltraVerifier \
    --rpc-url "127.0.0.1:8545" \
    --private-key "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80" \
    --json)
VERIFIER_ADDRESS=$(echo $DEPLOY_INFO | jq -r '.deployedTo')

# cast call $VERIFIER_ADDRESS "verify(bytes, bytes32[])(bool)" "0x$HEX_PROOF" "[${blockhash#0x}, ${challenge#0x}]"
cast call $VERIFIER_ADDRESS "verify(bytes, bytes32[])(bool)" "0x$HEX_PROOF" "[${blockhash}, ${challenge}]"

kill $anvil_pid