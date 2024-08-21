#!/bin/bash

set -ueExo pipefail

d=$(git rev-parse --show-toplevel)

$d/scripts/compile.sh

cargo run --manifest-path $d/prelude/Cargo.toml

$d/scripts/aggregate.sh

$d/scripts/verify.sh