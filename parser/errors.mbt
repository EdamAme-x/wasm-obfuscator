///|
pub(all) suberror ParseRuntimeError {
  ParseError(String)
  RuntimeError(String)
} derive(Show, Eq)
