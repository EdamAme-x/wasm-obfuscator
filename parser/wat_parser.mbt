///|
pub fn wat_to_wasm(wat : String) -> Bytes raise ParseRuntimeError {
  let tokens = tokenize_wat(wat)
  let cursor = { tokens, index: 0 }
  let functions = parse_wat_module(cursor)
  compile_wat_module(functions)
}

///|
fn tokenize_wat(wat : String) -> Array[String] raise ParseRuntimeError {
  let tokens : Array[String] = []
  let len = wat.length()
  let mut i = 0
  while i < len {
    let code = wat.unsafe_get(i).to_int()
    if is_space(code) {
      i += 1
    } else if code == '(' &&
      i + 1 < len &&
      wat.unsafe_get(i + 1).to_int() == ';' {
      i = skip_block_comment(wat, i + 2)
    } else if code == '(' {
      tokens.push("(")
      i += 1
    } else if code == ')' {
      tokens.push(")")
      i += 1
    } else if code == ';' &&
      i + 1 < len &&
      wat.unsafe_get(i + 1).to_int() == ';' {
      i += 2
      while i < len && wat.unsafe_get(i).to_int() != '\n' {
        i += 1
      }
    } else if code == '"' {
      let (string_token, next_offset) = read_string_literal(wat, i + 1)
      tokens.push("str:\{string_token}")
      i = next_offset
    } else {
      let start = i
      while i < len && !is_delimiter(wat.unsafe_get(i).to_int()) {
        i += 1
      }
      tokens.push(slice_string(wat, start, i))
    }
  }
  tokens
}

///|
fn skip_block_comment(wat : String, start : Int) -> Int raise ParseRuntimeError {
  let len = wat.length()
  let mut i = start
  let mut depth = 1
  while i < len {
    let code = wat.unsafe_get(i).to_int()
    if code == '(' && i + 1 < len && wat.unsafe_get(i + 1).to_int() == ';' {
      depth += 1
      i += 2
    } else if code == ';' &&
      i + 1 < len &&
      wat.unsafe_get(i + 1).to_int() == ')' {
      depth -= 1
      i += 2
      if depth == 0 {
        return i
      }
    } else {
      i += 1
    }
  }
  raise ParseError("Unterminated block comment in WAT.")
}

///|
fn slice_string(source : String, start : Int, end_ : Int) -> String {
  let source_len = source.length()
  let mut begin = if start < 0 { 0 } else { start }
  let mut end = if end_ < 0 { 0 } else { end_ }
  if begin > source_len {
    begin = source_len
  }
  if end > source_len {
    end = source_len
  }
  if end < begin {
    end = begin
  }
  let view = source[begin:end] catch {
      _ => return copy_code_units(source, begin, end)
    }
  view.to_string()
}

///|
fn copy_code_units(source : String, begin : Int, end_ : Int) -> String {
  let out = StringBuilder::new(size_hint=end_ - begin)
  for i in begin..<end_ {
    out.write_char(source.unsafe_get(i).to_int().unsafe_to_char())
  }
  out.to_string()
}

///|
fn read_string_literal(
  wat : String,
  start : Int,
) -> (String, Int) raise ParseRuntimeError {
  let len = wat.length()
  let mut i = start
  let out = StringBuilder::new()
  while i < len {
    let code = wat.unsafe_get(i).to_int()
    if code == '"' {
      return (out.to_string(), i + 1)
    }
    if code == '\\' {
      i += 1
      if i >= len {
        raise ParseError("Unterminated escape sequence in string literal.")
      }
      let esc = wat.unsafe_get(i).to_int()
      match esc {
        'n' => out.write_char('\n')
        't' => out.write_char('\t')
        '\\' => out.write_char('\\')
        '"' => out.write_char('"')
        _ => raise ParseError("Unsupported string escape sequence in WAT.")
      }
      i += 1
    } else {
      out.write_char(code.unsafe_to_char())
      i += 1
    }
  }
  raise ParseError("Unterminated string literal in WAT.")
}

///|
fn is_space(code : Int) -> Bool {
  code == ' ' || code == '\n' || code == '\r' || code == '\t'
}

///|
fn is_delimiter(code : Int) -> Bool {
  is_space(code) || code == '(' || code == ')'
}

///|
fn parse_wat_module(
  cursor : TokenCursor,
) -> Array[WatFunction] raise ParseRuntimeError {
  cursor.expect("(")
  cursor.expect("module")
  let functions : Array[WatFunction] = []
  while true {
    match cursor.peek() {
      Some(tok) => {
        if tok == ")" {
          break
        }
        functions.push(parse_wat_function(cursor))
      }
      None => raise ParseError("Unterminated module form in WAT.")
    }
  }
  cursor.expect(")")
  if cursor.has_next() {
    raise ParseError("Trailing tokens after module.")
  }
  if functions.length() == 0 {
    raise ParseError("WAT module must contain at least one function.")
  }
  functions
}

