use dep::std::hash::{keccak256, poseidon};

#[recursive]
fn main(
    safe_address: Field,
    msg_hash: Field,
    header_rlp: [u8; 590]
) -> pub ([u8; 32], [u8; 32]) {
    let blockhash = keccak256(header_rlp, 590);
    let challenge: [u8; 32] = poseidon::bn254::hash_2([safe_address, msg_hash]).to_be_bytes(32).as_array();

    (blockhash, challenge)
}
