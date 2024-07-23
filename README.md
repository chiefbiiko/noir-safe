# noir-safe

[![ci](https://github.com/chiefbiiko/noir-safe/workflows/ci/badge.svg)](https://github.com/chiefbiiko/noir-safe/actions/workflows/ci.yml) [![release](https://img.shields.io/github/v/release/chiefbiiko/noir-safe?include_prereleases)](https://github.com/chiefbiiko/noir-safe/releases/latest)

Safe zk multisig

**WIP**

Compile all circuits

```sh
nargo compile --workspace
```

Fetch and preprocess inputs

```sh
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


<!-- 
- FIXME sometimes header_rlp byte_len != 590 -->

<!-- ## Commands

Fetches circuit inputs and updates `circuits/Prover.toml`:

```sh
SAFE=0x38Ba7f4....A673336EDDc \
MSG_HASH=0xa225aed0c0283cef82b24485b8b28fb756fc9ce83d25e5cf799d0c8aa20ce6b7 \
RUST_LOG=info \
RUST_BACKTRACE=full \
  cargo run --manifest-path prelude/Cargo.toml
``` 

Nargo:

 -->