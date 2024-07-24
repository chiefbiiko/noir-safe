#!/bin/bash

set -ueExo pipefail

B=~/.nargo/backends/acvm-backend-barretenberg/backend_binary
D=$(git rev-parse --show-toplevel)

# verify that the generated recursive proof is valid
xxd -r -p $D/proofs/noir_safe_aggregation_circuit.proof $D/proofs/noir_safe_aggregation_circuit.proof.bin
$B verify -p $D/proofs/noir_safe_aggregation_circuit.proof.bin -k $D/target/ag_vk
