use anyhow::{anyhow, Context, Result};
use ark_bn254::Fr;
use ark_ff::{BigInteger, PrimeField};
use const_hex::encode as hex;
use ethers::{
    providers::{Middleware, Provider},
    types::{Address, Block, Bytes, H256},
};
use light_poseidon::{Poseidon, PoseidonHasher};
use rlp::RlpStream;
use serde::{Deserialize, Serialize};
use tiny_keccak::{Hasher, Keccak};
use zerocopy::AsBytes;

/// NOTE Since Safes have proxies the actual storage slot of the signed_messages mapping is 5+2
pub const SAFE_SIGNED_MESSAGES_SLOT: [u8; 32] = [
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7,
];
/// SEE https://github.com/safe-global/safe-smart-account/blob/bf943f80fec5ac647159d26161446ac5d716a294/contracts/libraries/SignMessageLib.sol#L24
pub const SAFE_SIGNED_MSG_VALUE: [u8; 32] = [
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
];

/// See https://hackmd.io/@axiom/BJBledudT
const ACCOUNT_PROOF_MAX_DEPTH: usize = 13;
/// See https://hackmd.io/@axiom/BJBledudT
const STORAGE_PROOF_MAX_DEPTH: usize = 12;
/// Maximum length of a state or storage trie node in bytes
const MAX_TRIE_NODE_LENGTH: usize = 532;
/// Maximum size of the value in a storage slot
const MAX_STORAGE_VALUE_LENGTH: usize = 32;
/// Maximum size of the RLP-encoded list representing an account state
const MAX_ACCOUNT_STATE_LENGTH: usize = 134;
/// Minimum number of bytes of a RLP encoded header
const HEADER_RLP_MIN_BYTES: usize = 577;
/// Maximum number of bytes of a RLP encoded header
const HEADER_RLP_MAX_BYTES: usize = 636;

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Inputs {
    pub safe_address: [u8; 20],     // Safe address
    pub msg_hash: [u8; 32],         // Custom msg hash
    pub state_root: [u8; 32],       // eth_getBlockBy*::stateRoot
    pub storage_root: [u8; 32],     // eth_getProof::storageHash
    pub storage_key: [u8; 32],      // keccak256(msg_hash + uint256(7))
    pub account_proof_depth: usize, // eth_getProof::accountProof.len()
    pub storage_proof_depth: usize, // eth_getProof::storageProof.proof.len()
    #[serde(with = "serde_arrays")]
    pub padded_account_value: [u8; MAX_ACCOUNT_STATE_LENGTH], // preprocess_proof()::value
    #[serde(with = "serde_arrays")]
    pub account_proof: [u8; MAX_TRIE_NODE_LENGTH * ACCOUNT_PROOF_MAX_DEPTH], // eth_getProof::accountProof
    #[serde(with = "serde_arrays")]
    pub storage_proof: [u8; MAX_TRIE_NODE_LENGTH * STORAGE_PROOF_MAX_DEPTH], // eth_getProof::storageProof.proof
    #[serde(with = "serde_arrays")]
    pub header_rlp: [u8; HEADER_RLP_MAX_BYTES], // RLP-encoded header
    pub header_rlp_len: usize, // Length of the unpadded header
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct InputsFe {
    // These are all 0xhex strings of bn254 field elements
    pub input_hash: String, // poseidon(state_root, safe_address, storage_root, storage_key)
    pub safe_address_fe: String, // Safe address
    pub msg_hash_fe: String, // Custom msg hash
    pub state_root_fe: String, // eth_getBlockBy*::stateRoot
    pub storage_root_fe: String, // eth_getProof::storageHash
    pub storage_key_fe: String, // keccak256(msg_hash + uint256(7))
    // precalculated outputs
    pub blockhash: String,          // keccak256(header_rlp)
    pub challenge: String,          // poseidon(safe_address, msg_hash)
    pub safe_address: [u8; 20],     // Safe address
    pub msg_hash: [u8; 32],         // Custom msg hash
    pub state_root: [u8; 32],       // eth_getBlockBy*::stateRoot
    pub storage_root: [u8; 32],     // eth_getProof::storageHash
    pub storage_key: [u8; 32],      // keccak256(msg_hash + uint256(7))
    pub account_proof_depth: usize, // eth_getProof::accountProof.len()
    pub storage_proof_depth: usize, // eth_getProof::storageProof.proof.len()
    #[serde(with = "serde_arrays")]
    pub padded_account_value: [u8; MAX_ACCOUNT_STATE_LENGTH], // preprocess_proof()::value
    #[serde(with = "serde_arrays")]
    pub account_proof: [u8; MAX_TRIE_NODE_LENGTH * ACCOUNT_PROOF_MAX_DEPTH], // eth_getProof::accountProof
    #[serde(with = "serde_arrays")]
    pub storage_proof: [u8; MAX_TRIE_NODE_LENGTH * STORAGE_PROOF_MAX_DEPTH], // eth_getProof::storageProof.proof
    #[serde(with = "serde_arrays")]
    pub header_rlp: [u8; HEADER_RLP_MAX_BYTES], // RLP-encoded header
    pub header_rlp_len: usize, // Length of the unpadded header
}

impl From<Inputs> for InputsFe {
    fn from(inputs: Inputs) -> Self {
        let trimmed_header = trim_header(inputs.header_rlp);
        let blockhash = Fr::from_be_bytes_mod_order(&keccak256(trimmed_header));

        let mut poseidon_h2 = Poseidon::<Fr>::new_circom(2).expect("poseidon hash2 init failed");
        // _mod_order might reduce msg_hash_fe i.e. it has 2 preimages aka collision;
        // since the 20-byte Safe address cannot exceed bn254's scalar field _mod_order
        // is always a noop for safe_address_fe, i.e. it has strictly 1 address preimage:
        // no collisions; consequently "cross-account" collisions can never occur
        let safe_address_fe = Fr::from_be_bytes_mod_order(&lpad_bytes32(&inputs.safe_address));
        let msg_hash_fe = Fr::from_be_bytes_mod_order(&inputs.msg_hash);
        let challenge = poseidon_h2
            .hash(&[safe_address_fe, msg_hash_fe])
            .expect("poseidon hash failed");

        let state_root_fe = Fr::from_be_bytes_mod_order(&inputs.state_root);
        let storage_root_fe = Fr::from_be_bytes_mod_order(&inputs.storage_root);
        let storage_key_fe = Fr::from_be_bytes_mod_order(&inputs.storage_key);

        let mut poseidon_h4 = Poseidon::<Fr>::new_circom(4).expect("poseidon hash4 init failed");
        let input_hash = poseidon_h4
            .hash(&[
                state_root_fe,
                safe_address_fe,
                storage_root_fe,
                storage_key_fe,
            ])
            .expect("poseidon hash failed");

        InputsFe {
            input_hash: format!("0x{}", hex(input_hash.into_bigint().to_bytes_be())),
            safe_address_fe: format!("0x{}", hex(safe_address_fe.into_bigint().to_bytes_be())),
            msg_hash_fe: format!("0x{}", hex(msg_hash_fe.into_bigint().to_bytes_be())),
            state_root_fe: format!("0x{}", hex(state_root_fe.into_bigint().to_bytes_be())),
            storage_root_fe: format!("0x{}", hex(storage_root_fe.into_bigint().to_bytes_be())),
            storage_key_fe: format!("0x{}", hex(storage_key_fe.into_bigint().to_bytes_be())),
            safe_address: inputs.safe_address,
            msg_hash: inputs.msg_hash,
            state_root: inputs.state_root,
            storage_root: inputs.storage_root,
            storage_key: inputs.storage_key,
            account_proof_depth: inputs.account_proof_depth,
            storage_proof_depth: inputs.storage_proof_depth,
            padded_account_value: inputs.padded_account_value,
            account_proof: inputs.account_proof,
            storage_proof: inputs.storage_proof,
            header_rlp: inputs.header_rlp,
            header_rlp_len: inputs.header_rlp_len,
            blockhash: format!("0x{}", hex(blockhash.into_bigint().to_bytes_be())),
            challenge: format!("0x{}", hex(challenge.into_bigint().to_bytes_be())),
        }
    }
}

pub async fn fetch_inputs(
    rpc: &str,
    safe_address: Address,
    msg_hash: H256,
) -> Result<(u64, Inputs)> {
    let storage_key = keccak256(&concat_bytes64(msg_hash.into(), SAFE_SIGNED_MESSAGES_SLOT));

    let provider = Provider::try_from(rpc)?;
    let latest = provider.get_block_number().await?;
    let block = provider.get_block(latest).await?.context("no such block")?;
    let proof = provider
        .get_proof(safe_address, vec![storage_key.into()], Some(latest.into()))
        .await?;

    let account_value = rlp::Rlp::new(
        &proof
            .account_proof
            .last() // Terminal proof node
            .ok_or(anyhow!("State proof empty"))?,
    ) // Proof should have been non-empty
    .as_list::<Vec<u8>>()?
    .last() // Extract value
    .ok_or(anyhow!("RLP list empty"))?
    .to_vec();

    let (header_rlp_len, header_rlp) = rlp_encode_header(&block);

    let TrieProof {
        proof: padded_storage_proof,
        value: _,
        depth: storage_proof_depth,
        key: _,
    } = preprocess_proof(
        &proof.storage_proof[0].proof,
        storage_key.to_vec(),
        SAFE_SIGNED_MSG_VALUE.to_vec(),
        STORAGE_PROOF_MAX_DEPTH,
        MAX_TRIE_NODE_LENGTH,
        MAX_STORAGE_VALUE_LENGTH,
    )
    .map_err(|_| anyhow!("Preprocess storage proof"))?;

    let TrieProof {
        proof: padded_account_proof,
        value: padded_account_value,
        depth: account_proof_depth,
        key: _,
    } = preprocess_proof(
        &proof.account_proof,
        safe_address.as_bytes().to_vec(),
        account_value,
        ACCOUNT_PROOF_MAX_DEPTH,
        MAX_TRIE_NODE_LENGTH,
        MAX_ACCOUNT_STATE_LENGTH,
    )
    .map_err(|_| anyhow!("Preprocess account proof"))?;

    Ok((
        latest.as_u64(),
        Inputs {
            safe_address: safe_address.into(),
            msg_hash: msg_hash.into(),
            header_rlp,
            header_rlp_len,
            state_root: block.state_root.into(),
            storage_root: proof.storage_hash.into(),
            storage_key,
            account_proof_depth,
            storage_proof_depth,
            padded_account_value: padded_account_value
                .try_into()
                .map_err(|_| anyhow!("padded account value"))?,
            account_proof: padded_account_proof
                .try_into()
                .map_err(|_| anyhow!("padded account proof"))?,
            storage_proof: padded_storage_proof
                .try_into()
                .map_err(|_| anyhow!("padded storage proof"))?,
        },
    ))
}

// https://ethereum.stackexchange.com/a/67332
// https://github.com/ethereum/go-ethereum/blob/14eb8967be7acc54c5dc9a416151ac45c01251b6/core/types/block.go#L65
pub fn rlp_encode_header(block: &Block<H256>) -> (usize, [u8; HEADER_RLP_MAX_BYTES]) {
    let mut rlp = RlpStream::new();
    rlp.begin_list(20);
    rlp.append(&block.parent_hash);
    rlp.append(&block.uncles_hash);
    rlp.append(&block.author.expect("author"));
    rlp.append(&block.state_root);
    rlp.append(&block.transactions_root);
    rlp.append(&block.receipts_root);
    rlp.append(&block.logs_bloom.expect("logs_bloom"));
    rlp.append(&block.difficulty);
    rlp.append(&block.number.expect("number"));
    rlp.append(&block.gas_limit);
    rlp.append(&block.gas_used);
    rlp.append(&block.timestamp);
    rlp.append(&block.extra_data.as_bytes().to_vec());
    rlp.append(&block.mix_hash.expect("mix_hash"));
    rlp.append(&block.nonce.expect("nonce"));
    rlp.append(&block.base_fee_per_gas.expect("base_fee_per_gas")); // london
    rlp.append(&block.withdrawals_root.expect("withdrawals_root")); // shanghai
    rlp.append(&block.blob_gas_used.expect("blob_gas_used")); // cancun
    rlp.append(&block.excess_blob_gas.expect("excess_blob_gas")); // cancun
    rlp.append(
        &block
            .parent_beacon_block_root
            .expect("parent_beacon_block_root"),
    ); // cancun
    let mut bytes: Vec<u8> = rlp.out().freeze().into();

    let unpadded_length = bytes.len();
    println!("unpadded_length {}", unpadded_length);
    while bytes.len() < HEADER_RLP_MAX_BYTES {
        bytes.push(0xff);
    }

    (unpadded_length, bytes.try_into().expect("header_rlp"))
}

pub fn lpad_bytes32(x: &[u8; 20]) -> [u8; 32] {
    core::array::from_fn(|i| if i < 12 { 0u8 } else { x[i - 12] })
}

pub fn concat_bytes64(a: [u8; 32], b: [u8; 32]) -> [u8; 64] {
    // https://stackoverflow.com/a/76573243
    unsafe { core::mem::transmute::<[[u8; 32]; 2], [u8; 64]>([a, b]) }
}

pub fn keccak256<T: AsRef<[u8]>>(input: T) -> [u8; 32] {
    let mut out = [0u8; 32];
    let mut k = Keccak::v256();
    k.update(input.as_ref());
    k.finalize(&mut out);
    out
}

pub fn trim_header(header_rlp: [u8; HEADER_RLP_MAX_BYTES]) -> Vec<u8> {
    let mut out = header_rlp[0..HEADER_RLP_MIN_BYTES].to_vec();
    for i in HEADER_RLP_MIN_BYTES..HEADER_RLP_MAX_BYTES {
        if header_rlp[i] != 0xff {
            out.push(header_rlp[i]);
        }
    }
    out
}

/// Trie proof struct mirroring the equivalent Noir code
pub struct TrieProof {
    /// Unhashed key
    key: Vec<u8>,
    /// Flat RLP-encoded proof with appropriate padding
    proof: Vec<u8>,
    /// Actual proof depth
    depth: usize,
    /// The value resolved by the proof
    value: Vec<u8>,
}

/// Trie proof preprocessor. Returns a proof suitable for use in a Noir program using the noir-trie-proofs library.
/// Note: Depending on the application, the `value` field of the struct may have to be further processed, e.g.
/// left-padded to 32 bytes for storage proofs.
///
/// # Arguments
/// * `proof` - Trie proof as a vector of `Bytes`
/// * `key` - Byte vector of the key the trie proof resolves
/// * `value` - Value the key resolves to as a byte vector
/// * `max_depth` - Maximum admissible depth of the trie proof
/// * `max_node_len` - Maximum admissible length of a node in the proof
/// * `max_value_len` - Maximum admissible length of value (in bytes)
pub fn preprocess_proof(
    proof: &[Bytes],
    key: Vec<u8>,
    value: Vec<u8>,
    max_depth: usize,
    max_node_len: usize,
    max_value_len: usize,
) -> Result<TrieProof, Box<dyn std::error::Error>> {
    // Depth of trie proof
    let depth = proof.len();

    // Padded and flattened proof
    let padded_proof = proof
        .clone()
        .into_iter()
        .map(|b| b.to_vec()) // Convert Bytes to Vec<u8>
        .chain({
            let depth_excess = if depth <= max_depth {
                Ok(max_depth - depth)
            } else {
                Err(format!(
                    "The depth of this proof ({}) exceeds the maximum depth specified ({})!",
                    depth, max_depth
                ))
            }?;
            // Append with empty nodes to fill up to depth MAX_DEPTH
            vec![vec![]; depth_excess]
        })
        .map(|mut v| {
            let node_len = v.len();
            let len_excess = if node_len <= max_node_len {
                Ok(max_node_len - node_len)
            } else {
                Err("Node length cannot exceed the given maximum.")
            }
            .unwrap();
            // Then pad each node up to length MAX_NODE_LEN
            v.append(&mut vec![0; len_excess]);
            v
        })
        .flatten()
        .collect::<Vec<u8>>(); // And flatten

    // Left-pad value with zeros
    let padded_value = left_pad(&value, max_value_len)?;

    Ok(TrieProof {
        key,
        proof: padded_proof,
        depth,
        value: padded_value,
    })
}

/// Function for left padding a byte vector with zeros. Returns the padded vector.
///
/// # Arguments
/// * `v` - Byte vector
/// * `max_len` - Desired size of padded vector
fn left_pad(v: &Vec<u8>, max_len: usize) -> Result<Vec<u8>, Box<dyn std::error::Error>> {
    if v.len() > max_len {
        Err(format!("The vector exceeds its maximum expected dimensions.").into())
    } else {
        let mut v_r = v.clone();
        let mut v_l = vec![0u8; max_len - v.len()];

        v_l.append(&mut v_r);

        Ok(v_l)
    }
}
