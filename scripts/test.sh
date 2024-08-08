#!/bin/bash

set -ueExo pipefail

D=$(git rev-parse --show-toplevel)

cargo run --manifest-path $D/prelude/Cargo.toml

$D/scripts/compile.sh

$D/scripts/aggregate.sh

$D/scripts/verify.sh