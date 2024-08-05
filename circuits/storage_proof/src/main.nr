use dep::{
    std::hash::poseidon,
    noir_trie_proofs::trie_proof::TrieProof,
};

///FROM https://github.com/axiom-crypto/axiom-eth/blob/0a218a7a68c5243305f2cd514d72dae58d536eff/axiom-query/configs/production/all_max.yml#L116
global STORAGE_PROOF_MAX_DEPTH = 3;//13;
///SEE https://github.com/safe-global/safe-smart-account/blob/bf943f80fec5ac647159d26161446ac5d716a294/contracts/libraries/SignMessageLib.sol#L24
global SAFE_SIGNED_MSG_VALUE =
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1];
/// Maximum length of a state or storage trie node in bytes
global MAX_TRIE_NODE_LENGTH = 532;

#[recursive]
fn main(
    storage_root: [u8; 32],
    storage_key: [u8; 32],
    storage_proof_depth: u64,
    storage_proof: [u8; MAX_TRIE_NODE_LENGTH * STORAGE_PROOF_MAX_DEPTH],

    input_hash: Field,
    safe_address_fe: Field,
    state_root_fe: Field,
    storage_root_fe: Field,
    storage_key_fe: Field,
) {
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