///|
fn parse_wat_function(
  cursor : TokenCursor,
) -> WatFunction raise ParseRuntimeError {
  cursor.expect("(")
  cursor.expect("func")

  match cursor.peek() {
    Some(tok) => if tok.has_prefix("$") { cursor.next() |> ignore }
    None => ()
  }

  let mut export_name : String? = None
  let mut param_count = 0
  let mut local_count = 0
  let mut result_count = 0
  let instructions : Array[WatInstr] = []

  while true {
    match cursor.peek() {
      Some(tok) => {
        if tok == ")" {
          break
        }
        if tok == "(" {
          cursor.expect("(")
          let clause = cursor.next()
          match clause {
            "export" => {
              let token = cursor.next()
              export_name = Some(parse_string_token(token))
              cursor.expect(")")
            }
            "param" => {
              while true {
                match cursor.peek() {
                  Some(param_tok) => {
                    if param_tok == ")" {
                      break
                    }
                    let token = cursor.next()
                    if token.has_prefix("$") {
                      continue
                    }
                    if token != "i32" {
                      raise RuntimeError("Only i32 parameters are supported.")
                    }
                    param_count += 1
                  }
                  None => raise ParseError("Unterminated (param ...) clause.")
                }
              }
              cursor.expect(")")
            }
            "result" => {
              while true {
                match cursor.peek() {
                  Some(result_tok) => {
                    if result_tok == ")" {
                      break
                    }
                    let token = cursor.next()
                    if token != "i32" {
                      raise RuntimeError("Only i32 result type is supported.")
                    }
                    result_count += 1
                  }
                  None => raise ParseError("Unterminated (result ...) clause.")
                }
              }
              cursor.expect(")")
            }
            "local" => {
              while true {
                match cursor.peek() {
                  Some(local_tok) => {
                    if local_tok == ")" {
                      break
                    }
                    let token = cursor.next()
                    if token.has_prefix("$") {
                      continue
                    }
                    if token != "i32" {
                      raise RuntimeError("Only i32 locals are supported.")
                    }
                    local_count += 1
                  }
                  None => raise ParseError("Unterminated (local ...) clause.")
                }
              }
              cursor.expect(")")
            }
            _ => raise RuntimeError("Unsupported func clause in WAT: \{clause}")
          }
        } else {
          instructions.push(parse_instruction(cursor))
        }
      }
      None => raise ParseError("Unterminated function form in WAT.")
    }
  }

  cursor.expect(")")
  let export_name = match export_name {
    Some(name) => name
    None =>
      raise ParseError("Function must include an (export \"...\") clause.")
  }
  if result_count != 1 {
    raise RuntimeError(
      "Exactly one i32 result is required for exported function.",
    )
  }

  { export_name, param_count, local_count, result_count, instructions }
}

///|
fn parse_instruction(cursor : TokenCursor) -> WatInstr raise ParseRuntimeError {
  let opcode = cursor.next()
  match opcode {
    "local.get" => {
      let index = parse_int_token(cursor.next())
      LocalGet(index)
    }
    "local.set" => {
      let index = parse_int_token(cursor.next())
      LocalSet(index)
    }
    "local.tee" => {
      let index = parse_int_token(cursor.next())
      LocalTee(index)
    }
    "i32.const" => {
      let value = parse_int_token(cursor.next())
      I32Const(value)
    }
    "nop" => Nop
    "drop" => Drop
    "i32.add" => I32Add
    "i32.sub" => I32Sub
    "i32.mul" => I32Mul
    "i32.xor" => I32Xor
    "i32.eq" => I32Eq
    "i32.eqz" => I32Eqz
    _ => raise RuntimeError("Unsupported instruction in WAT: \{opcode}")
  }
}

///|
fn parse_int_token(token : String) -> Int raise ParseRuntimeError {
  @strconv.parse_int(token) catch {
    _ => raise ParseError("Invalid integer literal in WAT: \{token}")
  }
}

///|
fn parse_string_token(token : String) -> String raise ParseRuntimeError {
  if !token.has_prefix("str:") {
    raise ParseError("Expected string literal token.")
  }
  slice_string(token, 4, token.length())
}

