#!/bin/bash

set -ueExo pipefail

b=~/.bb/bb
d=$(git rev-parse --show-toplevel)
vk_toml=$d/target/vk.toml

nargo compile --workspace

jq -r '.bytecode' $d/target/noir_safe_storage_proof_circuit.json | base64 -d > $d/target/sp_circuit.gz
$b write_vk -b $d/target/sp_circuit.gz -o $d/target/sp_vk
$b vk_as_fields -k $d/target/sp_vk -o $d/target/sp_vk_as_fields
sp_vk_hash=$(jq -r '.[0]' $d/target/sp_vk_as_fields)
sp_vk_as_fields=$(jq -r '.[1:]' $d/target/sp_vk_as_fields)

jq -r '.bytecode' $d/target/noir_safe_account_proof_circuit.json | base64 -d > $d/target/ap_circuit.gz
$b write_vk -b $d/target/ap_circuit.gz -o $d/target/ap_vk
$b vk_as_fields -k $d/target/ap_vk -o $d/target/ap_vk_as_fields
ap_vk_hash=$(jq -r '.[0]' $d/target/ap_vk_as_fields)
ap_vk_as_fields=$(jq -r '.[1:]' $d/target/ap_vk_as_fields)

jq -r '.bytecode' $d/target/noir_safe_anchor_circuit.json | base64 -d > $d/target/an_circuit.gz
$b write_vk -b $d/target/an_circuit.gz -o $d/target/an_vk
$b vk_as_fields -k $d/target/an_vk -o $d/target/an_vk_as_fields
an_vk_hash=$(jq -r '.[0]' $d/target/an_vk_as_fields)
an_vk_as_fields=$(jq -r '.[1:]' $d/target/an_vk_as_fields)

jq -r '.bytecode' $d/target/noir_safe_aggregation_circuit.json | base64 -d > $d/target/ag_circuit.gz
$b write_vk -b $d/target/ag_circuit.gz -o $d/target/ag_vk

$b vk_as_fields -k $d/target/ag_vk -o $d/target/ag_vk_as_fields
ag_vk_hash=$(jq -r '.[0]' $d/target/ag_vk_as_fields)

echo "$ag_vk_hash" > $d/target/vk_hash

cp $d/target/ag_vk $d/target/vk
$b contract -o $d/contract/UltraVerifier.sol

echo "sp_vk_hash = \"$sp_vk_hash\"
sp_vk = $sp_vk_as_fields
ap_vk_hash = \"$ap_vk_hash\"
ap_vk = $ap_vk_as_fields
an_vk_hash = \"$an_vk_hash\"
an_vk = $an_vk_as_fields
" > $vk_toml