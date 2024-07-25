use dep::noir_trie_proofs::trie_proof::TrieProof;

///FROM https://github.com/axiom-crypto/axiom-eth/blob/0a218a7a68c5243305f2cd514d72dae58d536eff/axiom-query/configs/production/all_max.yml#L91
global ACCOUNT_PROOF_MAX_DEPTH = 7;//14;
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
) {
    let atp = TrieProof {
        key: safe_address,
        proof: account_proof,
        depth: account_proof_depth,
        value: padded_account_value
    };
    let _ = atp.verify_state_root(state_root);
}
