///|
/// Errors raised by the bit-level reader and writer.
pub suberror BitError {
  InvalidWidth
  InvalidValue
  OutOfBounds
} derive(Debug)

///|
/// A growable most-significant-bit-first writer.
pub struct BitWriter {
  bits : Array[Bool]
}

///|
/// Create an empty bit writer.
pub fn new_bit_writer() -> BitWriter {
  { bits: [] }
}

///|
/// Return the number of bits currently written.
pub fn BitWriter::length(self : BitWriter) -> Int {
  self.bits.length()
}

///|
/// Append one bit.
pub fn BitWriter::write_bit(self : BitWriter, bit : Bool) -> Unit {
  self.bits.push(bit)
}

///|
/// Append an unsigned value using exactly `width` high-to-low bits.
pub fn BitWriter::write(
  self : BitWriter,
  value : UInt,
  width : Int,
) -> Unit raise BitError {
  if width < 0 || width > 32 {
    raise InvalidWidth
  }
  if width < 32 && value >> width != 0 {
    raise InvalidValue
  }
  for index in 0..<width {
    self.bits.push(((value >> (width - index - 1)) & 1) == 1)
  }
}

///|
/// Append a signed two's-complement value.
pub fn BitWriter::write_signed(
  self : BitWriter,
  value : Int,
  width : Int,
) -> Unit raise BitError {
  if width <= 0 || width > 31 {
    raise InvalidWidth
  }
  let minimum = -(1 << (width - 1))
  let maximum = (1 << (width - 1)) - 1
  if value < minimum || value > maximum {
    raise InvalidValue
  }
  let encoded = value.reinterpret_as_uint() & ((1 << width) - 1)
  self.write(encoded, width)
}

///|
/// Add zero padding until the writer reaches a byte boundary.
pub fn BitWriter::align_byte(self : BitWriter) -> Unit {
  let remainder = self.bits.length() % 8
  if remainder != 0 {
    for _ in 0..<(8 - remainder) {
      self.bits.push(false)
    }
  }
}

///|
/// Return a defensive copy of the written bits.
pub fn BitWriter::finish(self : BitWriter) -> Array[Bool] {
  self.bits.copy()
}

///|
/// Return the written bits packed into bytes, padding the final byte with 0.
pub fn BitWriter::to_bytes(self : BitWriter) -> Array[Byte] {
  bits_to_bytes(self.bits)
}

///|
/// A sequential most-significant-bit-first reader.
pub struct BitReader {
  bits : Array[Bool]
  mut position : Int
}

///|
/// Create a reader over a defensive copy of the input bits.
pub fn new_bit_reader(bits : Array[Bool]) -> BitReader {
  { bits: bits.copy(), position: 0 }
}

///|
/// Create a reader directly from packed bytes.
pub fn bit_reader_from_bytes(bytes : Array[Byte]) -> BitReader {
  new_bit_reader(bytes_to_bits(bytes))
}

///|
/// Return the current read offset.
pub fn BitReader::position(self : BitReader) -> Int {
  self.position
}

///|
/// Return the number of unread bits.
pub fn BitReader::remaining(self : BitReader) -> Int {
  self.bits.length() - self.position
}

///|
/// Read one bit.
pub fn BitReader::read_bit(self : BitReader) -> Bool raise BitError {
  if self.position >= self.bits.length() {
    raise OutOfBounds
  }
  let bit = self.bits[self.position]
  self.position += 1
  bit
}

///|
/// Read an unsigned value of exactly `width` bits.
pub fn BitReader::read(self : BitReader, width : Int) -> UInt raise BitError {
  if width < 0 || width > 32 {
    raise InvalidWidth
  }
  if self.remaining() < width {
    raise OutOfBounds
  }
  let mut value : UInt = 0
  for _ in 0..<width {
    value = (value << 1) | (if self.read_bit() { 1 } else { 0 })
  }
  value
}

///|
/// Read a signed two's-complement value of up to 31 bits.
pub fn BitReader::read_signed(
  self : BitReader,
  width : Int,
) -> Int raise BitError {
  if width <= 0 || width > 31 {
    raise InvalidWidth
  }
  let raw = self.read(width)
  if ((raw >> (width - 1)) & 1) == 0 {
    raw.reinterpret_as_int()
  } else {
    let sign_mask : UInt = 0xFFFFFFFF ^ ((1 << width) - 1)
    (raw | sign_mask).reinterpret_as_int()
  }
}

///|
/// Skip a number of bits.
pub fn BitReader::skip(self : BitReader, width : Int) -> Unit raise BitError {
  if width < 0 || self.remaining() < width {
    raise OutOfBounds
  }
  self.position += width
}

///|
/// Inspect a bit without advancing the reader.
pub fn BitReader::peek(self : BitReader, width : Int) -> UInt raise BitError {
  let saved = self.position
  let value = self.read(width)
  self.position = saved
  value
}

///|
/// Convert packed bytes to high-to-low bits.
pub fn bytes_to_bits(bytes : Array[Byte]) -> Array[Bool] {
  let result : Array[Bool] = []
  for byte in bytes {
    for index in 0..<8 {
      result.push(((byte.to_uint() >> (7 - index)) & 1) == 1)
    }
  }
  result
}

///|
/// Convert bits to packed bytes. The last byte is zero padded.
pub fn bits_to_bytes(bits : Array[Bool]) -> Array[Byte] {
  if bits.is_empty() {
    return []
  }
  let byte_count = (bits.length() + 7) / 8
  let result : Array[Byte] = Array::make(byte_count, 0)
  for index in 0..<bits.length() {
    if bits[index] {
      let byte_index = index / 8
      let offset = 7 - index % 8
      let mask : Byte = 1 << offset
      result[byte_index] = result[byte_index] | mask
    }
  }
  result
}

///|
/// Return the bit at an absolute offset, or `None` when outside the array.
pub fn bit_at(bits : Array[Bool], position : Int) -> Bool? {
  bits.get(position)
}

///|
/// Set a bit in a defensive copy. Out-of-range positions are ignored.
pub fn set_bit(bits : Array[Bool], position : Int, value : Bool) -> Array[Bool] {
  let result = bits.copy()
  if position >= 0 && position < result.length() {
    result[position] = value
  }
  result
}

///|
/// Return a string made of `0` and `1` for diagnostics and golden tests.
pub fn bits_to_string(bits : Array[Bool]) -> String {
  let builder = StringBuilder()
  for bit in bits {
    builder.write_string(if bit { "1" } else { "0" })
  }
  builder.to_string()
}
