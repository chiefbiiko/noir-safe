#!/bin/bash

set -ueExo pipefail

B=~/.nargo/backends/acvm-backend-barretenberg/backend_binary
D=$(git rev-parse --show-toplevel)
VK_TOML=$D/target/vk.toml

#TODO gen sol verifier
echo TODO