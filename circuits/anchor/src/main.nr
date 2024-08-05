use dep::std::hash::{keccak256, poseidon};

#[recursive]
fn main(
    msg_hash_fe: Field,
    header_rlp: [u8; 590],
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

    let blockhash = keccak256(header_rlp, 590);
    let challenge = poseidon::bn254::hash_2([safe_address_fe, msg_hash_fe]);

    (bytes32_to_field(blockhash), challenge)
}

fn bytes32_to_field(
    array: [u8; 32]
) -> Field {
    let mut out: Field = 0;
    for i in 0..32 {
        out = (out * 256) + (array[i] as Field);
    }
    out
}

fn extract_state_root(header_rlp: [u8; 590]) -> Field {
    let mut state_root: [u8; 32] = [0; 32];
    for i in 0..32 {
        state_root[i] = header_rlp[i + 91];
    }
    bytes32_to_field(state_root)
}
