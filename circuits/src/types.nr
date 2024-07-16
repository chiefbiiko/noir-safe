// #[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Inputs {
    safe_address: [u8; 20],      // Safe address
    msg_hash: [u8; 32],          // Custom msg hash
    state_root: [u8; 32],        // eth_getBlockBy*::response.stateRoot
    storage_root: [u8; 32],      // eth_getProof::response.storageHash
    state_trie_key: [u8; 32],    // keccak256(safe)
    storage_trie_key: [u8; 32],  // keccak256(msg_hash + uint256(7))
    account_proof: Vec<u8>,      // eth_getProof::response.accountProof ::flat()
    storage_proof: Vec<u8>,      // eth_getProof::response.storageProof.proof ::flat()
    header_rlp: Vec<u8>,         // RLP-encoded header
}
