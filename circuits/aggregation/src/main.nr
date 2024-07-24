use dep::std;

fn main(
    sp_vk : [Field; 114],
    sp_vk_hash : Field,
    // https://noir-lang.org/docs/how_to/how-to-recursion/#step-3---verification-and-proof-artifacts
    // says proofs should have a constant size [Field; 93] ¯\_(°ペ)_/¯
    sp_proof : [Field; 89],
    sp_pi : [Field; 4],
    ap_vk : [Field; 114],
    ap_vk_hash : Field,
    ap_proof : [Field; 88],
    ap_pi : [Field; 5],
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