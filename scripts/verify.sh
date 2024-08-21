#!/bin/bash

set -ueExo pipefail

b=~/.bb/bb
d=$(git rev-parse --show-toplevel)

# verify in solidity
pub_bytes=$((32 * $((2+16)))) # 2 actual public inputs; 16 from accumulator
hex_pubs=$(head -c $pub_bytes $d/target/ag_proof.bin | od -An -v -t x1 | tr -d $' \n')
hex_proof=$(tail -c +$(($pub_bytes + 1)) $d/target/ag_proof.bin | od -An -v -t x1 | tr -d $' \n')
anvil &
anvil_pid=$!
deploy_info=$( \
    forge create --no-cache --force --contracts $d/contract UltraVerifier \
        --rpc-url "127.0.0.1:8545" \
        --private-key "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80" \
        --json \
)
verifier_adrs=$(echo $deploy_info | jq -r '.deployedTo')
cast call $verifier_adrs "verify(bytes, bytes32[])(bool)" "0x$hex_proof" "[ \
    ${hex_pubs:0:64}, \
    ${hex_pubs:64:64}, \
    ${hex_pubs:128:64}, \
    ${hex_pubs:192:64}, \
    ${hex_pubs:256:64}, \
    ${hex_pubs:320:64}, \
    ${hex_pubs:384:64}, \
    ${hex_pubs:448:64}, \
    ${hex_pubs:512:64}, \
    ${hex_pubs:576:64}, \
    ${hex_pubs:640:64}, \
    ${hex_pubs:704:64}, \
    ${hex_pubs:768:64}, \
    ${hex_pubs:832:64}, \
    ${hex_pubs:896:64}, \
    ${hex_pubs:960:64}, \
    ${hex_pubs:1024:64}, \
    ${hex_pubs:1088:64} \
]"
kill $anvil_pid

# verify with binary
$b verify -p $d/target/ag_proof.bin -k $d/target/ag_vk