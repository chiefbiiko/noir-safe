use dep::{
    std::hash::poseidon,
    noir_trie_proofs::trie_proof::TrieProof,
    noir_safe_utils::{ACCOUNT_PROOF_MAX_DEPTH, MAX_ACCOUNT_STATE_LENGTH, MAX_TRIE_NODE_LENGTH, bytes20_to_field, bytes32_to_field}
};

#[recursive]
fn main(
    safe_address: [u8; 20],
    state_root: [u8; 32],
    account_proof_depth: u64,
    padded_account_value: [u8; MAX_ACCOUNT_STATE_LENGTH],
    account_proof: [u8; MAX_TRIE_NODE_LENGTH * ACCOUNT_PROOF_MAX_DEPTH],
    input_hash: Field,
    storage_root_fe: Field,
    storage_key_fe: Field,
) {
    let safe_address_fe = bytes20_to_field(safe_address);
    let state_root_fe = bytes32_to_field(state_root);
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
