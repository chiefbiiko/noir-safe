use dep::std::verify_proof;

fn main(
    sp_vk: [Field; 114],
    sp_vk_hash: Field,
    sp_proof: [Field; 93],
    sp_pi: [Field; 0],
    ap_vk: [Field; 114],
    ap_vk_hash: Field,
    ap_proof: [Field; 93],
    ap_pi: [Field; 0],
    an_vk: [Field; 114],
    an_vk_hash: Field,
    an_proof: [Field; 93],
    an_pi: pub [Field; 2],
) {
    verify_proof(
        sp_vk.as_slice(),
        sp_proof.as_slice(),
        sp_pi.as_slice(),
        sp_vk_hash
    );
    verify_proof(
        ap_vk.as_slice(),
        ap_proof.as_slice(),
        ap_pi.as_slice(),
        ap_vk_hash
    );
    verify_proof(
        an_vk.as_slice(),
        an_proof.as_slice(),
        an_pi.as_slice(),
        an_vk_hash
    );
}