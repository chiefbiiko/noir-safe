use dep::{
    std::hash::poseidon,
    noir_trie_proofs::trie_proof::TrieProof,
    noir_safe_utils::{SAFE_SIGNED_MSG_VALUE, STORAGE_PROOF_MAX_DEPTH, MAX_TRIE_NODE_LENGTH, bytes32_to_field}
};

// /// See https://hackmd.io/@axiom/BJBledudT
// global STORAGE_PROOF_MAX_DEPTH = 12;
// /// See https://github.com/safe-global/safe-smart-account/blob/bf943f80fec5ac647159d26161446ac5d716a294/contracts/libraries/SignMessageLib.sol#L24
// global SAFE_SIGNED_MSG_VALUE =
//     [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1];
// /// Maximum length of a state or storage trie node in bytes
// global MAX_TRIE_NODE_LENGTH = 532;

#[recursive]
fn main(
    storage_root: [u8; 32],
    storage_key: [u8; 32],
    storage_proof_depth: u64,
    storage_proof: [u8; MAX_TRIE_NODE_LENGTH * STORAGE_PROOF_MAX_DEPTH],
    input_hash: Field,
    safe_address_fe: Field,
    state_root_fe: Field,
    // storage_root_fe: Field,
    // storage_key_fe: Field,
) {
    let storage_key_fe = bytes32_to_field(storage_key);
    let storage_root_fe = bytes32_to_field(storage_root);
    let reput_hash = poseidon::bn254::hash_4([state_root_fe, safe_address_fe, storage_root_fe, storage_key_fe]);
    assert(reput_hash == input_hash);

    let stp = TrieProof {
        key: storage_key,
        proof: storage_proof,
        depth: storage_proof_depth,
        value: SAFE_SIGNED_MSG_VALUE
    };
    let _ = stp.verify_storage_root(storage_root);
}

// fn bytes32_to_field(
//     array: [u8; 32]
// ) -> Field {
//     let mut out: Field = 0;
//     for i in 0..32 {
//         out = (out * 256) + (array[i] as Field);
//     }
//     out
// }