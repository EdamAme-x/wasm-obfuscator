///|
pub fn encode_u32_leb(value : Int) -> Bytes {
  let normalized = if value < 0 { 0 } else { value }
  let mut remaining = normalized
  let out = @buffer.new(size_hint=5)
  while true {
    let mut byte = remaining & 0x7F
    remaining = remaining >> 7
    if remaining != 0 {
      byte = byte | 0x80
    }
    out.write_byte(byte.to_byte())
    if remaining == 0 {
      break
    }
  }
  out.to_bytes()
}
