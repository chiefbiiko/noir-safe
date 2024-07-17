use dep::noir_trie_proofs::trie_proof::TrieProof;
use dep::noir_trie_proofs::{state_proof::StateProof, storage_proof::StorageProof};

//FROM https://github.com/axiom-crypto/axiom-eth/blob/0a218a7a68c5243305f2cd514d72dae58d536eff/axiom-query/configs/production/all_max.yml#L91
global ACCOUNT_PROOF_MAX_DEPTH = 14;
//FROM https://github.com/axiom-crypto/axiom-eth/blob/0a218a7a68c5243305f2cd514d72dae58d536eff/axiom-query/configs/production/all_max.yml#L116
global STORAGE_PROOF_MAX_DEPTH = 13;
//SEE https://github.com/safe-global/safe-smart-account/blob/bf943f80fec5ac647159d26161446ac5d716a294/contracts/libraries/SignMessageLib.sol#L24
global SAFE_SIGNED_MSG_VALUE =
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1];

//SEE https://github.com/aragonzkresearch/noir-trie-proofs/blob/cfaba4e612e4e443c0c7c81cb06c4087313a9e2e/lib/src/const.nr#L8
// proof max byte length: 7448 = 532*14

fn main(
    safe_address: [u8; 20],
    msg_hash: [u8; 32],
    state_root: [u8; 32],
    storage_root: [u8; 32],
    state_trie_key: [u8; 32],
    storage_key: [u8; 32],
    account_proof: [u8; 7448],
    storage_proof: [u8; 7448],
    header_rlp: [u8; 590]
) {
    // let sp_idx = storage_proof[0] as u16 + (storage_proof[1] << 8) as u16;
    // let ap_idx = account_proof[0] as u16 + (account_proof[1] << 8) as u16;
    // let sp = tail(storage_proof, sp_idx);
    // let ap = tail(account_proof, ap_idx);

    let stp = TrieProof {
        key: storage_key,
        proof: storage_proof, //sp.as_array(),
        depth: STORAGE_PROOF_MAX_DEPTH,
        value: SAFE_SIGNED_MSG_VALUE
    };
    let _ = stp.verify_storage_root(storage_root);
    //TODO TrieProof::verify_state_root()
}

// fn tail(arr: [u8; 7448], offset: u16) -> [u8] {
//     let mut slice = &[];
//     for i in 0..(7448 - offset) {
//         slice = slice.push_back(arr[i + offset]);
//     }
//     slice
// }

//FIXME how2 test with PRover.toml
// #[test]
// fn test_circuit() {
//     main(FIXTURE_OK);
// }
