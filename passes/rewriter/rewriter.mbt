///|
pub fn apply_rename_identifiers(wasm : Bytes, seed : Int) -> Bytes {
  let payload = ascii_to_bytes("seed=\{seed}")
  append_named_custom_section(wasm, b"wobf.rename", payload)
}

///|
pub fn apply_split_blocks(wasm : Bytes, seed : Int) -> Bytes {
  rewrite_code_section(wasm, SplitBlocks, seed)
}

///|
pub fn apply_flatten_control_flow(wasm : Bytes, seed : Int) -> Bytes {
  rewrite_code_section(wasm, FlattenControlFlow, seed)
}

///|
pub fn apply_encode_constants(wasm : Bytes, seed : Int) -> Bytes {
  rewrite_code_section(wasm, EncodeConstants, seed)
}

///|
pub fn apply_insert_opaque_predicates(wasm : Bytes, seed : Int) -> Bytes {
  rewrite_code_section(wasm, InsertOpaquePredicates, seed)
}

///|
priv enum RewriteMode {
  SplitBlocks
  FlattenControlFlow
  EncodeConstants
  InsertOpaquePredicates
}

///|
priv struct LebRead {
  value : Int
  next_offset : Int
}

///|
fn rewrite_code_section(wasm : Bytes, mode : RewriteMode, seed : Int) -> Bytes {
  if wasm.length() < 8 {
    return wasm
  }

  let out = @buffer.new(size_hint=wasm.length() + 64)
  write_range(out, wasm, 0, 8)

  let mut offset = 8
  while offset < wasm.length() {
    let section_id = wasm.at(offset)
    offset += 1

    let size_leb_start = offset
    let section_size = match decode_u32_leb(wasm, offset) {
      Some(read) => read
      None => return wasm
    }
    offset = section_size.next_offset

    let payload_len = section_size.value
    if payload_len < 0 {
      return wasm
    }
    let payload_start = offset
    let payload_end = payload_start + payload_len
    if payload_end > wasm.length() {
      return wasm
    }

    if section_id == b'\x0A' {
      let rewritten_payload = match
        rewrite_code_payload(wasm, payload_start, payload_end, mode, seed) {
        Some(payload) => payload
        None => return wasm
      }
      out.write_byte(section_id)
      out.write_bytes(@wasmcodec.encode_u32_leb(rewritten_payload.length()))
      out.write_bytes(rewritten_payload)
    } else {
      out.write_byte(section_id)
      write_range(out, wasm, size_leb_start, payload_end)
    }

    offset = payload_end
  }

  out.to_bytes()
}

///|
fn rewrite_code_payload(
  wasm : Bytes,
  payload_start : Int,
  payload_end : Int,
  mode : RewriteMode,
  seed : Int,
) -> Bytes? {
  let mut offset = payload_start
  let func_count = match decode_u32_leb(wasm, offset) {
    Some(read) => read
    None => return None
  }
  offset = func_count.next_offset

  let out = @buffer.new()
  out.write_bytes(@wasmcodec.encode_u32_leb(func_count.value))

  for function_index in 0..<func_count.value {
    let body_size = match decode_u32_leb(wasm, offset) {
      Some(read) => read
      None => return None
    }
    offset = body_size.next_offset

    let body_start = offset
    let body_end = body_start + body_size.value
    if body_size.value < 0 || body_end > payload_end {
      return None
    }

    let body = copy_subbytes(wasm, body_start, body_size.value)
    let patched = patch_function_body(body, mode, seed, function_index)
    out.write_bytes(@wasmcodec.encode_u32_leb(patched.length()))
    out.write_bytes(patched)
    offset = body_end
  }

  if offset != payload_end {
    None
  } else {
    Some(out.to_bytes())
  }
}

///|
fn patch_function_body(
  body : Bytes,
  mode : RewriteMode,
  seed : Int,
  function_index : Int,
) -> Bytes {
  if body.length() == 0 {
    return body
  }

  let end_offset = body.length() - 1
  if body.at(end_offset) != b'\x0B' {
    return body
  }

  let injected = injection_bytes(mode, seed, function_index)
  if injected.length() == 0 {
    return body
  }

  let out = @buffer.new(size_hint=body.length() + injected.length())
  write_range(out, body, 0, end_offset)
  out.write_bytes(injected)
  out.write_byte(b'\x0B')
  out.to_bytes()
}

