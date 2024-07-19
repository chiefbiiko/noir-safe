use dep::std;

fn main(
    sp_vk : [Field; 114],
    sp_vk_hash : Field,
    sp_proof : [Field; 93],
    sp_pi : [Field; 1],
    ap_vk : [Field; 114],
    ap_vk_hash : Field,
    ap_proof : [Field; 93],
    ap_pi : [Field; 1],
) {
    std::verify_proof(
        sp_vk.as_slice(),
        sp_proof.as_slice(),
        sp_pi.as_slice(),
        sp_vk_hash
    );
    std::verify_proof(
        ap_vk.as_slice(),
        ap_proof.as_slice(),
        ap_pi.as_slice(),
        ap_vk_hash
    );
}