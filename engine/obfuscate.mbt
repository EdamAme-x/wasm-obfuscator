///|
pub fn obfuscate_core(
  wasm : Bytes,
  noise_section_count : Int,
  noise_payload_bytes : Int,
  seed : Int,
) -> Bytes {
  @noise.append_noise_sections(
    wasm, noise_section_count, noise_payload_bytes, seed,
  )
}
