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

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Inputs {
    pub safe_address: [u64; 20],     // Safe address
    pub msg_hash: [u64; 32],         // Custom msg hash
    pub state_root: [u64; 32],       // eth_getBlockBy*::response.stateRoot
    pub storage_root: [u64; 32],     // eth_getProof::response.storageHash
    pub state_trie_key: [u64; 32],   // keccak256(safe)
    pub storage_trie_key: [u64; 32], // keccak256(msg_hash + uint256(7))
    #[serde(with = "serde_arrays")]
    pub account_proof: [u64; 4096],  // eth_getProof::response.accountProof
    #[serde(with = "serde_arrays")]
    pub storage_proof: [u64; 4096],  // eth_getProof::response.storageProof.proof
    #[serde(with = "serde_arrays")]
    pub header_rlp: [u64; 590],      // RLP-encoded header
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

    Ok((
        latest.as_u64(),
        Inputs {
            safe_address: safe_address.into(),
            msg_hash: msg_hash.into(),
            header_rlp: rlp_encode_header(&block),
            state_root: block.state_root.into(),
            storage_root: proof.storage_hash.into(),
            state_trie_key: keccak256(&safe_address),
            storage_trie_key: keccak256(&storage_key),
            account_proof: proof
                .account_proof
                .iter()
                .map(|b| b.as_bytes().to_vec())
                .flatten()
                .collect(),
            storage_proof: proof.storage_proof[0]
                .proof
                .iter()
                .map(|b| b.as_bytes().to_vec())
                .flatten()
                .collect(),
        },
    ))

    // Ok((
    //     latest.as_u64(),
    //     Inputs {
    //         safe_address: u8_to_u64_arr(safe_address.into()), //safe_address.into()
    //         msg_hash: u8_to_u64_arr(msg_hash.into()), //msg_hash.into()
    //         header_rlp: rlp_encode_header(&block), //.into_iter().map(|b| b as u64).collect(), //rlp_encode_header(&block)
    //         state_root: u8_to_u64_arr(block.state_root.into()), //block.state_root.into(),
    //         storage_root: u8_to_u64_arr(proof.storage_hash.into()), //proof.storage_hash.into()
    //         state_trie_key: u8_to_u64_arr(keccak256(&safe_address)), //keccak256(&safe_address)
    //         storage_trie_key: u8_to_u64_arr(keccak256(&storage_key)), //keccak256(&storage_key)
    //         account_proof: fixed_size_proof(&proof.account_proof),
    //             // proof
    //             //     .account_proof
    //             //     .iter()
    //             //     .map(|b| b.as_bytes().to_vec())
    //             //     .flatten()
    //             //     .collect(),
    //         storage_proof: fixed_size_proof(&proof.storage_proof[0].proof)
    //             // proof.storage_proof[0]
    //             //     .proof
    //             //     .iter()
    //             //     .map(|b| b.as_bytes().to_vec())
    //             //     .flatten()
    //             //     .collect(),
    //     },
    // ))
}

// https://ethereum.stackexchange.com/a/67332
// https://github.com/ethereum/go-ethereum/blob/14eb8967be7acc54c5dc9a416151ac45c01251b6/core/types/block.go#L65
pub fn rlp_encode_header(block: &Block<H256>) -> [u64; 590] {
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
    bytes.into_iter().map(|b| b as u64).collect::<Vec<u64>>().try_into().expect("header_rlp")
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

fn u8_to_u64_arr<const L: usize>(byte_array: [u8; L]) -> [u64; L] {
    byte_array.as_bytes().into_iter().map(|b| *b as u64).collect::<Vec<u64>>().try_into().unwrap()
}

fn fixed_size_proof(proof: &[Bytes]) -> [u64; 4096] {
   proof.iter()
    .map(|b| b.as_bytes().to_vec())
    .flatten()
    .map(|b| b as u64) //
    .collect::<Vec<u64>>()
    .try_into()
    .expect("proof")
}