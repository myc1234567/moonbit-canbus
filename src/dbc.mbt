///|
/// A small, dependency-free DBC reader for message and signal definitions.
pub suberror DbcError {
  InvalidMessageLine(String)
  InvalidSignalLine(String)
  InvalidNumber(String)
}

///|
/// Parse the message/signal subset commonly used by simulation tools.
pub fn parse_dbc(input : String) -> Array[Message] raise DbcError {
  let messages : Array[Message] = []
  let mut current : Message? = None
  for raw in input.split("\n") {
    let line = raw.trim()
    if line.has_prefix("BO_ ") {
      let fields = split_words(line)
      if fields.length() < 4 {
        raise DbcError::InvalidMessageLine(line.to_owned())
      }
      let id = parse_uint(fields[1])
      let name = first_part(fields[2], ":")
      let dlc = parse_int(fields[3])
      let next = message(id, name, dlc)
      match current {
        Some(previous) => messages.push(previous)
        None => ()
      }
      current = Some(next)
    } else if line.has_prefix("SG_ ") {
      let message = match current {
        Some(value) => value
        None => raise DbcError::InvalidSignalLine(line.to_owned())
      }
      let fields = split_words(line)
      if fields.length() < 4 {
        raise DbcError::InvalidSignalLine(line.to_owned())
      }
      let name = fields[1]
      let layout = split_array(fields[3], "|")
      if layout.length() != 2 {
        raise DbcError::InvalidSignalLine(line.to_owned())
      }
      let start_bit = parse_int(layout[0])
      let size_and_endian = split_array(layout[1], "@")
      let size = parse_int(size_and_endian[0])
      let endian_sign = if size_and_endian.length() > 1 {
        size_and_endian[1]
      } else {
        "1+"
      }
      let little_endian = endian_sign.has_prefix("1")
      let signed = endian_sign.has_suffix("-")
      message.add_signal(signal(name, start_bit, size, little_endian~, signed~))
    }
  }
  match current {
    Some(last) => messages.push(last)
    None => ()
  }
  messages
}

///|
fn split_words(input : StringView) -> Array[String] {
  let result : Array[String] = []
  for part in input.split(" ") {
    if !part.is_empty() {
      result.push(part.to_owned())
    }
  }
  result
}

///|
fn split_array(input : String, separator : String) -> Array[String] {
  let result : Array[String] = []
  for part in input.split(separator) {
    result.push(part.to_owned())
  }
  result
}

///|
fn first_part(input : String, separator : String) -> String {
  let parts = split_array(input, separator)
  if parts.is_empty() {
    input
  } else {
    parts[0]
  }
}

///|
fn parse_int(value : String) -> Int raise DbcError {
  @strconv.from_str(value) catch {
    _ => raise DbcError::InvalidNumber(value)
  }
}

///|
fn parse_uint(value : String) -> UInt raise DbcError {
  let number : Int = @strconv.from_str(value) catch {
    _ => raise DbcError::InvalidNumber(value)
  }
  number.reinterpret_as_uint()
}

///|
/// The message identifier.
pub fn Message::id(self : Message) -> UInt {
  self.id
}

///|
/// The message name.
pub fn Message::name(self : Message) -> String {
  self.name
}

///|
/// The configured payload length.
pub fn Message::dlc(self : Message) -> Int {
  self.dlc
}

///|
/// The signal name.
pub fn Signal::name(self : Signal) -> String {
  self.name
}

///|
/// The signal's start bit.
pub fn Signal::start_bit(self : Signal) -> Int {
  self.start_bit
}
