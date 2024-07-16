use noir_trie_proofs::trie_proof::TrieProof;
mod constants;
use constants::{ACCOUNT_PROOF_MAX_DEPTH, STORAGE_PROOF_MAX_DEPTH, SAFE_SIGNED_MSG_VALUE};
mod types;
use types::Inputs;

fn circuit(inputs: Inputs) {
    let trie_proof = TrieProof {
        key: inputs.storage_trie_key,
        proof: inputs.storage_proof,
        depth: STORAGE_PROOF_MAX_DEPTH,
        value: SAFE_SIGNED_MSG_VALUE
    };
    let _ = trie_proof.verify_storage_root(inputs.storage_root);

    //TODO TrieProof::verify_state_root()

}

#[test]
fn test_circuit() {
    circuit(FIXTURE_OK);
}
