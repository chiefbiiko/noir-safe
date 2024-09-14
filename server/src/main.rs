#[macro_use]
extern crate rocket;

use anyhow::{bail, Result};
use rocket::{
    data::{Limits, ToByteUnit},
    fairing::{Fairing, Info, Kind},
    http::{Header, Method, Status},
    request::Request,
    serde::json::{json, Json, Value},
    Config, Response,
};
use serde::{Deserialize, Serialize};
use std::{
    env,
    fs::{read, read_to_string},
    net::Ipv4Addr,
    process::Command,
    time::{SystemTime, UNIX_EPOCH},
};

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
    pub public_inputs: Vec<String>,
}

fn is_0x_hex(len: usize, s: &str) -> bool {
    if &s[0..2] != "0x" || (s.len() - 2) / 2 != len {
        return false;
    }
    true
}

pub fn get_epoch_millis() -> u128 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_millis()
}

async fn _proof(params: Json<NoirSafeParams>) -> Result<Value> {
    log::info!("🏈 incoming request");
    let dir = env::var("CARGO_MANIFEST_DIR").expect("cargo manifest dir");
    let rpc = match params.chain_id {
        100 => env::var("GNOSIS_RPC").unwrap_or("https://rpc.gnosis.gateway.fm".to_string()),
        11155111 => env::var("SEPOLIA_RPC")
            .unwrap_or("https://ethereum-sepolia-rpc.publicnode.com".to_string()),
        _ => bail!("invalid chain_id {}", params.chain_id),
    };

    if !is_0x_hex(20, &params.safe_address) {
        bail!("invalid safe address {}", &params.safe_address);
    }
    if !is_0x_hex(32, &params.message_hash) {
        bail!("invalid msg hash {}", &params.message_hash);
    }
    let cargo = format!(
        "{}/bin/cargo",
        home::cargo_home().expect("cargo home").to_string_lossy()
    );
    let req_id = get_epoch_millis().to_string();
    let prelude = Command::new(cargo)
        .arg("run")
        .env("RPC", rpc)
        .env("SAFE", &params.safe_address)
        .env("MSG_HASH", &params.message_hash)
        .env("REQ_ID", &req_id)
        .arg("--manifest-path")
        .arg(format!("{}/../prelude/Cargo.toml", dir))
        .output()?;
    if !prelude.status.success() {
        log::error!("{}", String::from_utf8_lossy(&prelude.stderr));
        bail!("prelude failed");
    }
    let anchor = {
        let digits = read_to_string(format!("{}/../target/anchor_{}.txt", dir, req_id))?;
        u64::from_str_radix(&digits, 10)?
    };
    let aggregation = Command::new(format!("{}/../scripts/aggregate.sh", dir))
        .env("REQ_ID", &req_id)
        .output()?;
    if !aggregation.status.success() {
        log::error!("{}", String::from_utf8_lossy(&aggregation.stderr));
        bail!("aggregation failed");
    }
    let mut ag_proof = read(format!("{}/../target/ag_proof_{}.bin", dir, req_id))?;
    let proofbin = ag_proof.split_off(PUBLIC_INPUTS_BYTES);
    let _public_inputs = ag_proof;
    let blockhash = &_public_inputs[0..32];
    let challenge = &_public_inputs[32..64];
    let public_inputs = _public_inputs[0..PUBLIC_INPUTS_BYTES]
        .chunks(32)
        .map(|pi| format!("0x{}", const_hex::encode(pi)))
        .collect::<Vec<String>>();

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
    env_logger::init();
    let dir = env::var("CARGO_MANIFEST_DIR").expect("cargo manifest dir");
    let vk_hash: String = read_to_string(format!("{}/../target/vk_hash", dir)).expect("vk hash");
    log::info!("vkey hash {}", vk_hash);

    let config = Config {
        port: std::env::var("PORT")
            .map(|p| p.parse::<u16>().expect("invalid port"))
            .unwrap_or(4190),
        address: Ipv4Addr::new(0, 0, 0, 0).into(),
        ip_header: None,
        limits: Limits::default().limit("json", 256.bytes()),
        ..Config::release_default()
    };

    rocket::custom(&config)
        .attach(CORS)
        .register("/", catchers![internal_server_error, not_found])
        .mount("/", routes![proof, status])
}
