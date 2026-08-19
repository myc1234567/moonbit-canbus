///|
/// A DBC signal description.
pub struct Signal {
  name : String
  start_bit : Int
  size : Int
  little_endian : Bool
  signed : Bool
  factor : Double
  offset : Double
  minimum : Double
  maximum : Double
  unit : String
}

///|
/// Create a signal descriptor.
pub fn signal(
  name : String,
  start_bit : Int,
  size : Int,
  little_endian? : Bool = true,
  signed? : Bool = false,
  factor? : Double = 1.0,
  offset? : Double = 0.0,
  minimum? : Double = 0.0,
  maximum? : Double = 0.0,
  unit? : String = "",
) -> Signal {
  {
    name,
    start_bit,
    size,
    little_endian,
    signed,
    factor,
    offset,
    minimum,
    maximum,
    unit,
  }
}

///|
/// Extract a raw signal value from a payload.
pub fn Signal::decode_raw(self : Signal, data : Array[Byte]) -> UInt {
  let mut value : UInt = 0
  for bit_index in 0..<self.size {
    let absolute = if self.little_endian {
      self.start_bit + bit_index
    } else {
      self.start_bit - bit_index
    }
    let byte_index = absolute / 8
    let offset = absolute % 8
    if byte_index < data.length() &&
      ((data[byte_index].to_uint() >> offset) & 1) == 1 {
      value = value | (1 << bit_index)
    }
  }
  value
}

///|
/// Decode a physical value using factor and offset.
pub fn Signal::decode(self : Signal, data : Array[Byte]) -> Double {
  self.decode_raw(data).to_double() * self.factor + self.offset
}

///|
/// Encode a raw value into a payload copy.
pub fn Signal::encode_raw(
  self : Signal,
  data : Array[Byte],
  value : UInt,
) -> Array[Byte] {
  let result = data.copy()
  let required = (self.start_bit + self.size + 7) / 8
  while result.length() < required {
    result.push(0)
  }
  for bit_index in 0..<self.size {
    let absolute = if self.little_endian {
      self.start_bit + bit_index
    } else {
      self.start_bit - bit_index
    }
    let byte_index = absolute / 8
    let offset = absolute % 8
    let mask = 1 << offset
    if ((value >> bit_index) & 1) == 1 {
      result[byte_index] = result[byte_index] | mask.to_byte()
    } else {
      result[byte_index] = result[byte_index] & (0xFF ^ mask).to_byte()
    }
  }
  result
}

///|
/// Encode a physical value into a payload copy.
pub fn Signal::encode(
  self : Signal,
  data : Array[Byte],
  value : Double,
) -> Array[Byte] {
  let raw = ((value - self.offset) / self.factor).to_int().reinterpret_as_uint()
  self.encode_raw(data, raw)
}

///|
/// A CAN message with named signals.
pub struct Message {
  id : UInt
  name : String
  dlc : Int
  signals : Array[Signal]
}

///|
/// Create a message definition.
pub fn message(id : UInt, name : String, dlc : Int) -> Message {
  { id, name, dlc, signals: [] }
}

///|
/// Add a signal to a message.
pub fn Message::add_signal(self : Message, item : Signal) -> Unit {
  self.signals.push(item)
}

///|
/// Find a signal by name.
pub fn Message::find(self : Message, name : String) -> Signal? {
  for item in self.signals {
    if item.name == name {
      return Some(item)
    }
  }
  None
}

///|
/// Return whether the signal uses Intel/little-endian bit ordering.
pub fn Signal::little_endian(self : Signal) -> Bool {
  self.little_endian
}
