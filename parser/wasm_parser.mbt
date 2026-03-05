///|
let wasm_header : Bytes = b"\x00asm\x01\x00\x00\x00"

///|
fn parse_module(wasm : Bytes) -> ParsedModule raise ParseRuntimeError {
  if wasm.length() < wasm_header.length() {
    raise ParseError(
      "Wasm binary must include the 8-byte magic+version header.",
    )
  }
  for i in 0..<wasm_header.length() {
    if wasm.at(i) != wasm_header.at(i) {
      raise ParseError("Wasm magic or version is invalid.")
    }
  }

  let mut offset = wasm_header.length()
  let mut function_types : Array[FuncType] = []
  let mut function_type_indices : Array[Int] = []
  let mut function_bodies : Array[Bytes] = []
  let mut exports : Array[ExportEntry] = []

  while offset < wasm.length() {
    let section_id = wasm.at(offset).to_int()
    offset += 1

    let section_size = decode_u32_leb(wasm, offset)
    let payload_len = section_size.value
    offset = section_size.next_offset

    if payload_len < 0 || offset + payload_len > wasm.length() {
      raise ParseError("Section payload length is invalid.")
    }

    let section_start = offset
    let section_end = offset + payload_len
    match section_id {
      1 => function_types = parse_type_section(wasm, section_start, section_end)
      3 =>
        function_type_indices = parse_function_section(
          wasm, section_start, section_end,
        )
      7 => exports = parse_export_section(wasm, section_start, section_end)
      10 =>
        function_bodies = parse_code_section(wasm, section_start, section_end)
      _ => ()
    }

    offset = section_end
  }

  if function_type_indices.length() != function_bodies.length() {
    raise ParseError(
      "Function section and code section entry counts do not match.",
    )
  }

  { function_types, function_type_indices, function_bodies, exports }
}

///|
pub fn validate_wasm(wasm : Bytes) -> Unit raise ParseRuntimeError {
  parse_module(wasm) |> ignore
}

///|
fn parse_type_section(
  wasm : Bytes,
  section_start : Int,
  section_end : Int,
) -> Array[FuncType] raise ParseRuntimeError {
  let mut offset = section_start
  let count_read = decode_u32_leb(wasm, offset)
  let count = count_read.value
  offset = count_read.next_offset

  let types : Array[FuncType] = []
  for _ in 0..<count {
    if offset >= section_end {
      raise ParseError("Type section ended unexpectedly.")
    }
    if wasm.at(offset) != b'\x60' {
      raise RuntimeError("Only function type (0x60) is supported.")
    }
    offset += 1

    let param_count_read = decode_u32_leb(wasm, offset)
    let param_count = param_count_read.value
    offset = param_count_read.next_offset

    let param_types : Array[Byte] = []
    for _ in 0..<param_count {
      if offset >= section_end {
        raise ParseError("Type section ended while reading params.")
      }
      param_types.push(wasm.at(offset))
      offset += 1
    }

    let result_count_read = decode_u32_leb(wasm, offset)
    let result_count = result_count_read.value
    offset = result_count_read.next_offset

    let result_types : Array[Byte] = []
    for _ in 0..<result_count {
      if offset >= section_end {
        raise ParseError("Type section ended while reading results.")
      }
      result_types.push(wasm.at(offset))
      offset += 1
    }

    types.push({ param_types, result_types })
  }

  if offset != section_end {
    raise ParseError("Type section has trailing bytes.")
  }
  types
}

///|
fn parse_function_section(
  wasm : Bytes,
  section_start : Int,
  section_end : Int,
) -> Array[Int] raise ParseRuntimeError {
  let mut offset = section_start
  let count_read = decode_u32_leb(wasm, offset)
  let count = count_read.value
  offset = count_read.next_offset

  let type_indices : Array[Int] = []
  for _ in 0..<count {
    let type_read = decode_u32_leb(wasm, offset)
    type_indices.push(type_read.value)
    offset = type_read.next_offset
  }

  if offset != section_end {
    raise ParseError("Function section has trailing bytes.")
  }
  type_indices
}

///|
fn parse_export_section(
  wasm : Bytes,
  section_start : Int,
  section_end : Int,
) -> Array[ExportEntry] raise ParseRuntimeError {
  let mut offset = section_start
  let count_read = decode_u32_leb(wasm, offset)
  let count = count_read.value
  offset = count_read.next_offset

  let entries : Array[ExportEntry] = []
  for _ in 0..<count {
    let name_len_read = decode_u32_leb(wasm, offset)
    let name_len = name_len_read.value
    offset = name_len_read.next_offset
    if name_len < 0 || offset + name_len > section_end {
      raise ParseError("Export name length is invalid.")
    }

    let name = ascii_from_bytes(wasm, offset, name_len)
    offset += name_len

    if offset >= section_end {
      raise ParseError("Export entry is truncated.")
    }
    let kind = wasm.at(offset)
    offset += 1

    let index_read = decode_u32_leb(wasm, offset)
    entries.push({ name, kind, index: index_read.value })
    offset = index_read.next_offset
  }

  if offset != section_end {
    raise ParseError("Export section has trailing bytes.")
  }
  entries
}

///|
fn parse_code_section(
  wasm : Bytes,
  section_start : Int,
  section_end : Int,
) -> Array[Bytes] raise ParseRuntimeError {
  let mut offset = section_start
  let count_read = decode_u32_leb(wasm, offset)
  let count = count_read.value
  offset = count_read.next_offset

  let bodies : Array[Bytes] = []
  for _ in 0..<count {
    let size_read = decode_u32_leb(wasm, offset)
    let body_size = size_read.value
    offset = size_read.next_offset
    if body_size < 0 || offset + body_size > section_end {
      raise ParseError("Function body size is invalid.")
    }
    bodies.push(copy_subbytes(wasm, offset, body_size))
    offset += body_size
  }

  if offset != section_end {
    raise ParseError("Code section has trailing bytes.")
  }
  bodies
}

///|
fn ascii_from_bytes(
  bytes : Bytes,
  start : Int,
  len : Int,
) -> String raise ParseRuntimeError {
  let out = StringBuilder::new(size_hint=len)
  for i in start..<(start + len) {
    let code = bytes.at(i).to_int()
    if code < 0 || code > 0x7F {
      raise RuntimeError("Only ASCII export names are currently supported.")
    }
    out.write_char(code.unsafe_to_char())
  }
  out.to_string()
}

///|
fn copy_subbytes(bytes : Bytes, start : Int, len : Int) -> Bytes {
  let out = @buffer.new(size_hint=len)
  for i in start..<(start + len) {
    out.write_byte(bytes.at(i))
  }
  out.to_bytes()
}
