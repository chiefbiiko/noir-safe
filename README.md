# noir-safe

[![ci](https://github.com/chiefbiiko/noir-safe/workflows/ci/badge.svg)](https://github.com/chiefbiiko/noir-safe/actions/workflows/ci.yml) [![release](https://img.shields.io/github/v/release/chiefbiiko/noir-safe?include_prereleases)](https://github.com/chiefbiiko/noir-safe/releases/latest)

Safe zk multisig

**WIP**

Install tooling

```sh
# install noirup
curl -L https://raw.githubusercontent.com/noir-lang/noirup/main/install | bash
# install nargo and the acvm-backend-barretenberg
noirup -v v0.29.0
# install json and toml parsers
brew install jq yq
```

Compile all circuits

```sh
./scripts/compile.sh
```

Fetch and preprocess inputs

> To sign a msg via a Safe and obtain the msg hash use the scripts within `scripts/safe`

```sh
RPC=https://rpc.gnosis.gateway.fm \
SAFE=0x38Ba7f...673336EDDc \
MSG_HASH=0xa225aed0c0283cef82b24485b8b28fb756fc9ce83d25e5cf799d0c8aa20ce6b7 \
  cargo run --manifest-path prelude/Cargo.toml
```

Generate the aggregated proof

```sh
./scripts/aggregate.sh
```

Verify locally

```sh
./scripts/verify.sh
```

Generate the Solidity verifier

```sh
./scripts/solidity_verifier.sh
```

Test everything e2e

```sh
SAFE=0x38Ba7f...673336EDDc \
MSG_HASH=0xa225aed0c0283cef82b24485b8b28fb756fc9ce83d25e5cf799d0c8aa20ce6b7 \
  ./scripts/test.sh
```
