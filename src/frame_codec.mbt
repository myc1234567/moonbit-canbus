///|
/// Errors raised by the portable frame codec.
pub suberror FrameCodecError {
  UnsupportedVersion
  Truncated
  InvalidFlags
  InvalidPayloadLength
  InvalidHex
} derive(Debug)

///|
/// A stable binary representation for trace files and test fixtures.
///
/// The format is: version, flags, four-byte identifier, payload length, data.
/// All multi-byte values are big-endian so the format is identical on every
/// MoonBit backend.
pub fn encode_frame(frame : Frame) -> Array[Byte] {
  let flags : Byte = (if frame.is_extended() { 1 } else { 0 }) |
    (if frame.protocol() is CanFd { 2 } else { 0 }) |
    (match frame.kind() {
      Data => 0
      Remote => 4
      Error => 8
    }) |
    (if frame.bitrate_switch() { 16 } else { 0 }) |
    (if frame.error_state_indicator() { 32 } else { 0 })
  let id = frame.id()
  [
    1,
    flags,
    (id >> 24).to_byte(),
    (id >> 16).to_byte(),
    (id >> 8).to_byte(),
    id.to_byte(),
    frame.data().length().to_byte(),
  ] +
  frame.data()
}

///|
/// Decode one frame from the stable binary representation.
pub fn decode_frame(bytes : Array[Byte]) -> Frame raise FrameCodecError {
  if bytes.length() < 7 {
    raise Truncated
  }
  if bytes[0] != 1 {
    raise UnsupportedVersion
  }
  let flags = bytes[1].to_int()
  if (flags & 0xC0) != 0 {
    raise InvalidFlags
  }
  let extended = (flags & 1) != 0
  let fd = (flags & 2) != 0
  let kind_code = flags & 12
  let kind = if kind_code == 0 {
    Data
  } else if kind_code == 4 {
    Remote
  } else if kind_code == 8 {
    Error
  } else {
    raise InvalidFlags
  }
  let id : UInt = (bytes[2].to_uint() << 24) |
    (bytes[3].to_uint() << 16) |
    (bytes[4].to_uint() << 8) |
    bytes[5].to_uint()
  let length = bytes[6].to_int()
  if bytes.length() != 7 + length {
    raise InvalidPayloadLength
  }
  if kind is Remote && length != 0 {
    raise InvalidPayloadLength
  }
  if fd && kind_code != 0 {
    raise InvalidFlags
  }
  let data = bytes[7:].to_owned()
  if fd {
    fd_frame(
      id,
      data,
      extended~,
      bitrate_switch=(flags & 16) != 0,
      error_state_indicator=(flags & 32) != 0,
    ) catch {
      _ => raise InvalidPayloadLength
    }
  } else if kind is Data {
    data_frame(id, data, extended~) catch {
      _ => raise InvalidPayloadLength
    }
  } else if kind is Remote {
    remote_frame(id, extended~) catch {
      _ => raise InvalidPayloadLength
    }
  } else {
    if id != 0 || length != 1 {
      raise InvalidFlags
    }
    error_frame(data[0])
  }
}

///|
/// Encode a frame as lowercase hexadecimal bytes.
pub fn frame_to_hex(frame : Frame) -> String {
  let builder = StringBuilder()
  for byte in encode_frame(frame) {
    builder.write_string(hex_digit((byte.to_int() >> 4) & 15))
    builder.write_string(hex_digit(byte.to_int() & 15))
  }
  builder.to_string()
}

///|
/// Decode a hexadecimal frame representation.
pub fn frame_from_hex(text : String) -> Frame raise FrameCodecError {
  if text.length() % 2 != 0 {
    raise InvalidHex
  }
  let bytes : Array[Byte] = []
  for index in 0..<(text.length() / 2) {
    let high = hex_value(text[index * 2])
    let low = hex_value(text[index * 2 + 1])
    match (high, low) {
      (Some(a), Some(b)) => bytes.push(((a << 4) | b).to_byte())
      _ => raise InvalidHex
    }
  }
  decode_frame(bytes)
}

