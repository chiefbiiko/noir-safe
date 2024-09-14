#!/bin/bash

set -ueExo pipefail

d=$(git rev-parse --show-toplevel)

$d/scripts/compile.sh

REQ_ID=123 cargo run --manifest-path $d/prelude/Cargo.toml

REQ_ID=123 $d/scripts/aggregate.sh

$d/scripts/verify.sh