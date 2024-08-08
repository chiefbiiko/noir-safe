use dep::{
    std::hash::{keccak256, poseidon},
    noir_safe_utils::{HEADER_RLP_MAX_BYTES, bytes32_to_field, extract_state_root}
};

#[recursive]
fn main(
    msg_hash_fe: Field,
    header_rlp: [u8; HEADER_RLP_MAX_BYTES],
    header_rlp_len: u32,
    input_hash: Field,
    safe_address_fe: Field,
    state_root_fe: Field,
    storage_root_fe: Field,
    storage_key_fe: Field,
) -> pub (Field, Field) {
    let reput_hash = poseidon::bn254::hash_4([state_root_fe, safe_address_fe, storage_root_fe, storage_key_fe]);
    assert(reput_hash == input_hash);

    let state_root_xt = extract_state_root(header_rlp);
    assert(state_root_fe == state_root_xt);

    // let blockhash = keccak256(header_rlp, 590);
    let blockhash = keccak256(header_rlp, header_rlp_len);
    let challenge = poseidon::bn254::hash_2([safe_address_fe, msg_hash_fe]);

    (bytes32_to_field(blockhash), challenge)
}
