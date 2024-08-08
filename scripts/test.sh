#!/bin/bash

set -ueExo pipefail

D=$(git rev-parse --show-toplevel)

# env var SAFE should be set from exterior
MSG_HASH=0xa225aed0c0283cef82b24485b8b28fb756fc9ce83d25e5cf799d0c8aa20ce6b7 \
  cargo run --manifest-path $D/prelude/Cargo.toml

$D/scripts/compile.sh

$D/scripts/aggregate.sh

$D/scripts/verify.sh