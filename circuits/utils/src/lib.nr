/// See https://hackmd.io/@axiom/BJBledudT
global ACCOUNT_PROOF_MAX_DEPTH = 13;
/// See https://hackmd.io/@axiom/BJBledudT
global STORAGE_PROOF_MAX_DEPTH = 12;
/// Maximum size of the RLP-encoded list representing an account state
global MAX_ACCOUNT_STATE_LENGTH = 134;
/// Maximum length of a state or storage trie node in bytes
global MAX_TRIE_NODE_LENGTH = 532;
/// See https://github.com/safe-global/safe-smart-account/blob/bf943f80fec5ac647159d26161446ac5d716a294/contracts/libraries/SignMessageLib.sol#L24
global SAFE_SIGNED_MSG_VALUE =
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1];
/// Minimum number of bytes of a RLP encoded header
global HEADER_RLP_MIN_BYTES = 577;
/// Maximum number of bytes of a RLP encoded header
global HEADER_RLP_MAX_BYTES = 636;

pub fn bytes32_to_field(
    array: [u8; 32]
) -> Field {
    let mut out: Field = 0;
    for i in 0..32 {
        out = (out * 256) + (array[i] as Field);
    }
    out
}

pub fn bytes20_to_field(
    array: [u8; 20]
) -> Field {
    let mut out: Field = 0;
    for i in 0..20 {
        out = (out * 256) + (array[i] as Field);
    }
    out
}

pub fn extract_state_root(header_rlp: [u8; HEADER_RLP_MAX_BYTES]) -> Field {
    let mut state_root: [u8; 32] = [0; 32];
    for i in 0..32 {
        state_root[i] = header_rlp[i + 91];
    }
    bytes32_to_field(state_root)
}
