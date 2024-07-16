use dep::noir_trie_proofs::trie_proof::TrieProof;

//FROM https://github.com/axiom-crypto/axiom-eth/blob/0a218a7a68c5243305f2cd514d72dae58d536eff/axiom-query/configs/production/all_max.yml#L91
global ACCOUNT_PROOF_MAX_DEPTH = 14;
//FROM https://github.com/axiom-crypto/axiom-eth/blob/0a218a7a68c5243305f2cd514d72dae58d536eff/axiom-query/configs/production/all_max.yml#L116
global STORAGE_PROOF_MAX_DEPTH = 13;
//SEE https://github.com/safe-global/safe-smart-account/blob/bf943f80fec5ac647159d26161446ac5d716a294/contracts/libraries/SignMessageLib.sol#L24
global SAFE_SIGNED_MSG_VALUE =
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1];

fn main(
    safe_address: [u8; 20],
    msg_hash: [u8; 32],
    state_root: [u8; 32],
    storage_root: [u8; 32],
    state_trie_key: [u8; 32],
    storage_trie_key: [u8; 32],
    account_proof: [u8; 4096],
    storage_proof: [u8; 4096],
    header_rlp: [u8; 590]
) {
    //TODO
    //4 account_&storage_proof
    //read real start byte index from first 2 le bytes
    //and discard leading zeros


    let trie_proof = TrieProof {
        key: storage_trie_key,
        proof: storage_proof,
        depth: STORAGE_PROOF_MAX_DEPTH,
        value: SAFE_SIGNED_MSG_VALUE
    };
    let _ = trie_proof.verify_storage_root(storage_root);

    //TODO TrieProof::verify_state_root()

}

//FIXME how2 test with PRover.toml
// #[test]
// fn test_circuit() {
//     main(FIXTURE_OK);
// }
