// #![feature(lazy_cell)]

#[macro_use]
extern crate rocket;

use anyhow::{bail, Context, Result};
use rocket::{
    data::{Limits, ToByteUnit},
    fairing::{Fairing, Info, Kind},
    http::{Header, Method, Status},
    request::Request,
    serde::json::{json, Json, Value},
    Config, Response,
};
// use sp1_safe_basics::{Inputs, NoirSafeParams, NoirSafeParams};
// use sp1_safe_fetch::fetch_inputs;
// use sp1_sdk::{HashableKey, ProverClient, SP1ProvingKey, SP1Stdin, SP1VerifyingKey};
use std::env;
use std::net::Ipv4Addr;
// use std::sync::LazyLock;
use std::process::Command;
use std::fs::read;
use serde::{Deserialize, Serialize};

// const ELF: &[u8] = include_bytes!("../../program/elf/riscv32im-succinct-zkvm-elf");

// struct Prover {
//     client: ProverClient,
//     pk: SP1ProvingKey,
//     vk: SP1VerifyingKey,
// }

// static PROVER: LazyLock<Prover> = LazyLock::new(|| {
//     let client = ProverClient::new();
//     let (pk, vk) = client.setup(ELF);
//     Prover { client, pk, vk }
// });

const PUBLIC_INPUTS_BYTES: usize = 512 + 64;

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct NoirSafeParams {
    pub chain_id: u64,
    pub safe_address: String,
    pub message_hash: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct NoirSafeResult {
    pub chain_id: u64,
    pub safe_address: String,
    pub message_hash: String,
    pub block_number: u64,
    pub block_hash: String,
    pub challenge: String,
    pub proof: String,
    pub public_inputs: Vec<String>
}

fn is_0x_hex(len: usize, s: &str) -> bool {
    if &s[0..2] != "0x" || (s.len() - 2) != len {
        return false;
    }
    true
}

async fn _proof(params: Json<NoirSafeParams>) -> Result<Value> {
    log::info!("🏈 incoming request");
    let cargo_manifest_dir = env!("CARGO_MANIFEST_DIR");
    let rpc = match params.chain_id {
        100 => env::var("GNOSIS_RPC").unwrap_or("https://rpc.gnosis.gateway.fm".to_string()),
        11155111 => env::var("SEPOLIA_RPC").unwrap_or("https://1rpc.io/sepolia".to_string()),
        _ => bail!("invalid chain_id {}", params.chain_id),
    };

    // let safe: [u8; 20] = const_hex::decode_to_array::<&str, 20>(&params.safe_address)?;
    // let msg_hash: [u8; 32] = const_hex::decode_to_array::<&str, 32>(&params.message_hash)?;

    

    //TODO
    // run these two
    //              cargo run --manifest-path $d/prelude/Cargo.toml
    //                  while parse decimal number from last line of stdout as block anchor
    //              $d/scripts/aggregate.sh
    // then serve 
    //              hex_pubs=$(head -c $pub_bytes $d/target/ag_proof.bin | od -An -v -t x1 | tr -d $' \n')
    //              hex_proof=$(tail -c +$(($pub_bytes + 1)) $d/target/ag_proof.bin | od -An -v -t x1 | tr -d $' \n')


//TODO validate params safe_address and message_hash with is_0x_hex(l,s)
let prelude = Command::new("cargo run")
                        .env("RPC", rpc)
                        .env("SAFE", &params.safe_address)
                        .env("MSG_HASH", &params.message_hash)
                     .arg(format!("--manifest-path {}/../prelude/Cargo.toml", cargo_manifest_dir))
                     .output()?;
if !prelude.status.success() {
    bail!("prelude failed");
}
let anchor = {
    let digits = String::from_utf8_lossy(&prelude.stdout).split('\n').last().context("")?
   .chars().filter(|char| char.is_digit(10)).collect::<String>();
    u64::from_str_radix(&digits, 10)?
};
let aggregation = Command::new(format!("{}/../scripts/aggregate.sh", cargo_manifest_dir))
                     .output()?;
if !aggregation.status.success() {
    bail!("aggregation failed");
}
let mut ag_proof = read(format!("{}/../target/ag_proof.bin", cargo_manifest_dir))?;
let proofbin = ag_proof.split_off(PUBLIC_INPUTS_BYTES);
let _public_inputs = ag_proof;
let blockhash = &_public_inputs[0..32];
let challenge = &_public_inputs[32..64];
let public_inputs = _public_inputs[64..PUBLIC_INPUTS_BYTES].chunks(32)
.map(|pi| format!("0x{}", const_hex::encode(pi)))
.collect::<Vec<String>>();





    // log::info!("🕳️ fetching inputs");
    // let (anchor, inputs) = fetch_inputs(&rpc, safe.into(), msg_hash.into()).await?;
    // let mut stdin = SP1Stdin::new();
    // stdin.write::<Inputs>(&inputs);

    // log::info!("🎰 zk proving");
    // let mut proofwpv = PROVER
    //     .client
    //     .prove_plonk(&PROVER.pk, stdin)
    //     .expect("proving failed");

    // let blockhash = proofwpv.public_values.read::<[u8; 32]>();
    // let challenge = proofwpv.public_values.read::<[u8; 32]>();
    // let proofbin = bincode::serialize(&proofwpv.proof)?;

    Ok(json!(NoirSafeResult {
        chain_id: params.chain_id,
        safe_address: params.safe_address.to_owned(),
        message_hash: params.message_hash.to_owned(),
        block_number: anchor,
        block_hash: format!("0x{}", const_hex::encode(blockhash)),
        challenge: format!("0x{}", const_hex::encode(challenge)),
        proof: format!("0x{}", const_hex::encode(proofbin)),
        public_inputs,
    }))
}

#[post("/proof", data = "<params>")]
async fn proof(params: Json<NoirSafeParams>) -> (Status, Value) {
    match _proof(params).await {
        Ok(res) => (Status::Ok, res),
        Err(err) => {
            log::error!("{}", err);
            (
                Status::BadRequest,
                json!({
                    "error": "t(ツ)_/¯ invalid chain id"
                }),
            )
        }
    }
}

#[get("/status")]
async fn status() -> (Status, Value) {
    (Status::Ok, json!({ "status": "ok" }))
}

#[catch(400)]
fn not_found(_: &Request) -> Value {
    json!({
        "error": "t(ツ)_/¯ invalid request params"
    })
}

#[catch(500)]
fn internal_server_error(_: &Request) -> Value {
    json!({
        "error": "t(ツ)_/¯ invalid storage proof"
    })
}

pub struct CORS;

#[rocket::async_trait]
impl Fairing for CORS {
    fn info(&self) -> Info {
        Info {
            name: "Add CORS headers to responses",
            kind: Kind::Response,
        }
    }

    async fn on_response<'r>(&self, request: &'r Request<'_>, response: &mut Response<'r>) {
        response.set_header(Header::new("access-control-allow-origin", "*"));
        response.set_header(Header::new(
            "access-control-allow-methods",
            "POST, GET, OPTIONS",
        ));
        response.set_header(Header::new("access-control-allow-headers", "*"));
        response.set_status(Status {
            code: if request.method() == Method::Options {
                200
            } else {
                response.status().code
            },
        });
    }
}

#[launch]
fn rocket() -> _ {
    std::env::set_var("RUST_LOG", "info");
    sp1_sdk::utils::setup_logger();
    let config = Config {
        port: std::env::var("PORT")
            .map(|p| p.parse::<u16>().expect("invalid port"))
            .unwrap_or(4190),
        address: Ipv4Addr::new(0, 0, 0, 0).into(),
        ip_header: None,
        limits: Limits::default().limit("json", 256.bytes()),
        ..Config::release_default()
    };

    log::info!("vkey hash 0x{}", const_hex::encode(&PROVER.vk.hash_bytes()));

    rocket::custom(&config)
        .attach(CORS)
        .register("/", catchers![internal_server_error, not_found])
        .mount("/", routes![proof, status])
}