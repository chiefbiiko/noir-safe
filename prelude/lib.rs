use anyhow::{Context, Result};
use ethers::{
    providers::{Middleware, Provider},
    types::{Address, Block, Bytes, H256},
};
use rlp::RlpStream;
use serde::{Deserialize, Serialize};
use tiny_keccak::{Hasher, Keccak};
use zerocopy::AsBytes;

pub const SAFE_SIGNED_MESSAGES_SLOT: [u8; 32] = [
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7,
];
pub const SAFE_SIGNED_MSG_VALUE: [u8; 32] =
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1];

//FROM https://github.com/axiom-crypto/axiom-eth/blob/0a218a7a68c5243305f2cd514d72dae58d536eff/axiom-query/configs/production/all_max.yml#L91
const ACCOUNT_PROOF_MAX_DEPTH: usize = 14;
//FROM https://github.com/axiom-crypto/axiom-eth/blob/0a218a7a68c5243305f2cd514d72dae58d536eff/axiom-query/configs/production/all_max.yml#L116
const STORAGE_PROOF_MAX_DEPTH: usize = 13;
/// Maximum length of a state or storage trie node in bytes
const MAX_TRIE_NODE_LENGTH: usize = 532;
/// Maximum size of the value in a storage slot
const MAX_STORAGE_VALUE_LENGTH: usize = 32;
/// Maximum size of the RLP-encoded list representing an account state
const MAX_ACCOUNT_STATE_LENGTH: usize = 134;

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Inputs {
    pub safe_address: [u8; 20],     // Safe address
    pub msg_hash: [u8; 32],         // Custom msg hash
    pub state_root: [u8; 32],       // eth_getBlockBy*::response.stateRoot
    pub storage_root: [u8; 32],     // eth_getProof::response.storageHash
    // pub state_trie_key: [u8; 32],   // keccak256(safe)
    pub storage_key: [u8; 32],      // keccak256(msg_hash + uint256(7))
    pub account_proof_depth: usize, // eth_getProof::response.accountProof.len()
    pub storage_proof_depth: usize, // eth_getProof::response.storageProof.proof.len()
    #[serde(with = "serde_arrays")]
    pub padded_account_value: [u8; MAX_ACCOUNT_STATE_LENGTH],
    #[serde(with = "serde_arrays")]
    pub account_proof: [u8; MAX_TRIE_NODE_LENGTH * ACCOUNT_PROOF_MAX_DEPTH],  // eth_getProof::response.accountProof
    #[serde(with = "serde_arrays")]
    pub storage_proof: [u8; MAX_TRIE_NODE_LENGTH * STORAGE_PROOF_MAX_DEPTH],  // eth_getProof::response.storageProof.proof
    #[serde(with = "serde_arrays")]
    pub header_rlp: [u8; 590],      // RLP-encoded header
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

    let nonce = provider.get_transaction_count(safe_address, Some(latest.into())).await?;
    let balance = provider.get_balance(safe_address, Some(latest.into())).await?;
    let code = provider.get_code(safe_address, Some(latest.into())).await?;

    let storage_proof_depth =  proof.storage_proof[0].proof.len();
    let account_proof_depth =  proof.account_proof.len();

    let Padded {
        proof: padded_storage_proof,
        value: _
    } = preprocess_proof(
        &proof.storage_proof[0].proof,
        storage_key.to_vec(), 
        SAFE_SIGNED_MSG_VALUE.to_vec(), 
        STORAGE_PROOF_MAX_DEPTH, 
        MAX_TRIE_NODE_LENGTH, 
        MAX_STORAGE_VALUE_LENGTH
    ).expect("TODO");

    let account_node: Vec<u8> = vec![
        &nonce.as_u64().to_be_bytes(), // 8 bytes
        &balance.as_u128().to_be_bytes()[4..16], // 12 bytes
        proof.storage_hash.as_bytes(), // 32 bytes
        keccak256(code).as_bytes() // 32 bytes
    ].into_iter().flatten().map(|b| *b).collect();

    let Padded {
        proof: padded_account_proof,
        value: padded_account_value
    } = preprocess_proof(
        &proof.account_proof,
        safe_address.as_bytes().into(), 
        account_node,
        ACCOUNT_PROOF_MAX_DEPTH, 
        MAX_TRIE_NODE_LENGTH, 
        MAX_ACCOUNT_STATE_LENGTH
    ).expect("TODO");

    Ok((
        latest.as_u64(),
        Inputs {
            safe_address: safe_address.into(),
            msg_hash: msg_hash.into(),
            header_rlp: rlp_encode_header(&block),
            state_root: block.state_root.into(),
            storage_root: proof.storage_hash.into(),
            // state_trie_key: keccak256(&safe_address),
            // storage_trie_key: keccak256(&storage_key),
            storage_key: storage_key,
            account_proof_depth,
            storage_proof_depth,
            padded_account_value: padded_account_value.try_into().expect("padded account value"),
            account_proof: padded_account_proof.try_into().expect("padded account proof"),
            storage_proof: padded_storage_proof.try_into().expect("padded storage proof"),
        },
    ))
}

