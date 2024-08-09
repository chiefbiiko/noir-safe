#!/bin/bash

set -ueExo pipefail

D=$(git rev-parse --show-toplevel)

$D/scripts/compile.sh

cargo run --manifest-path $D/prelude/Cargo.toml

$D/scripts/aggregate.sh

$D/scripts/verify.sh