///|
/// Return a compact human-readable frame summary.
pub fn frame_summary(frame : Frame) -> String {
  let kind = match frame.kind() {
    Data => "data"
    Remote => "remote"
    Error => "error"
  }
  let protocol = match frame.protocol() {
    Can20 => "can20"
    CanFd => "canfd"
  }
  "\{protocol} \{kind} id=0x\{frame.id().to_string()} len=\{frame.data().length()}"
}

///|
/// Compare frames in the order used by deterministic arbitration.
pub fn compare_frames(left : Frame, right : Frame) -> Int {
  if left.id() < right.id() {
    -1
  } else if left.id() > right.id() {
    1
  } else if left.is_extended() && !right.is_extended() {
    1
  } else if !left.is_extended() && right.is_extended() {
    -1
  } else {
    0
  }
}

///|
/// Compare frame payloads and all control flags.
pub fn frame_equal(left : Frame, right : Frame) -> Bool {
  left.id() == right.id() &&
  left.is_extended() == right.is_extended() &&
  same_kind(left.kind(), right.kind()) &&
  same_protocol(left.protocol(), right.protocol()) &&
  left.bitrate_switch() == right.bitrate_switch() &&
  left.error_state_indicator() == right.error_state_indicator() &&
  left.data() == right.data()
}

///|
/// Return the number of encoded frame bytes, including the codec header.
pub fn frame_encoded_size(frame : Frame) -> Int {
  7 + frame.data().length()
}

///|
/// Return the CRC for the unstuffed arbitration/control/data sequence.
pub fn frame_crc(frame : Frame) -> UInt {
  let bits = encode_bits(frame)
  match frame.protocol() {
    Can20 => crc15(bits)
    CanFd => if frame.data().length() <= 16 { crc17(bits) } else { crc21(bits) }
  }
}

///|
/// Return the approximate wire bit count before inter-frame spacing.
pub fn frame_wire_bits(frame : Frame) -> Int {
  let base = if frame.is_extended() { 29 } else { 11 }
  let control = if frame.protocol() is CanFd { 11 } else { 6 }
  let payload = frame.data().length() * 8
  base +
  control +
  payload +
  (match frame.protocol() {
    Can20 => 15
    CanFd => if frame.data().length() <= 16 { 17 } else { 21 }
  }) +
  13
}

///|
/// Return a hexadecimal nibble.
fn hex_digit(value : Int) -> String {
  match value {
    0 => "0"
    1 => "1"
    2 => "2"
    3 => "3"
    4 => "4"
    5 => "5"
    6 => "6"
    7 => "7"
    8 => "8"
    9 => "9"
    10 => "a"
    11 => "b"
    12 => "c"
    13 => "d"
    14 => "e"
    _ => "f"
  }
}

///|
/// Decode one UTF-16 code unit containing an ASCII hexadecimal digit.
fn hex_value(value : UInt16) -> Int? {
  if value >= '0' && value <= '9' {
    Some(value.to_int() - '0'.to_int())
  } else if value >= 'a' && value <= 'f' {
    Some(value.to_int() - 'a'.to_int() + 10)
  } else if value >= 'A' && value <= 'F' {
    Some(value.to_int() - 'A'.to_int() + 10)
  } else {
    None
  }
}

///|
fn same_kind(left : FrameKind, right : FrameKind) -> Bool {
  match (left, right) {
    (Data, Data) => true
    (Remote, Remote) => true
    (Error, Error) => true
    (_, _) => false
  }
}

///|
fn same_protocol(left : Protocol, right : Protocol) -> Bool {
  match (left, right) {
    (Can20, Can20) => true
    (CanFd, CanFd) => true
    (_, _) => false
  }
}
