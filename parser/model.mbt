///|
priv struct LebRead {
  value : Int
  next_offset : Int
}

///|
priv struct FuncType {
  param_types : Array[Byte]
  result_types : Array[Byte]
}

///|
priv struct ExportEntry {
  name : String
  kind : Byte
  index : Int
}

///|
priv struct ParsedModule {
  function_types : Array[FuncType]
  function_type_indices : Array[Int]
  function_bodies : Array[Bytes]
  exports : Array[ExportEntry]
}

///|
priv enum WatInstr {
  LocalGet(Int)
  LocalSet(Int)
  LocalTee(Int)
  I32Const(Int)
  Nop
  Drop
  I32Add
  I32Sub
  I32Mul
  I32Xor
  I32Eq
  I32Eqz
}

///|
priv struct WatFunction {
  export_name : String
  param_count : Int
  local_count : Int
  result_count : Int
  instructions : Array[WatInstr]
}

///|
priv struct TokenCursor {
  tokens : Array[String]
  mut index : Int
}
