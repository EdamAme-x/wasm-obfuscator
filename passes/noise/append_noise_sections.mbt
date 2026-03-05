///|
pub fn append_noise_sections(
  wasm : Bytes,
  noise_section_count : Int,
  noise_payload_bytes : Int,
  seed : Int,
) -> Bytes {
  if noise_section_count <= 0 {
    wasm
  } else {
    let payload_len = normalize_non_negative(noise_payload_bytes)
    let mut size_hint = wasm.length() + noise_section_count * (payload_len + 16)
    if size_hint < wasm.length() {
      size_hint = wasm.length()
    }

    let out = @buffer.new(size_hint~)
    out.write_bytes(wasm)

    let random = @wobf_random.new(seed)
    for section_index in 0..<noise_section_count {
      let section_name = build_noise_section_name(random, section_index)
      write_noise_custom_section(out, random, payload_len, section_name)
    }

    out.to_bytes()
  }
}

///|
fn normalize_non_negative(value : Int) -> Int {
  if value < 0 {
    0
  } else {
    value
  }
}

///|
fn write_noise_custom_section(
  out : @buffer.Buffer,
  random : @wobf_random.LcgState,
  payload_len : Int,
  section_name : Bytes,
) -> Unit {
  let section_name_len_leb = @wasmcodec.encode_u32_leb(section_name.length())
  let section_payload_len = section_name_len_leb.length() +
    section_name.length() +
    payload_len

  out.write_byte(b'\x00')
  out.write_bytes(@wasmcodec.encode_u32_leb(section_payload_len))
  out.write_bytes(section_name_len_leb)
  out.write_bytes(section_name)
  for _ in 0..<payload_len {
    out.write_byte(random.next_byte())
  }
}

///|
fn build_noise_section_name(
  random : @wobf_random.LcgState,
  section_index : Int,
) -> Bytes {
  let out = @buffer.new(size_hint=10)
  out.write_bytes(b"wobf.")
  for i in 0..<5 {
    let mixed = random.next_byte().to_int() ^ section_index ^ (i * 17)
    let ch = (97 + (mixed & 0x1F) % 26).to_byte()
    out.write_byte(ch)
  }
  out.to_bytes()
}
