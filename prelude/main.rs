use const_hex;
use noir_safe_prelude::fetch_inputs;
use std::io::Write;

#[tokio::main]
async fn main() {
    let rpc = std::env::var("RPC").unwrap_or("https://rpc.gnosis.gateway.fm".to_string());
    let safe = const_hex::decode_to_array::<&str, 20>(
        &std::env::var("SAFE").expect("must set env var SAFE=0x..."),
    )
    .expect("env var SAFE");
    let msg_hash = const_hex::decode_to_array::<&str, 32>(
        &std::env::var("MSG_HASH").expect("must set env var MSG_HASH=0x..."),
    )
    .expect("env var MSG_HASH");

    let (anchor, inputs) = fetch_inputs(&rpc, safe.into(), msg_hash.into())
        .await
        .expect("fetch_inputs failed");

    let cargo_manifest_dir = env!("CARGO_MANIFEST_DIR");
    let prover_toml = toml::to_string(&inputs).expect("prover toml pt1");
    let mut ap_prover_file = std::fs::File::create(format!("{}/../circuits/account-proof/Prover.toml", cargo_manifest_dir))
        .expect("ap_prover_file");
    ap_prover_file.write_all(prover_toml.as_bytes())
        .expect("ap_prover_file write");
    let mut sp_prover_file = std::fs::File::create(format!("{}/../circuits/storage-proof/Prover.toml", cargo_manifest_dir))
        .expect("sp_prover_file");
    sp_prover_file.write_all(prover_toml.as_bytes())
        .expect("sp_prover_file write");
    let mut an_prover_file = std::fs::File::create(format!("{}/../circuits/anchor/Prover.toml", cargo_manifest_dir))
        .expect("an_prover_file");
    an_prover_file.write_all(prover_toml.as_bytes())
        .expect("an_prover_file write");

    println!("anchor block number {} - Prover.toml files refreshed", anchor);
}
