///|
/// Errors raised by J1939 identifier and transport helpers.
pub suberror J1939Error {
  InvalidPriority
  InvalidPgn
  InvalidAddress
  InvalidPayloadLength
  InvalidSequence
  TransferTooLarge
} derive(Debug)

///|
/// Validate a J1939 identifier's fields.
pub fn validate_j1939(value : J1939Id) -> Unit raise J1939Error {
  if value.priority > 7 {
    raise InvalidPriority
  }
  if value.pdu_format == 0 {
    raise InvalidPgn
  }
}

///|
pub fn J1939Id::priority(self : J1939Id) -> Byte {
  self.priority
}

///|
pub fn J1939Id::data_page(self : J1939Id) -> Bool {
  self.data_page
}

///|
pub fn J1939Id::pdu_format(self : J1939Id) -> Byte {
  self.pdu_format
}

///|
pub fn J1939Id::pdu_specific(self : J1939Id) -> Byte {
  self.pdu_specific
}

///|
pub fn J1939Id::destination(self : J1939Id) -> Byte? {
  if self.pdu_format < 240 {
    Some(self.pdu_specific)
  } else {
    None
  }
}

///|
/// A J1939 application payload with its decoded identifier.
pub struct J1939Message {
  identifier : J1939Id
  payload : Array[Byte]
}

///|
pub fn j1939_message(
  identifier : J1939Id,
  payload : Array[Byte],
) -> J1939Message raise J1939Error {
  validate_j1939(identifier)
  if payload.length() > 8 {
    raise InvalidPayloadLength
  }
  { identifier, payload: payload.copy() }
}

///|
pub fn J1939Message::identifier(self : J1939Message) -> J1939Id {
  self.identifier
}

///|
pub fn J1939Message::payload(self : J1939Message) -> Array[Byte] {
  self.payload.copy()
}

///|
/// Create a data frame from a J1939 message.
pub fn J1939Message::to_frame(self : J1939Message) -> Frame raise FrameError {
  data_frame(encode_j1939(self.identifier), self.payload, extended=true)
}

///|
/// Decode an extended CAN data frame as a J1939 message.
pub fn decode_j1939_frame(frame : Frame) -> J1939Message? raise J1939Error {
  if !frame.is_extended() || !frame.is_data() {
    return None
  }
  let identifier = decode_j1939(frame.id())
  Some(j1939_message(identifier, frame.data()))
}

///|
/// Return the numeric destination address, or broadcast for PDU2 messages.
pub fn j1939_destination(identifier : J1939Id) -> Byte {
  match identifier.destination() {
    Some(value) => value
    None => 0xFF
  }
}

///|
/// Test whether a J1939 identifier belongs to a PGN.
pub fn j1939_matches_pgn(identifier : J1939Id, pgn : UInt) -> Bool {
  identifier.pgn() == pgn
}

///|
/// Return a priority-adjusted arbitration identifier.
pub fn j1939_with_priority(
  identifier : J1939Id,
  priority : Byte,
) -> J1939Id raise J1939Error {
  if priority > 7 {
    raise InvalidPriority
  }
  {
    priority,
    data_page: identifier.data_page,
    pdu_format: identifier.pdu_format,
    pdu_specific: identifier.pdu_specific,
    source_address: identifier.source_address,
  }
}

///|
/// Return a source-address-adjusted identifier.
pub fn j1939_with_source(
  identifier : J1939Id,
  source : Byte,
) -> J1939Id raise J1939Error {
  if source > 0xFF {
    raise InvalidAddress
  }
  {
    priority: identifier.priority,
    data_page: identifier.data_page,
    pdu_format: identifier.pdu_format,
    pdu_specific: identifier.pdu_specific,
    source_address: source,
  }
}

///|
/// Build a J1939 BAM transport-protocol announcement.
pub fn j1939_bam(
  pgn : UInt,
  payload : Array[Byte],
) -> Array[Array[Byte]] raise J1939Error {
  if pgn > 0x3FFFF {
    raise InvalidPgn
  }
  if payload.is_empty() || payload.length() > 1785 {
    raise TransferTooLarge
  }
  let packet_count = (payload.length() + 6) / 7
  let announcement : Array[Byte] = [
    0x20,
    payload.length().to_byte(),
    (payload.length() >> 8).to_byte(),
    packet_count.to_byte(),
    0xFF,
    pgn.to_byte(),
    (pgn >> 8).to_byte(),
    (pgn >> 16).to_byte(),
  ]
  let result : Array[Array[Byte]] = [announcement]
  let mut offset = 0
  for sequence in 1..<=packet_count {
    let count = if payload.length() - offset > 7 {
      7
    } else {
      payload.length() - offset
    }
    let packet = [sequence.to_byte()] +
      payload[offset:offset + count].to_owned()
    result.push(packet + Array::make(8 - packet.length(), 0xFF))
    offset += count
  }
  result
}

///|
/// Parse a BAM announcement as `(length, packet_count, pgn)`.
pub fn j1939_parse_bam(announcement : Array[Byte]) -> (Int, Int, UInt)? {
  if announcement.length() < 8 || announcement[0] != 0x20 {
    return None
  }
  let length = announcement[1].to_int() | (announcement[2].to_int() << 8)
  let count = announcement[3].to_int()
  let pgn = announcement[5].to_uint() |
    (announcement[6].to_uint() << 8) |
    (announcement[7].to_uint() << 16)
  Some((length, count, pgn))
}

///|
/// Reassemble BAM data packets after validating their sequence numbers.
pub fn j1939_reassemble_bam(
  packets : Array[Array[Byte]],
  total_length : Int,
) -> Array[Byte] raise J1939Error {
  if total_length <= 0 || total_length > 1785 {
    raise TransferTooLarge
  }
  let result : Array[Byte] = []
  let mut expected = 1
  for packet in packets {
    if packet.is_empty() || packet[0].to_int() != expected {
      raise InvalidSequence
    }
    for byte in packet[1:] {
      if result.length() < total_length {
        result.push(byte)
      }
    }
    expected += 1
  }
  if result.length() != total_length {
    raise InvalidPayloadLength
  }
  result
}

///|
/// Return the standard J1939 priority ordering for messages.
pub fn sort_j1939(messages : Array[J1939Message]) -> Array[J1939Message] {
  let result = messages.copy()
  result.sort_by((left, right) => {
    let left_id = encode_j1939(left.identifier)
    let right_id = encode_j1939(right.identifier)
    if left_id < right_id {
      -1
    } else if left_id > right_id {
      1
    } else {
      0
    }
  })
  result
}
