///|
/// Errors raised by the complete bit-level wire codec.
pub suberror WireCodecError {
  InvalidEof
  InvalidCrc
  InvalidControl
  InvalidDlc
  InvalidFrameBits
} derive(Debug)

///|
/// Encode identifier, control, data, CRC, stuffing and EOF bits.
pub fn encode_wire(frame : Frame) -> Array[Bool] {
  let writer = new_bit_writer()
  try! writer.write(if frame.is_extended() { 1 } else { 0 }, 1)
  try! writer.write(
    match frame.kind() {
      Data => 0
      Remote => 1
      Error => 2
    },
    2,
  )
  try! writer.write(if frame.protocol() is CanFd { 1 } else { 0 }, 1)
  try! writer.write(if frame.bitrate_switch() { 1 } else { 0 }, 1)
  try! writer.write(if frame.error_state_indicator() { 1 } else { 0 }, 1)
  try! writer.write(frame.id(), 29)
  try! writer.write(frame.dlc().to_uint(), 4)
  for byte in frame.data() {
    try! writer.write(byte.to_uint(), 8)
  }
  let body = writer.finish()
  let crc = match frame.protocol() {
    Can20 => crc15(body)
    CanFd => if frame.data().length() <= 16 { crc17(body) } else { crc21(body) }
  }
  let crc_width = match frame.protocol() {
    Can20 => 15
    CanFd => if frame.data().length() <= 16 { 17 } else { 21 }
  }
  let with_crc = body + bits_of(crc, crc_width)
  stuff(with_crc) + Array::make(7, true)
}

///|
/// Return the stuffed frame length, including SOF-free EOF bits.
pub fn encoded_wire_length(frame : Frame) -> Int {
  encode_wire(frame).length()
}

///|
/// Decode a classic CAN wire sequence produced by `encode_wire`.
pub fn decode_wire_can20(bits : Array[Bool]) -> Frame raise WireCodecError {
  decode_wire(bits, Can20)
}

///|
/// Decode a CAN-FD wire sequence produced by `encode_wire`.
pub fn decode_wire_canfd(bits : Array[Bool]) -> Frame raise WireCodecError {
  decode_wire(bits, CanFd)
}

///|
/// Check CRC and parse a normalized frame from a complete wire sequence.
fn decode_wire(
  bits : Array[Bool],
  protocol : Protocol,
) -> Frame raise WireCodecError {
  if bits.length() < 7 {
    raise InvalidFrameBits
  }
  for bit in bits[bits.length() - 7:] {
    if !bit {
      raise InvalidEof
    }
  }
  let stuffed = bits[0:bits.length() - 7].to_owned()
  let raw = destuff(stuffed) catch { _ => raise InvalidControl }
  let crc_width = match protocol {
    Can20 => 15
    CanFd => if raw.length() > 16 * 8 + 64 { 21 } else { 17 }
  }
  if raw.length() <= crc_width {
    raise InvalidFrameBits
  }
  let body = raw[0:raw.length() - crc_width].to_owned()
  let received = bits_to_uint(raw[raw.length() - crc_width:].to_owned())
  let expected = match protocol {
    Can20 => crc15(body)
    CanFd =>
      if body.length() <= 16 * 8 + 64 {
        crc17(body)
      } else {
        crc21(body)
      }
  }
  if received != expected {
    raise InvalidCrc
  }
  parse_wire_body(body, protocol)
}

///|
fn parse_wire_body(
  body : Array[Bool],
  protocol : Protocol,
) -> Frame raise WireCodecError {
  let reader = new_bit_reader(body)
  let extended = reader.read_bit() catch { _ => raise InvalidFrameBits }
  let kind_code = reader.read(2) catch { _ => raise InvalidFrameBits }
  let is_fd = reader.read_bit() catch { _ => raise InvalidFrameBits }
  let bitrate_switch = reader.read_bit() catch { _ => raise InvalidFrameBits }
  let error_state_indicator = reader.read_bit() catch {
    _ => raise InvalidFrameBits
  }
  if (protocol is CanFd) != is_fd {
    raise InvalidControl
  }
  let id = reader.read(29) catch { _ => raise InvalidFrameBits }
  let dlc = reader.read(4) catch { _ => raise InvalidDlc }
  let data_length = if protocol is Can20 {
    if dlc > 8 {
      raise InvalidDlc
    } else {
      dlc.reinterpret_as_int()
    }
  } else {
    let remaining_bytes = reader.remaining() / 8
    if dlc <= 8 {
      dlc.reinterpret_as_int()
    } else {
      remaining_bytes
    }
  }
  if reader.remaining() < data_length * 8 {
    raise InvalidFrameBits
  }
  let data : Array[Byte] = []
  for _ in 0..<data_length {
    let value = reader.read(8) catch { _ => raise InvalidFrameBits }
    data.push(value.to_byte())
  }
  if kind_code == 1 {
    if !data.is_empty() {
      raise InvalidControl
    }
    remote_frame(id, extended~) catch {
      _ => raise InvalidFrameBits
    }
  } else if kind_code == 2 {
    error_frame(if data.is_empty() { 0 } else { data[0] })
  } else if protocol is CanFd {
    fd_frame(id, data, extended~, bitrate_switch~, error_state_indicator~) catch {
      _ => raise InvalidFrameBits
    }
  } else {
    data_frame(id, data, extended~) catch {
      _ => raise InvalidFrameBits
    }
  }
}

///|
fn bits_to_uint(bits : Array[Bool]) -> UInt {
  let mut result : UInt = 0
  for bit in bits {
    result = (result << 1) | (if bit { 1 } else { 0 })
  }
  result
}

///|
/// Verify that a frame's wire encoding can be decoded without loss.
pub fn wire_round_trip(frame : Frame) -> Bool {
  let bits = encode_wire(frame)
  let decoded = match frame.protocol() {
    Can20 => decode_wire_can20(bits) catch { _ => return false }
    CanFd => decode_wire_canfd(bits) catch { _ => return false }
  }
  frame_equal(frame, decoded)
}