///|
fn compile_wat_module(
  functions : Array[WatFunction],
) -> Bytes raise ParseRuntimeError {
  let function_count = functions.length()
  let function_count_leb = encode_u32_leb(function_count)

  let out = @buffer.new()
  out.write_bytes(b"\x00asm\x01\x00\x00\x00")

  let type_payload = @buffer.new()
  type_payload.write_bytes(function_count_leb)
  for function in functions {
    type_payload.write_byte(b'\x60')
    type_payload.write_bytes(encode_u32_leb(function.param_count))
    for _ in 0..<function.param_count {
      type_payload.write_byte(b'\x7F')
    }
    type_payload.write_bytes(encode_u32_leb(function.result_count))
    for _ in 0..<function.result_count {
      type_payload.write_byte(b'\x7F')
    }
  }
  append_section(out, b'\x01', type_payload.to_bytes())

  let function_payload = @buffer.new()
  function_payload.write_bytes(function_count_leb)
  for i in 0..<function_count {
    function_payload.write_bytes(encode_u32_leb(i))
  }
  append_section(out, b'\x03', function_payload.to_bytes())

  let export_payload = @buffer.new()
  export_payload.write_bytes(function_count_leb)
  for i in 0..<function_count {
    let function = functions[i]
    let name_bytes = ascii_string_to_bytes(function.export_name)
    export_payload.write_bytes(encode_u32_leb(name_bytes.length()))
    export_payload.write_bytes(name_bytes)
    export_payload.write_byte(b'\x00')
    export_payload.write_bytes(encode_u32_leb(i))
  }
  append_section(out, b'\x07', export_payload.to_bytes())

  let code_payload = @buffer.new()
  code_payload.write_bytes(function_count_leb)
  for function in functions {
    let body = @buffer.new()
    if function.local_count <= 0 {
      body.write_bytes(encode_u32_leb(0))
    } else {
      body.write_bytes(encode_u32_leb(1))
      body.write_bytes(encode_u32_leb(function.local_count))
      body.write_byte(b'\x7F')
    }
    for instruction in function.instructions {
      write_instruction(body, instruction)
    }
    body.write_byte(b'\x0B')

    let body_bytes = body.to_bytes()
    code_payload.write_bytes(encode_u32_leb(body_bytes.length()))
    code_payload.write_bytes(body_bytes)
  }
  append_section(out, b'\x0A', code_payload.to_bytes())

  out.to_bytes()
}

///|
fn append_section(
  out : @buffer.Buffer,
  section_id : Byte,
  payload : Bytes,
) -> Unit {
  out.write_byte(section_id)
  out.write_bytes(encode_u32_leb(payload.length()))
  out.write_bytes(payload)
}

///|
fn write_instruction(buf : @buffer.Buffer, instruction : WatInstr) -> Unit {
  match instruction {
    LocalGet(index) => {
      buf.write_byte(b'\x20')
      buf.write_bytes(encode_u32_leb(index))
    }
    LocalSet(index) => {
      buf.write_byte(b'\x21')
      buf.write_bytes(encode_u32_leb(index))
    }
    LocalTee(index) => {
      buf.write_byte(b'\x22')
      buf.write_bytes(encode_u32_leb(index))
    }
    I32Const(value) => {
      buf.write_byte(b'\x41')
      buf.write_bytes(encode_i32_leb(value))
    }
    Nop => buf.write_byte(b'\x01')
    Drop => buf.write_byte(b'\x1A')
    I32Add => buf.write_byte(b'\x6A')
    I32Sub => buf.write_byte(b'\x6B')
    I32Mul => buf.write_byte(b'\x6C')
    I32Xor => buf.write_byte(b'\x73')
    I32Eq => buf.write_byte(b'\x46')
    I32Eqz => buf.write_byte(b'\x45')
  }
}

///|
fn ascii_string_to_bytes(value : String) -> Bytes raise ParseRuntimeError {
  let out = @buffer.new(size_hint=value.length())
  for ch in value {
    let code = ch.to_int()
    if code < 0 || code > 0x7F {
      raise RuntimeError("Only ASCII export names are supported.")
    }
    out.write_byte(code.to_byte())
  }
  out.to_bytes()
}

///|
fn TokenCursor::has_next(self : TokenCursor) -> Bool {
  self.index < self.tokens.length()
}

///|
fn TokenCursor::peek(self : TokenCursor) -> String? {
  if self.has_next() {
    Some(self.tokens[self.index])
  } else {
    None
  }
}

///|
fn TokenCursor::next(self : TokenCursor) -> String raise ParseRuntimeError {
  match self.peek() {
    Some(token) => {
      self.index += 1
      token
    }
    None => raise ParseError("Unexpected end of WAT input.")
  }
}

///|
fn TokenCursor::expect(
  self : TokenCursor,
  expected : String,
) -> Unit raise ParseRuntimeError {
  let actual = self.next()
  if actual != expected {
    raise ParseError("Expected `\{expected}` but got `\{actual}`.")
  }
}
