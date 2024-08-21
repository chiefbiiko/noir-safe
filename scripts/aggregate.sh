#!/bin/bash

set -ueExo pipefail

B=~/.bb/bb
D=$(git rev-parse --show-toplevel)
VK_TOML=$D/target/vk.toml
AGGREGATION_PROVER_TOML=$D/circuits/aggregation/Prover.toml

sp_shard() {
    nargo execute --package noir_safe_storage_proof_circuit sp_witness
    $B prove -b $D/target/sp_circuit -w $D/target/sp_witness.gz -o $D/target/sp_proof.bin
    SP_FULL_PROOF_AS_FIELDS="$($B proof_as_fields -p $D/target/sp_proof.bin -k $D/target/sp_vk -o -)"
    echo -e "sp_pi = []\nsp_proof = $SP_FULL_PROOF_AS_FIELDS" >> $AGGREGATION_PROVER_TOML
}

ap_shard() {
    nargo execute --package noir_safe_account_proof_circuit ap_witness
    $B prove -b $D/target/ap_circuit -w $D/target/ap_witness.gz -o $D/target/ap_proof.bin
    AP_FULL_PROOF_AS_FIELDS="$($B proof_as_fields -p $D/target/ap_proof.bin -k $D/target/ap_vk -o -)"
    echo -e "ap_pi = []\nap_proof = $AP_FULL_PROOF_AS_FIELDS" >> $AGGREGATION_PROVER_TOML
}

an_shard() {
    nargo execute --package noir_safe_anchor_circuit an_witness
    $B prove -b $D/target/an_circuit -w $D/target/an_witness.gz -o $D/target/an_proof.bin
    AN_FULL_PROOF_AS_FIELDS="$($B proof_as_fields -p $D/target/an_proof.bin -k $D/target/an_vk -o -)"
    AN_PROOF_AS_FIELDS="$(echo $AN_FULL_PROOF_AS_FIELDS | jq -r '.[2:]')"
    blockhash=$(yq -r '.blockhash' $D/circuits/anchor/Prover.toml)
    challenge=$(yq -r '.challenge' $D/circuits/anchor/Prover.toml)
    echo -e "an_pi = [\"$blockhash\", \"$challenge\"]\nan_proof = $AN_PROOF_AS_FIELDS" >> $AGGREGATION_PROVER_TOML
}

ag_circuit() {
    nargo execute --package noir_safe_aggregation_circuit ag_witness
    $B prove -b $D/target/ag_circuit -w $D/target/ag_witness.gz -o $D/target/ag_proof.bin
}

cat $VK_TOML > $AGGREGATION_PROVER_TOML

sp_shard &
ap_shard &
an_shard &

wait

ag_circuit