///|
/// A decoded physical signal value.
pub struct DecodedSignal {
  name : String
  raw : UInt
  physical : Double
  unit : String
}

///|
/// A decoded DBC message with the source identifier.
pub struct DecodedMessage {
  id : UInt
  name : String
  signals : Array[DecodedSignal]
}

///|
/// Errors raised by checked DBC runtime operations.
pub suberror DbcRuntimeError {
  InvalidSignalLayout
  PayloadTooShort
  PayloadTooLong
  DuplicateSignal
  MissingSignalValue
  ValueOutOfRange
} derive(Debug)

///|
/// A lookup table for message definitions.
pub struct DbcDatabase {
  messages : Array[Message]
}

///|
/// Create an empty database.
pub fn new_dbc_database() -> DbcDatabase {
  { messages: [] }
}

///|
/// Add a message definition, rejecting duplicate numeric identifiers.
pub fn DbcDatabase::add(
  self : DbcDatabase,
  item : Message,
) -> Unit raise DbcRuntimeError {
  if self.by_id(item.id()) is Some(_) {
    raise DuplicateSignal
  }
  self.messages.push(item)
}

///|
/// Build a database using the existing DBC subset parser.
pub fn parse_dbc_database(input : String) -> DbcDatabase raise DbcError {
  let database = new_dbc_database()
  for item in parse_dbc(input) {
    database.add(item) catch {
      _ => ()
    }
  }
  database
}

///|
/// Return the number of definitions.
pub fn DbcDatabase::length(self : DbcDatabase) -> Int {
  self.messages.length()
}

///|
/// Return all message definitions in source order.
pub fn DbcDatabase::messages(self : DbcDatabase) -> Array[Message] {
  self.messages.copy()
}

///|
/// Find a message by CAN identifier.
pub fn DbcDatabase::by_id(self : DbcDatabase, id : UInt) -> Message? {
  for item in self.messages {
    if item.id() == id {
      return Some(item)
    }
  }
  None
}

///|
/// Find a message by its symbolic name.
pub fn DbcDatabase::by_name(self : DbcDatabase, name : String) -> Message? {
  for item in self.messages {
    if item.name() == name {
      return Some(item)
    }
  }
  None
}

///|
/// Return all numeric message identifiers.
pub fn DbcDatabase::ids(self : DbcDatabase) -> Array[UInt] {
  self.messages.map(item => item.id())
}

///|
/// Return signal definitions in source order.
pub fn Message::signals(self : Message) -> Array[Signal] {
  self.signals.copy()
}

///|
/// Return the number of defined signals.
pub fn Message::signal_count(self : Message) -> Int {
  self.signals.length()
}

///|
/// Validate message size and all signal bit ranges.
pub fn Message::validate(self : Message) -> Bool {
  if self.dlc < 0 || self.dlc > 64 {
    return false
  }
  for item in self.signals {
    if !item.is_valid(self.dlc) {
      return false
    }
  }
  true
}

///|
/// Decode all signals in a payload.
pub fn Message::decode(
  self : Message,
  data : Array[Byte],
) -> DecodedMessage raise DbcRuntimeError {
  if data.length() < self.dlc {
    raise PayloadTooShort
  }
  if !self.validate() {
    raise InvalidSignalLayout
  }
  let decoded : Array[DecodedSignal] = []
  for item in self.signals {
    decoded.push({
      name: item.name(),
      raw: item.decode_raw(data),
      physical: item.decode(data),
      unit: item.unit(),
    })
  }
  { id: self.id, name: self.name, signals: decoded }
}

///|
/// Encode physical signal values into a message payload.
pub fn Message::encode_values(
  self : Message,
  values : Map[String, Double],
  initial? : Array[Byte] = [],
) -> Array[Byte] raise DbcRuntimeError {
  if !self.validate() {
    raise InvalidSignalLayout
  }
  if initial.length() > self.dlc {
    raise PayloadTooLong
  }
  let result = initial.copy()
  while result.length() < self.dlc {
    result.push(0)
  }
  for item in self.signals {
    if !values.contains(item.name()) {
      raise MissingSignalValue
    }
    let physical = values[item.name()]
    if !item.accepts(physical) {
      raise ValueOutOfRange
    }
    let encoded = item.encode(result, physical)
    for index in 0..<encoded.length() {
      result[index] = encoded[index]
    }
  }
  result
}

///|
/// Encode a message definition and values as a CAN frame.
pub fn Message::encode_frame(
  self : Message,
  values : Map[String, Double],
  extended? : Bool = false,
) -> Frame raise DbcRuntimeError {
  let data = self.encode_values(values)
  if self.dlc > 8 {
    fd_frame(self.id, data, extended~) catch {
      _ => raise PayloadTooLong
    }
  } else {
    data_frame(self.id, data, extended~) catch {
      _ => raise PayloadTooLong
    }
  }
}

