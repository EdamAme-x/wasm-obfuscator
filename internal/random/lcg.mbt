///|
pub(all) struct LcgState {
  mut state : UInt
}

///|
pub fn new(seed : Int) -> LcgState {
  let mixed = seed.reinterpret_as_uint() ^ 0x9E3779B9U
  { state: mixed }
}

///|
fn LcgState::next_u32(self : LcgState) -> UInt {
  self.state = self.state * 1664525U + 1013904223U
  self.state
}

///|
pub fn LcgState::next_byte(self : LcgState) -> Byte {
  (self.next_u32() & 0xFFU).to_byte()
}
