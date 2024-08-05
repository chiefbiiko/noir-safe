use dep::{
    std::hash::poseidon,
    noir_trie_proofs::trie_proof::TrieProof,
};

/// See https://hackmd.io/@axiom/BJBledudT
global ACCOUNT_PROOF_MAX_DEPTH = 13;
/// Maximum length of a state or storage trie node in bytes
global MAX_TRIE_NODE_LENGTH = 532;
/// Maximum size of the RLP-encoded list representing an account state
global MAX_ACCOUNT_STATE_LENGTH = 134;

#[recursive]
fn main(
    safe_address: [u8; 20],
    state_root: [u8; 32],
    account_proof_depth: u64,
    padded_account_value: [u8; MAX_ACCOUNT_STATE_LENGTH],
    account_proof: [u8; MAX_TRIE_NODE_LENGTH * ACCOUNT_PROOF_MAX_DEPTH],
    input_hash: Field,
    safe_address_fe: Field,
    state_root_fe: Field,
    storage_root_fe: Field,
    storage_key_fe: Field,
) {
    let reput_hash = poseidon::bn254::hash_4([state_root_fe, safe_address_fe, storage_root_fe, storage_key_fe]);
    assert(reput_hash == input_hash);

    let atp = TrieProof {
        key: safe_address,
        proof: account_proof,
        depth: account_proof_depth,
        value: padded_account_value
    };
    let _ = atp.verify_state_root(state_root);
}
