///|
/// CANopen PDO mapping errors.
pub suberror PdoError {
  InvalidMapping
  TooManyEntries
  ValueTooLarge
  PayloadOverflow
} derive(Debug)

///|
/// One object-dictionary entry mapped into a PDO.
pub struct PdoMapEntry {
  index : UInt
  sub_index : Byte
  bit_offset : Int
  bit_length : Int
}

///|
/// A bit-packed PDO mapping.
pub struct PdoMapping {
  entries : Array[PdoMapEntry]
  payload_bytes : Int
}

///|
/// A decoded mapped value.
pub struct PdoValue {
  index : UInt
  sub_index : Byte
  value : UInt
}

///|
pub fn new_pdo_mapping(payload_bytes? : Int = 8) -> PdoMapping raise PdoError {
  if payload_bytes <= 0 || payload_bytes > 8 {
    raise PayloadOverflow
  }
  { entries: [], payload_bytes }
}

///|
/// Add a mapping entry at the next available bit offset.
pub fn PdoMapping::add(
  self : PdoMapping,
  index : UInt,
  sub_index : Byte,
  bit_length : Int,
) -> Unit raise PdoError {
  if self.entries.length() >= 8 {
    raise TooManyEntries
  }
  if index > 0xFFFF || bit_length <= 0 || bit_length > 32 {
    raise InvalidMapping
  }
  let bit_offset = self.entries.fold(init=0, (offset, item) => {
    offset + item.bit_length
  })
  if bit_offset + bit_length > self.payload_bytes * 8 {
    raise PayloadOverflow
  }
  self.entries.push({ index, sub_index, bit_offset, bit_length })
}

///|
pub fn PdoMapping::length(self : PdoMapping) -> Int {
  self.entries.length()
}

///|
pub fn PdoMapping::payload_bytes(self : PdoMapping) -> Int {
  self.payload_bytes
}

///|
pub fn PdoMapping::entries(self : PdoMapping) -> Array[PdoMapEntry] {
  self.entries.copy()
}

///|
/// Pack values in mapping order into a little-endian bit payload.
pub fn PdoMapping::pack(
  self : PdoMapping,
  values : Array[UInt],
) -> Array[Byte] raise PdoError {
  if values.length() != self.entries.length() {
    raise InvalidMapping
  }
  let writer = new_bit_writer()
  let mut cursor = 0
  for index in 0..<self.entries.length() {
    let entry = self.entries[index]
    if entry.bit_offset != cursor {
      raise InvalidMapping
    }
    let value = values[index]
    if entry.bit_length < 32 && value >> entry.bit_length != 0 {
      raise ValueTooLarge
    }
    writer.write(value, entry.bit_length) catch {
      _ => raise ValueTooLarge
    }
    cursor += entry.bit_length
  }
  let bytes = writer.to_bytes()
  if bytes.length() > self.payload_bytes {
    raise PayloadOverflow
  }
  bytes + Array::make(self.payload_bytes - bytes.length(), 0)
}

///|
/// Unpack all mapped values from a PDO payload.
pub fn PdoMapping::unpack(
  self : PdoMapping,
  data : Array[Byte],
) -> Array[PdoValue] raise PdoError {
  if data.length() < self.payload_bytes {
    raise PayloadOverflow
  }
  let reader = bit_reader_from_bytes(data)
  let result : Array[PdoValue] = []
  for entry in self.entries {
    if entry.bit_length > 32 {
      raise InvalidMapping
    }
    reader.skip(entry.bit_offset - reader.position()) catch {
      _ => raise InvalidMapping
    }
    let value = reader.read(entry.bit_length) catch {
      _ => raise InvalidMapping
    }
    result.push({ index: entry.index, sub_index: entry.sub_index, value })
  }
  result
}

///|
pub fn PdoMapEntry::index(self : PdoMapEntry) -> UInt {
  self.index
}

///|
pub fn PdoMapEntry::sub_index(self : PdoMapEntry) -> Byte {
  self.sub_index
}

///|
pub fn PdoMapEntry::bit_offset(self : PdoMapEntry) -> Int {
  self.bit_offset
}

///|
pub fn PdoMapEntry::bit_length(self : PdoMapEntry) -> Int {
  self.bit_length
}

///|
pub fn PdoValue::index(self : PdoValue) -> UInt {
  self.index
}

///|
pub fn PdoValue::sub_index(self : PdoValue) -> Byte {
  self.sub_index
}

///|
pub fn PdoValue::value(self : PdoValue) -> UInt {
  self.value
}

///|
/// Build a PDO frame with the standard 11-bit COB-ID.
pub fn pdo_frame(
  node_id : Byte,
  transmit_number : Byte,
  data : Array[Byte],
) -> Frame raise PdoError {
  if node_id == 0 || node_id > 127 || transmit_number < 1 || transmit_number > 4 {
    raise InvalidMapping
  }
  let base = 0x180 + (transmit_number.to_int() - 1) * 0x100
  data_frame((base + node_id.to_int()).reinterpret_as_uint(), data) catch {
    _ => raise PayloadOverflow
  }
}