// https://ethereum.stackexchange.com/a/67332
// https://github.com/ethereum/go-ethereum/blob/14eb8967be7acc54c5dc9a416151ac45c01251b6/core/types/block.go#L65
pub fn rlp_encode_header(block: &Block<H256>) -> [u8; 590] {
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
    let bytes: Vec<u8> = rlp.out().freeze().into();
    bytes.try_into().expect("header_rlp")
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

// / Left-pads zeros while writing the new head index into the first two bytes.
/// Right-pads zeros up to a length of 7448.
fn fixed_size_proof(proof: &[Bytes]) -> [u8; 7448] {
    let vsa = proof
        .iter()
        .map(|b| b.as_bytes().to_vec())
        .flatten()
        .map(|b| b as u8) //
        .collect::<Vec<u8>>();
    let mut fsa: [u8; 7448] = [0; 7448];
    // let idx = 4094_u16 - vsa.len() as u16 + 2_u16;
    // let idx_le = idx.to_le_bytes();
    // fsa[0] = idx_le[0] as u8;
    // fsa[1] = idx_le[1] as u8;
    // fsa[(idx as usize)..7448].copy_from_slice(&vsa);
    fsa[0..vsa.len()].copy_from_slice(&vsa);
    fsa
}

//////////



/// Trie proof padding struct mirroring the equivalent Noir code
pub struct Padded
{
    // /// Unhashed key
    // key: Vec<u8>,
    /// Flat RLP-encoded proof with appropriate padding
    proof: Vec<u8>,
    // /// Actual proof depth
    // depth: usize,
    /// The value resolved by the proof
    value: Vec<u8>,
}

// impl TrieProof
// {
//     /// Proof Toml string formatter. Returns a string with the table entries corresponding to a `TrieProof`.
//     ///
//     /// # Arguments
//     /// * `tp` - A reference to a trie proof
//     pub fn to_toml_string(&self, proof_name: &str) -> String
//     {
//         // Print Toml string
//         format!(
//             "[{}]\nkey = {:#04x?}\nproof = {:#04x?}\ndepth = {:#04x?}\nvalue = {:#04x?}",
//             proof_name, self.key, self.proof, self.depth, self.value
//         )
//     }
// }


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
) -> Result<Padded, Box<dyn std::error::Error>>
{
    // Depth of trie proof
    let depth = proof.len();

    // Padded and flattened proof
    let padded_proof = proof
        .clone()
        .into_iter()
        .map(|b| b.to_vec()) // Convert Bytes to Vec<u8>
        .chain({
            let depth_excess = if depth <= max_depth
            {
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
            let len_excess = if node_len <= max_node_len
            {
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

    Ok(Padded {
        // key,
        proof: padded_proof,
        // depth,
        value: padded_value,
    })
}

/// Function for left padding a byte vector with zeros. Returns the padded vector.
///
/// # Arguments
/// * `v` - Byte vector
/// * `max_len` - Desired size of padded vector
fn left_pad(v: &Vec<u8>, max_len: usize) -> Result<Vec<u8>, Box<dyn std::error::Error>>
{
    if v.len() > max_len
    {
        Err(format!("The vector exceeds its maximum expected dimensions.").into())
    } else {
        let mut v_r = v.clone();
        let mut v_l = vec![0u8; max_len - v.len()];

        v_l.append(&mut v_r);

        Ok(v_l)
    }
}