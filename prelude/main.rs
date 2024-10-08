use const_hex;
use noir_safe_prelude::{fetch_inputs, InputsFe};
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
    let inputs_fe = InputsFe::from(inputs);
    let prover_toml = toml::to_string(&inputs_fe).expect("prover toml");
    let an_prover_payload = format!("{}\nblocknumber = {}", prover_toml, anchor);
    let req_id = std::env::var("REQ_ID").expect("must set env var REQ_ID=1734..");

    let mut sp_prover_file = std::fs::File::create(format!(
        "{}/../circuits/storage_proof/sp_prover_{}.toml",
        cargo_manifest_dir, &req_id
    ))
    .expect("sp_prover_file");
    let mut ap_prover_file = std::fs::File::create(format!(
        "{}/../circuits/account_proof/ap_prover_{}.toml",
        cargo_manifest_dir, &req_id
    ))
    .expect("ap_prover_file");
    let mut an_prover_file = std::fs::File::create(format!(
        "{}/../circuits/anchor/an_prover_{}.toml",
        cargo_manifest_dir, &req_id
    ))
    .expect("an_prover_file");
    let mut anchor_file = std::fs::File::create(format!(
        "{}/../target/anchor_{}.txt",
        cargo_manifest_dir, req_id
    ))
    .expect("anchor_file");

    sp_prover_file
        .write_all(prover_toml.as_bytes())
        .expect("sp_prover_file write");

    ap_prover_file
        .write_all(prover_toml.as_bytes())
        .expect("ap_prover_file write");

    an_prover_file
        .write_all(an_prover_payload.as_bytes())
        .expect("an_prover_file write");

    anchor_file
        .write_all(&anchor.to_string().into_bytes())
        .expect("anchor_file write");
}
