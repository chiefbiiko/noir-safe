use dep::std::hash::{keccak256, poseidon};
// use dep::noir_trie_proofs::trie_proof::TrieProof;

// ///FROM https://github.com/axiom-crypto/axiom-eth/blob/0a218a7a68c5243305f2cd514d72dae58d536eff/axiom-query/configs/production/all_max.yml#L91
// global ACCOUNT_PROOF_MAX_DEPTH = 7;//14;
// ///FROM https://github.com/axiom-crypto/axiom-eth/blob/0a218a7a68c5243305f2cd514d72dae58d536eff/axiom-query/configs/production/all_max.yml#L116
// global STORAGE_PROOF_MAX_DEPTH = 3;//13;
// ///SEE https://github.com/safe-global/safe-smart-account/blob/bf943f80fec5ac647159d26161446ac5d716a294/contracts/libraries/SignMessageLib.sol#L24
// global SAFE_SIGNED_MSG_VALUE =
//     [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1];
// /// Maximum length of a state or storage trie node in bytes
// global MAX_TRIE_NODE_LENGTH = 532;
// /// Maximum size of the RLP-encoded list representing an account state
// global MAX_ACCOUNT_STATE_LENGTH = 134;

// fn lpad_bytes32(x: [u8; 20]) -> [u8; 32] {
//     let mut out: [u8; 32] = [0; 32];
//     for i in 0..20 {
//         out[i + 12] = x[i];
//     }
//     out
// }

#[recursive]
fn main(
    safe_address: Field,
    msg_hash: Field,
    // state_root: [u8; 32],
    // storage_root: [u8; 32],
    // storage_key: [u8; 32],
    // account_proof_depth: u64,
    // storage_proof_depth: u64,
    // padded_account_value: [u8; MAX_ACCOUNT_STATE_LENGTH],
    // account_proof: [u8; MAX_TRIE_NODE_LENGTH * ACCOUNT_PROOF_MAX_DEPTH],
    // storage_proof: [u8; MAX_TRIE_NODE_LENGTH * STORAGE_PROOF_MAX_DEPTH],
    header_rlp: [u8; 590]
) {
    // let stp = TrieProof {
    //     key: storage_key,
    //     proof: storage_proof,
    //     depth: storage_proof_depth,
    //     value: SAFE_SIGNED_MSG_VALUE
    // };
    // let _ = stp.verify_storage_root(storage_root);

    // let atp = TrieProof {
    //     key: safe_address,
    //     proof: account_proof,
    //     depth: account_proof_depth,
    //     value: padded_account_value
    // };
    // let _ = atp.verify_state_root(state_root);

    //TODO calc challenge and blockhash
    // recalc blockhash using header_rlp incl proven state_root
    // let mut header_rlp = header_rlp;
    // header_rlp[91..123].copy_from_slice(state_root.as_bytes());

    //FIXME header_rlp[91..123] must equal state root used in account proof
    let blockhash = keccak256(header_rlp, 590);

    // let challenge_inputs: [Field; 2] = [safe_address, msg_hash];
    let challenge = poseidon::bn254::hash_2([safe_address, msg_hash]);

//TODO
    // let mut poseidon = Poseidon::<Fr>::new_circom(2).expect("poseidon init failed");
    // // _mod_order might reduce fr2 i.e. it has 2 msg_hash preimages aka collision;
    // // since the 20-byte Safe address cannot exceed bn254's scalar field _mod_order
    // // is always a noop for fr1, i.e. it has strictly 1 Safe address preimage: 
    // // no collisions; consequently "cross-account" collisions can never occur
    // let fr1 = Fr::from_be_bytes_mod_order(&lpad_bytes32(inputs.safe_address));
    // let fr2 = Fr::from_be_bytes_mod_order(&inputs.msg_hash);
    // let challenge: [u8; 32] = poseidon
    //     .hash(&[fr1, fr2])
    //     .expect("poseidon hash failed")
    //     .into_bigint()
    //     .to_bytes_be()
    //     .try_into()
    //     .expect("converting field elements to bytes failed");
}

// #[test]
// fn test_main() {
//     main(1, 2);
// }
