///|
fn decode_u32_leb(
  bytes : Bytes,
  offset : Int,
) -> LebRead raise ParseRuntimeError {
  let mut result : UInt = 0U
  let mut shift = 0
  let mut pos = offset
  for _ in 0..<5 {
    if pos >= bytes.length() {
      raise ParseError("Unexpected EOF while reading u32 LEB.")
    }
    let byte = bytes.at(pos).to_int()
    result = result | ((byte & 0x7F).reinterpret_as_uint() << shift)
    pos += 1
    if (byte & 0x80) == 0 {
      return { value: result.reinterpret_as_int(), next_offset: pos }
    }
    shift += 7
  }
  raise ParseError("Invalid u32 LEB encoding.")
}

///|
fn decode_i32_leb(
  bytes : Bytes,
  offset : Int,
) -> LebRead raise ParseRuntimeError {
  let mut result = 0
  let mut shift = 0
  let mut pos = offset
  let mut byte = 0
  for _ in 0..<5 {
    if pos >= bytes.length() {
      raise ParseError("Unexpected EOF while reading i32 LEB.")
    }
    byte = bytes.at(pos).to_int()
    result = result | ((byte & 0x7F) << shift)
    pos += 1
    shift += 7
    if (byte & 0x80) == 0 {
      break
    }
  }
  if (byte & 0x80) != 0 {
    raise ParseError("Invalid i32 LEB encoding.")
  }
  if shift < 32 && (byte & 0x40) != 0 {
    result = result | (-1 << shift)
  }
  { value: result, next_offset: pos }
}

///|
fn encode_u32_leb(value : Int) -> Bytes {
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

///|
fn encode_i32_leb(value : Int) -> Bytes {
  let out = @buffer.new(size_hint=5)
  let mut current = value
  while true {
    let byte = current & 0x7F
    current = current >> 7
    let sign_bit_set = (byte & 0x40) != 0
    let done = (current == 0 && !sign_bit_set) ||
      (current == -1 && sign_bit_set)
    let encoded = if done { byte } else { byte | 0x80 }
    out.write_byte(encoded.to_byte())
    if done {
      break
    }
  }
  out.to_bytes()
}
