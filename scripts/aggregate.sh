#!/bin/bash

set -ueExo pipefail

b=~/.bb/bb
d=$(git rev-parse --show-toplevel)
vk_toml=$d/target/vk.toml
ag_prover_toml=$d/circuits/aggregation/Prover.toml

sp_shard() {
    nargo execute --package noir_safe_storage_proof_circuit sp_witness
    $b prove -b $d/target/sp_circuit -w $d/target/sp_witness.gz -o $d/target/sp_proof.bin
    SP_FULL_PROOF_AS_FIELDS="$($b proof_as_fields -p $d/target/sp_proof.bin -k $d/target/sp_vk -o -)"
    echo -e "sp_pi = []\nsp_proof = $SP_FULL_PROOF_AS_FIELDS" >> $ag_prover_toml
}

ap_shard() {
    nargo execute --package noir_safe_account_proof_circuit ap_witness
    $b prove -b $d/target/ap_circuit -w $d/target/ap_witness.gz -o $d/target/ap_proof.bin
    AP_FULL_PROOF_AS_FIELDS="$($b proof_as_fields -p $d/target/ap_proof.bin -k $d/target/ap_vk -o -)"
    echo -e "ap_pi = []\nap_proof = $AP_FULL_PROOF_AS_FIELDS" >> $ag_prover_toml
}

an_shard() {
    nargo execute --package noir_safe_anchor_circuit an_witness
    $b prove -b $d/target/an_circuit -w $d/target/an_witness.gz -o $d/target/an_proof.bin
    AN_FULL_PROOF_AS_FIELDS="$($b proof_as_fields -p $d/target/an_proof.bin -k $d/target/an_vk -o -)"
    AN_PROOF_AS_FIELDS="$(echo $AN_FULL_PROOF_AS_FIELDS | jq -r '.[2:]')"
    blockhash=$(yq -r '.blockhash' $d/circuits/anchor/Prover.toml)
    challenge=$(yq -r '.challenge' $d/circuits/anchor/Prover.toml)
    echo -e "an_pi = [\"$blockhash\", \"$challenge\"]\nan_proof = $AN_PROOF_AS_FIELDS" >> $ag_prover_toml
}

ag_circuit() {
    nargo execute --package noir_safe_aggregation_circuit ag_witness
    $b prove -b $d/target/ag_circuit -w $d/target/ag_witness.gz -o $d/target/ag_proof.bin
}

cat $vk_toml > $ag_prover_toml

sp_shard &
ap_shard &
an_shard &

wait

ag_circuit