///|
/// Decode a frame using the message selected by its identifier.
pub fn DbcDatabase::decode_frame(
  self : DbcDatabase,
  frame : Frame,
) -> DecodedMessage? raise DbcRuntimeError {
  match self.by_id(frame.id()) {
    Some(item) => Some(item.decode(frame.data()))
    None => None
  }
}

///|
/// Return the message identifier from a decoded message.
pub fn DecodedMessage::id(self : DecodedMessage) -> UInt {
  self.id
}

///|
/// Return the message name from a decoded message.
pub fn DecodedMessage::name(self : DecodedMessage) -> String {
  self.name
}

///|
/// Return decoded signals.
pub fn DecodedMessage::signals(self : DecodedMessage) -> Array[DecodedSignal] {
  self.signals.copy()
}

///|
/// Find a decoded value by signal name.
pub fn DecodedMessage::find(
  self : DecodedMessage,
  name : String,
) -> DecodedSignal? {
  for item in self.signals {
    if item.name == name {
      return Some(item)
    }
  }
  None
}

///|
pub fn DecodedSignal::name(self : DecodedSignal) -> String {
  self.name
}

///|
pub fn DecodedSignal::raw(self : DecodedSignal) -> UInt {
  self.raw
}

///|
pub fn DecodedSignal::physical(self : DecodedSignal) -> Double {
  self.physical
}

///|
pub fn DecodedSignal::unit(self : DecodedSignal) -> String {
  self.unit
}

///|
/// Return the configured signal bit size.
pub fn Signal::size(self : Signal) -> Int {
  self.size
}

///|
/// Return whether this signal uses signed two's-complement values.
pub fn Signal::is_signed(self : Signal) -> Bool {
  self.signed
}

///|
pub fn Signal::factor(self : Signal) -> Double {
  self.factor
}

///|
pub fn Signal::offset(self : Signal) -> Double {
  self.offset
}

///|
pub fn Signal::minimum(self : Signal) -> Double {
  self.minimum
}

///|
pub fn Signal::maximum(self : Signal) -> Double {
  self.maximum
}

///|
pub fn Signal::unit(self : Signal) -> String {
  self.unit
}

///|
/// Check whether a signal fits inside a payload of `dlc` bytes.
pub fn Signal::is_valid(self : Signal, dlc : Int) -> Bool {
  self.start_bit >= 0 &&
  self.size > 0 &&
  self.size <= 32 &&
  self.start_bit + self.size <= dlc * 8
}

///|
/// Return the largest raw unsigned value representable by this signal.
pub fn Signal::raw_max(self : Signal) -> UInt {
  if self.size >= 32 {
    0xFFFFFFFF
  } else {
    (1 << self.size) - 1
  }
}

///|
/// Decode a signed raw value using the signal width.
pub fn Signal::decode_signed(self : Signal, data : Array[Byte]) -> Int {
  let raw = self.decode_raw(data)
  if !self.signed || self.size == 0 {
    raw.reinterpret_as_int()
  } else if ((raw >> (self.size - 1)) & 1) == 0 {
    raw.reinterpret_as_int()
  } else {
    let mask : UInt = if self.size >= 32 {
      0xFFFFFFFF
    } else {
      (1 << self.size) - 1
    }
    (raw | (0xFFFFFFFF ^ mask)).reinterpret_as_int()
  }
}

///|
/// Decode a physical value while honoring the DBC signedness flag.
pub fn Signal::decode_physical(self : Signal, data : Array[Byte]) -> Double {
  self.decode_signed(data).to_double() * self.factor + self.offset
}

///|
/// Return the signal's inclusive physical range when configured.
pub fn Signal::has_range(self : Signal) -> Bool {
  self.maximum > self.minimum
}

///|
/// Check a physical value against the configured range.
pub fn Signal::accepts(self : Signal, value : Double) -> Bool {
  !self.has_range() || (value >= self.minimum && value <= self.maximum)
}

///|
/// Render a decoded message as a stable diagnostic line.
pub fn DecodedMessage::to_text(self : DecodedMessage) -> String {
  let builder = StringBuilder()
  builder.write_string("0x")
  builder.write_string(self.id.to_string())
  builder.write_string(" ")
  builder.write_string(self.name)
  for item in self.signals {
    builder.write_string(" ")
    builder.write_string(item.name)
    builder.write_string("=")
    builder.write_string(item.physical.to_string())
  }
  builder.to_string()
}
