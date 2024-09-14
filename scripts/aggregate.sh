#!/bin/bash

set -ueExo pipefail

n=~/.nargo/bin/nargo
b=~/.bb/bb
d=$(git rev-parse --show-toplevel)
vk_toml=$d/target/vk.toml
req_id=$REQ_ID
ag_prover_toml=$d/circuits/aggregation/ag_prover_$req_id.toml

sp_shard() {
    $n execute --package noir_safe_storage_proof_circuit --prover-name sp_prover_$req_id sp_witness_$req_id
    $b prove -b $d/target/sp_circuit -w $d/target/sp_witness_$req_id.gz -o $d/target/sp_proof_$req_id.bin
    sp_full_proof_as_fields="$($b proof_as_fields -p $d/target/sp_proof_$req_id.bin -k $d/target/sp_vk -o -)"
    echo -e "sp_pi = []\nsp_proof = $sp_full_proof_as_fields" >> $ag_prover_toml
}

ap_shard() {
    $n execute --package noir_safe_account_proof_circuit --prover-name ap_prover_$req_id ap_witness_$req_id
    $b prove -b $d/target/ap_circuit -w $d/target/ap_witness_$req_id.gz -o $d/target/ap_proof_$req_id.bin
    ap_full_proof_as_fields="$($b proof_as_fields -p $d/target/ap_proof_$req_id.bin -k $d/target/ap_vk -o -)"
    echo -e "ap_pi = []\nap_proof = $ap_full_proof_as_fields" >> $ag_prover_toml
}

an_shard() {
    $n execute --package noir_safe_anchor_circuit --prover-name an_prover_$req_id an_witness_$req_id
    $b prove -b $d/target/an_circuit -w $d/target/an_witness_$req_id.gz -o $d/target/an_proof_$req_id.bin
    an_full_proof_as_fields="$($b proof_as_fields -p $d/target/an_proof_$req_id.bin -k $d/target/an_vk -o -)"
    an_proof_as_fields="$(echo $an_full_proof_as_fields | jq -r '.[2:]')"
    blockhash=$(yq -r '.blockhash' $d/circuits/anchor/an_prover_$req_id.toml)
    challenge=$(yq -r '.challenge' $d/circuits/anchor/an_prover_$req_id.toml)
    echo -e "an_pi = [\"$blockhash\", \"$challenge\"]\nan_proof = $an_proof_as_fields" >> $ag_prover_toml
}

ag_circuit() {
    $n execute --package noir_safe_aggregation_circuit --prover-name ag_prover_$req_id ag_witness_$req_id
    $b prove -b $d/target/ag_circuit -w $d/target/ag_witness_$req_id.gz -o $d/target/ag_proof_$req_id.bin
}

cleanup() {
    rm $d/circuits/storage_proof/sp-prover-$req_id.toml \
        $d/circuits/account_proof/ap-prover-$req_id.toml \
        $d/circuits/anchor/an-prover-$req_id.toml \
        $d/circuits/aggregation/ag-prover-$req_id.toml \
        $d/target/sp_witness_$req_id.gz \
        $d/target/ap_witness_$req_id.gz \
        $d/target/an_witness_$req_id.gz \
        $d/target/ag_witness_$req_id.gz \
        $d/target/sp_proof_$req_id.bin \
        $d/target/ap_proof_$req_id.bin \
        $d/target/an_proof_$req_id.bin
}

cat $vk_toml > $ag_prover_toml

sp_shard &
ap_shard &
an_shard &

wait

ag_circuit

cleanup