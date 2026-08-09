///|
/// A decoded 29-bit J1939 identifier.
pub struct J1939Id {
  priority : Byte
  data_page : Bool
  pdu_format : Byte
  pdu_specific : Byte
  source_address : Byte
}

///|
/// Create a J1939 identifier from its wire fields.
pub fn j1939_id(
  priority : Byte,
  data_page : Bool,
  pdu_format : Byte,
  pdu_specific : Byte,
  source_address : Byte,
) -> J1939Id {
  { priority, data_page, pdu_format, pdu_specific, source_address }
}

///|
/// Decode the fields of a J1939 identifier.
pub fn decode_j1939(id : UInt) -> J1939Id {
  {
    priority: ((id >> 26) & 7).to_byte(),
    data_page: ((id >> 24) & 1) == 1,
    pdu_format: ((id >> 16) & 0xFF).to_byte(),
    pdu_specific: ((id >> 8) & 0xFF).to_byte(),
    source_address: (id & 0xFF).to_byte(),
  }
}

///|
/// Encode a J1939 identifier from its fields.
pub fn encode_j1939(value : J1939Id) -> UInt {
  (value.priority.to_uint() << 26) |
  ((if value.data_page { 1 } else { 0 }) << 24) |
  (value.pdu_format.to_uint() << 16) |
  (value.pdu_specific.to_uint() << 8) |
  value.source_address.to_uint()
}

///|
/// Return the PGN, omitting destination address for PDU1 messages.
pub fn J1939Id::pgn(self : J1939Id) -> UInt {
  if self.pdu_format < 240 {
    (self.data_page.to_int().reinterpret_as_uint() << 16) |
    (self.pdu_format.to_uint() << 8)
  } else {
    (self.data_page.to_int().reinterpret_as_uint() << 16) |
    (self.pdu_format.to_uint() << 8) |
    self.pdu_specific.to_uint()
  }
}

///|
/// The source address of a J1939 message.
pub fn J1939Id::source(self : J1939Id) -> Byte {
  self.source_address
}

///|
/// A J1939 parameter group entry.
pub struct Pgn {
  number : UInt
  name : String
  data_length : Int
}

///|
/// Describe a PGN for higher-level applications.
pub fn pgn(number : UInt, name : String, data_length : Int) -> Pgn {
  { number, name, data_length }
}

///|
/// Return the PGN number.
pub fn Pgn::number(self : Pgn) -> UInt {
  self.number
}

///|
/// Return the PGN label.
pub fn Pgn::name(self : Pgn) -> String {
  self.name
}