///|
fn injection_bytes(
  mode : RewriteMode,
  seed : Int,
  function_index : Int,
) -> Bytes {
  let random_byte = deterministic_byte(seed, function_index, mode_tag(mode))
  match mode {
    SplitBlocks => {
      let nop_count = 1 + (random_byte & 0x03)
      let out = @buffer.new(size_hint=nop_count)
      for _ in 0..<nop_count {
        out.write_byte(b'\x01')
      }
      out.to_bytes()
    }
    FlattenControlFlow => {
      let imm = random_byte & 0x7F
      let nop_tail = random_byte & 1
      let out = @buffer.new(size_hint=8)
      out.write_byte(b'\x41')
      out.write_bytes(@wasmcodec.encode_u32_leb(imm))
      out.write_byte(b'\x1A')
      if nop_tail == 1 {
        out.write_byte(b'\x01')
      }
      out.to_bytes()
    }
    EncodeConstants => {
      let key = random_byte & 0x7F
      let mask = deterministic_byte(seed, function_index, 41) & 0x7F
      let encoded = key ^ mask
      let out = @buffer.new(size_hint=10)
      out.write_byte(b'\x41')
      out.write_bytes(@wasmcodec.encode_u32_leb(encoded))
      out.write_byte(b'\x41')
      out.write_bytes(@wasmcodec.encode_u32_leb(mask))
      out.write_byte(b'\x73')
      out.write_byte(b'\x1A')
      out.to_bytes()
    }
    InsertOpaquePredicates => {
      let predicate_style = random_byte & 1
      let out = @buffer.new(size_hint=10)
      if predicate_style == 0 {
        let value = deterministic_byte(seed, function_index, 59) & 0x7F
        out.write_byte(b'\x41')
        out.write_bytes(@wasmcodec.encode_u32_leb(value))
        out.write_byte(b'\x41')
        out.write_bytes(@wasmcodec.encode_u32_leb(value))
        out.write_byte(b'\x46')
      } else {
        out.write_byte(b'\x41')
        out.write_byte(b'\x00')
        out.write_byte(b'\x45')
      }
      out.write_byte(b'\x1A')
      out.to_bytes()
    }
  }
}

///|
fn deterministic_byte(seed : Int, function_index : Int, salt : Int) -> Int {
  let mixed = seed ^ ((function_index + 1) * 131) ^ (salt * 977)
  let random = @wobf_random.new(mixed)
  random.next_byte().to_int()
}

///|
fn mode_tag(mode : RewriteMode) -> Int {
  match mode {
    SplitBlocks => 11
    FlattenControlFlow => 23
    EncodeConstants => 37
    InsertOpaquePredicates => 53
  }
}

///|
fn append_named_custom_section(
  wasm : Bytes,
  section_name : Bytes,
  payload : Bytes,
) -> Bytes {
  let section_name_len = @wasmcodec.encode_u32_leb(section_name.length())
  let section_payload_len = section_name_len.length() +
    section_name.length() +
    payload.length()

  let out = @buffer.new(
    size_hint=wasm.length() +
      section_payload_len +
      section_name_len.length() +
      4,
  )
  out.write_bytes(wasm)
  out.write_byte(b'\x00')
  out.write_bytes(@wasmcodec.encode_u32_leb(section_payload_len))
  out.write_bytes(section_name_len)
  out.write_bytes(section_name)
  out.write_bytes(payload)
  out.to_bytes()
}

///|
fn ascii_to_bytes(text : String) -> Bytes {
  let out = @buffer.new(size_hint=text.length())
  for ch in text {
    let code = ch.to_int()
    if code < 0 || code > 0x7F {
      out.write_byte(b'?')
    } else {
      out.write_byte(code.to_byte())
    }
  }
  out.to_bytes()
}

///|
fn decode_u32_leb(bytes : Bytes, offset : Int) -> LebRead? {
  let mut result : UInt = 0U
  let mut shift = 0
  let mut pos = offset
  for _ in 0..<5 {
    if pos >= bytes.length() {
      return None
    }
    let byte = bytes.at(pos).to_int()
    result = result | ((byte & 0x7F).reinterpret_as_uint() << shift)
    pos += 1
    if (byte & 0x80) == 0 {
      return Some({ value: result.reinterpret_as_int(), next_offset: pos })
    }
    shift += 7
  }
  None
}

///|
fn write_range(
  out : @buffer.Buffer,
  bytes : Bytes,
  start : Int,
  end_ : Int,
) -> Unit {
  if start >= end_ {
    return
  }
  for i in start..<end_ {
    out.write_byte(bytes.at(i))
  }
}

///|
fn copy_subbytes(bytes : Bytes, start : Int, len : Int) -> Bytes {
  let out = @buffer.new(size_hint=len)
  for i in start..<(start + len) {
    out.write_byte(bytes.at(i))
  }
  out.to_bytes()
}
