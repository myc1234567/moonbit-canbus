///|
/// CRC-15 used by the classical CAN frame format.
pub fn crc15(bits : Array[Bool]) -> UInt {
  let mut crc : UInt = 0
  for bit in bits {
    let top = ((crc >> 14) & 1) == 1
    let input = top != bit
    let next = (crc << 1) & 0x7FFF
    crc = if input { next ^ 0x4599 } else { next }
  }
  crc
}

///|
/// CRC-17 used by CAN-FD frames with a payload up to 16 bytes.
pub fn crc17(bits : Array[Bool]) -> UInt {
  crc_width(bits, 0x1685B, 17)
}

///|
/// CRC-21 used by CAN-FD frames with a payload above 16 bytes.
pub fn crc21(bits : Array[Bool]) -> UInt {
  crc_width(bits, 0x102899, 21)
}

///|
fn crc_width(bits : Array[Bool], polynomial : UInt, width : Int) -> UInt {
  let mut crc : UInt = 0
  let mask : UInt = (1 << width) - 1
  for bit in bits {
    let top = ((crc >> (width - 1)) & 1) == 1
    let next = (crc << 1) & mask
    crc = if top != bit { next ^ polynomial } else { next }
  }
  crc
}

///|
/// Convert an integer to most-significant-bit-first bits.
pub fn bits_of(value : UInt, width : Int) -> Array[Bool] {
  let result = Array::make(width, false)
  for i in 0..<width {
    result[i] = ((value >> (width - i - 1)) & 1) == 1
  }
  result
}

///|
/// Append a value as most-significant-bit-first bits.
pub fn append_bits(target : Array[Bool], value : UInt, width : Int) -> Unit {
  for bit in bits_of(value, width) {
    target.push(bit)
  }
}
