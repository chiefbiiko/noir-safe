use dep::noir_trie_proofs::trie_proof::TrieProof;
use dep::noir_trie_proofs::{state_proof::StateProof, storage_proof::StorageProof};

//FROM https://github.com/axiom-crypto/axiom-eth/blob/0a218a7a68c5243305f2cd514d72dae58d536eff/axiom-query/configs/production/all_max.yml#L91
global ACCOUNT_PROOF_MAX_DEPTH = 14;
//FROM https://github.com/axiom-crypto/axiom-eth/blob/0a218a7a68c5243305f2cd514d72dae58d536eff/axiom-query/configs/production/all_max.yml#L116
global STORAGE_PROOF_MAX_DEPTH = 13;
//SEE https://github.com/safe-global/safe-smart-account/blob/bf943f80fec5ac647159d26161446ac5d716a294/contracts/libraries/SignMessageLib.sol#L24
global SAFE_SIGNED_MSG_VALUE =
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1];
//SEE https://github.com/aragonzkresearch/noir-trie-proofs/blob/cfaba4e612e4e443c0c7c81cb06c4087313a9e2e/src/lib.rs#L11
global MAX_ACCOUNT_STATE_LENGTH = 134;

//SEE https://github.com/aragonzkresearch/noir-trie-proofs/blob/cfaba4e612e4e443c0c7c81cb06c4087313a9e2e/lib/src/const.nr#L8
// proof max byte length: 7448 = 532*14

fn main(
    safe_address: [u8; 20],
    msg_hash: [u8; 32],
    state_root: [u8; 32],
    storage_root: [u8; 32],
    // state_trie_key: [u8; 32],
    storage_key: [u8; 32],
    account_proof_depth: u64,
    storage_proof_depth: u64,
    padded_account_value: [u8; MAX_ACCOUNT_STATE_LENGTH],
    account_proof: [u8; 7448],
    storage_proof: [u8; 7448],
    header_rlp: [u8; 590]
) {
    let stp = TrieProof {
        key: storage_key,
        proof: storage_proof,
        depth: storage_proof_depth,
        value: SAFE_SIGNED_MSG_VALUE
    };
    let _ = stp.verify_storage_root(storage_root);

    // let atp = TrieProof {
    //     key: safe_address,
    //     proof: account_proof,
    //     depth: account_proof_depth,
    //     value: padded_account_value
    // };
    // let _ = atp.verify_state_root(state_root);

    //TODO calc challenge and blockhash
}

//FINDOUT how2 wen test/rels with Prover.toml ?
// #[test]
// fn test_circuit() {
//     main(FIXTURE_OK);
// }
