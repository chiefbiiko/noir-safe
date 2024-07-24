#!/bin/bash

set -ueExo pipefail

b=~/.nargo/backends/acvm-backend-barretenberg/backend_binary
d=$(git rev-parse --show-toplevel)

nargo compile --workspace

jq -r '.bytecode' $d/target/noir_safe_storage_proof_circuit.json | base64 -d > $d/target/noir_safe_storage_proof_circuit.gz
$b write_vk -b $d/target/noir_safe_storage_proof_circuit.gz -o $d/target/sp_vk
# $b write_vk -b $d/target/noir_safe_storage_proof_circuit.json -o $d/target/sp_vk
$b vk_as_fields -k $d/target/sp_vk -o $d/target/sp_vk_as_fields
SP_VK_HASH=$(jq -r '.[0]' $d/target/sp_vk_as_fields)
SP_VK_AS_FIELDS=$(jq -r '.[1:]' $d/target/sp_vk_as_fields)

jq -r '.bytecode' $d/target/noir_safe_account_proof_circuit.json | base64 -d > $d/target/noir_safe_account_proof_circuit.gz
$b write_vk -b $d/target/noir_safe_account_proof_circuit.gz -o $d/target/ap_vk
$b vk_as_fields -k $d/target/ap_vk -o $d/target/ap_vk_as_fields
AP_VK_HASH=$(jq -r '.[0]' $d/target/ap_vk_as_fields)
AP_VK_AS_FIELDS=$(jq -r '.[1:]' $d/target/ap_vk_as_fields)

VK_TOML=$d/target/vk.toml
echo "sp_vk_hash = \"$SP_VK_HASH\"" > $VK_TOML
echo "sp_vk = $SP_VK_AS_FIELDS"  >> $VK_TOML
echo "ap_vk_hash = \"$AP_VK_HASH\"" >> $VK_TOML
echo "ap_vk = $AP_VK_AS_FIELDS"  >> $VK_TOML