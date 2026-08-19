///|
/// Payload transformation errors.
pub suberror PayloadError {
  InvalidOffset
  InvalidWidth
  InvalidCounter
  InvalidFrame
} derive(Debug)

///|
/// Byte ordering used by application payload adapters.
pub(all) enum ByteOrder {
  BigEndian
  LittleEndian
}

///|
/// Extract an unsigned integer from a payload.
pub fn payload_uint(
  data : Array[Byte],
  offset : Int,
  width : Int,
  order : ByteOrder,
) -> UInt raise PayloadError {
  if offset < 0 || width <= 0 || width > 4 || offset + width > data.length() {
    raise InvalidWidth
  }
  let mut result : UInt = 0
  match order {
    BigEndian =>
      for index in 0..<width {
        result = (result << 8) | data[offset + index].to_uint()
      }
    LittleEndian =>
      for index in 0..<width {
        result = result | (data[offset + index].to_uint() << (8 * index))
      }
  }
  result
}

///|
/// Insert an unsigned integer into a copied payload.
pub fn payload_set_uint(
  data : Array[Byte],
  offset : Int,
  width : Int,
  value : UInt,
  order : ByteOrder,
) -> Array[Byte] raise PayloadError {
  if offset < 0 || width <= 0 || width > 4 || offset + width > data.length() {
    raise InvalidWidth
  }
  if width < 4 && value >> (width * 8) != 0 {
    raise InvalidWidth
  }
  let result = data.copy()
  match order {
    BigEndian =>
      for index in 0..<width {
        result[offset + index] = (value >> (8 * (width - index - 1))).to_byte()
      }
    LittleEndian =>
      for index in 0..<width {
        result[offset + index] = (value >> (8 * index)).to_byte()
      }
  }
  result
}

///|
/// Return the CRC-8/SAE-J1850 checksum of a payload.
pub fn crc8_sae_j1850(data : Array[Byte]) -> Byte {
  let mut crc : Byte = 0xFF
  for byte in data {
    crc = crc ^ byte
    for _ in 0..<=8 {
      crc = if (crc & 0x80) != 0 { (crc << 1) ^ 0x1D } else { crc << 1 }
    }
  }
  crc ^ 0xFF
}

///|
/// Return the CRC-8/AUTOSAR checksum with configurable initial value.
pub fn crc8_autosar(data : Array[Byte], initial : Byte) -> Byte {
  let mut crc = initial
  for byte in data {
    crc = crc ^ byte
    for _ in 0..<=8 {
      crc = if (crc & 0x80) != 0 { (crc << 1) ^ 0x2F } else { crc << 1 }
    }
  }
  crc
}

///|
/// Insert a rolling counter into a payload nibble.
pub fn set_counter_nibble(
  data : Array[Byte],
  offset : Int,
  counter : Byte,
  high_nibble : Bool,
) -> Array[Byte] raise PayloadError {
  if offset < 0 || offset >= data.length() || counter > 0x0F {
    raise InvalidCounter
  }
  let result = data.copy()
  if high_nibble {
    result[offset] = (result[offset] & 0x0F) | (counter << 4)
  } else {
    result[offset] = (result[offset] & 0xF0) | counter
  }
  result
}

///|
/// Read a rolling counter nibble.
pub fn counter_nibble(
  data : Array[Byte],
  offset : Int,
  high_nibble : Bool,
) -> Byte raise PayloadError {
  if offset < 0 || offset >= data.length() {
    raise InvalidCounter
  }
  if high_nibble {
    data[offset] >> 4
  } else {
    data[offset] & 0x0F
  }
}

///|
/// Verify the expected modulo-16 counter progression.
pub fn counter_is_next(previous : Byte, current : Byte) -> Bool {
  current == ((previous.to_int() + 1) & 0x0F).to_byte()
}

///|
/// Return a payload with bytes reversed in a selected range.
pub fn reverse_payload(
  data : Array[Byte],
  start : Int,
  end : Int,
) -> Array[Byte] raise PayloadError {
  if start < 0 || end < start || end > data.length() {
    raise InvalidOffset
  }
  let result = data.copy()
  let mut left = start
  let mut right = end - 1
  while left < right {
    let temp = result[left]
    result[left] = result[right]
    result[right] = temp
    left += 1
    right -= 1
  }
  result
}

///|
/// Mask a payload byte range without changing its length.
pub fn mask_payload(
  data : Array[Byte],
  offset : Int,
  mask : Byte,
) -> Array[Byte] raise PayloadError {
  if offset < 0 || offset >= data.length() {
    raise InvalidOffset
  }
  let result = data.copy()
  result[offset] = result[offset] & mask
  result
}

///|
/// Rebuild a frame with a defensive payload copy.
pub fn frame_with_data(
  frame : Frame,
  data : Array[Byte],
) -> Frame raise PayloadError {
  if frame.protocol() is CanFd {
    fd_frame(
      frame.id(),
      data,
      extended=frame.is_extended(),
      bitrate_switch=frame.bitrate_switch(),
      error_state_indicator=frame.error_state_indicator(),
    ) catch {
      _ => raise InvalidFrame
    }
  } else if frame.is_data() {
    data_frame(frame.id(), data, extended=frame.is_extended()) catch {
      _ => raise InvalidFrame
    }
  } else {
    raise InvalidFrame
  }
}

///|
/// Rebuild a frame with a different arbitration identifier.
pub fn frame_with_id(frame : Frame, id : UInt) -> Frame raise PayloadError {
  frame_with_data(
    if frame.protocol() is CanFd {
      fd_frame(
        id,
        frame.data(),
        extended=frame.is_extended(),
        bitrate_switch=frame.bitrate_switch(),
        error_state_indicator=frame.error_state_indicator(),
      ) catch {
        _ => raise InvalidFrame
      }
    } else {
      data_frame(id, frame.data(), extended=frame.is_extended()) catch {
        _ => raise InvalidFrame
      }
    },
    frame.data(),
  )
}
