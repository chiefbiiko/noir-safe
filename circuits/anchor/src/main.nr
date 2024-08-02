use dep::std::hash::{keccak256, poseidon};

fn bytes32_to_field(
    array: [u8; 32]
) -> Field {
    let mut out: Field = 0;
    for i in 0..32 {
        out = (out * 256) + (array[i] as Field);
    }
    out
}

#[recursive]
fn main(
    safe_address: Field,
    msg_hash: Field,
    header_rlp: [u8; 590]
) -> pub (Field, Field) {
    let blockhash = keccak256(header_rlp, 590);
    let challenge = poseidon::bn254::hash_2([safe_address, msg_hash]);
    (bytes32_to_field(blockhash), challenge)
}
