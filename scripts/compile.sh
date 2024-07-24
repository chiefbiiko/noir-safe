#!/bin/bash

set -ueExo pipefail

B=~/.nargo/backends/acvm-backend-barretenberg/backend_binary
D=$(git rev-parse --show-toplevel)
VK_TOML=$D/target/vk.toml

nargo compile --workspace

jq -r '.bytecode' $D/target/noir_safe_storage_proof_circuit.json | base64 -d > $D/target/noir_safe_storage_proof_circuit.gz
$B write_vk -b $D/target/noir_safe_storage_proof_circuit.gz -o $D/target/sp_vk
$B vk_as_fields -k $D/target/sp_vk -o $D/target/sp_vk_as_fields
SP_VK_HASH=$(jq -r '.[0]' $D/target/sp_vk_as_fields)
SP_VK_AS_FIELDS=$(jq -r '.[1:]' $D/target/sp_vk_as_fields)

jq -r '.bytecode' $D/target/noir_safe_account_proof_circuit.json | base64 -d > $D/target/noir_safe_account_proof_circuit.gz
$B write_vk -b $D/target/noir_safe_account_proof_circuit.gz -o $D/target/ap_vk
$B vk_as_fields -k $D/target/ap_vk -o $D/target/ap_vk_as_fields
AP_VK_HASH=$(jq -r '.[0]' $D/target/ap_vk_as_fields)
AP_VK_AS_FIELDS=$(jq -r '.[1:]' $D/target/ap_vk_as_fields)

echo "sp_vk_hash = \"$SP_VK_HASH\"
sp_vk = $SP_VK_AS_FIELDS
ap_vk_hash = \"$AP_VK_HASH\"
ap_vk = $AP_VK_AS_FIELDS
" > $VK_TOML