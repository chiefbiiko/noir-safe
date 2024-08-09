#!/bin/bash

set -ueExo pipefail

B=~/.nargo/backends/acvm-backend-barretenberg/backend_binary
D=$(git rev-parse --show-toplevel)

# nargo codegen-verifier

$B contract -o $D/contract/UltraVerifier.sol


PROOF_PATH=$D/proofs/noir_safe_aggregation_proof. #./target/proof
# $BACKEND prove -b ./target/hello_world.json -w ./target/witness.gz -o $PROOF_PATH

NUM_PUBLIC_INPUTS=1
PUBLIC_INPUT_BYTES=$((32 * $NUM_PUBLIC_INPUTS))
HEX_PUBLIC_INPUTS=$(head -c $PUBLIC_INPUT_BYTES $PROOF_PATH | od -An -v -t x1 | tr -d $' \n')
HEX_PROOF=$(tail -c +$(($PUBLIC_INPUT_BYTES + 1)) $PROOF_PATH | od -An -v -t x1 | tr -d $' \n')


# Spin up an anvil node to deploy the contract to
anvil &

DEPLOY_INFO=$(forge create --contracts $D/contract UltraVerifier \
    --rpc-url "127.0.0.1:8545" \
    --private-key "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80" \
    --json)
VERIFIER_ADDRESS=$(echo $DEPLOY_INFO | jq -r '.deployedTo')

# Call the verifier contract with our proof.
# Note that we haven't needed to split up `HEX_PUBLIC_INPUTS` as there's only a single public input
cast call $VERIFIER_ADDRESS "verify(bytes, bytes32[])(bool)" "0x$HEX_PROOF" "[0x$HEX_PUBLIC_INPUTS]"

# Stop anvil node again
kill %-