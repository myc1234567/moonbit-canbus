///|
/// Errors from the extended DBC reader.
pub suberror DbcExtendedError {
  InvalidMessage
  InvalidSignal
  InvalidNumber
  MissingMessage
  InvalidRange
} derive(Debug)

///|
/// A parse result that records ignored non-semantic lines.
pub struct DbcParseReport {
  messages : Array[Message]
  ignored_lines : Int
  signal_lines : Int
}

///|
/// Parse common factor, offset, range and unit fields in SG_ records.
pub fn parse_dbc_extended(
  input : String,
) -> DbcParseReport raise DbcExtendedError {
  let messages : Array[Message] = []
  let mut current : Message? = None
  let mut ignored_lines = 0
  let mut signal_lines = 0
  for raw in input.split("\n") {
    let line = raw.trim()
    if line.is_empty() ||
      line.has_prefix(";") ||
      line.has_prefix("VERSION") ||
      line.has_prefix("NS_") ||
      line.has_prefix("BS_") ||
      line.has_prefix("BU_") {
      ignored_lines += 1
    } else if line.has_prefix("BO_ ") {
      let fields = dbc_words(line)
      if fields.length() < 4 {
        raise InvalidMessage
      }
      let id = dbc_uint(fields[1])
      let name = dbc_before(fields[2], ":")
      let dlc = dbc_int(fields[3])
      match current {
        Some(previous) => messages.push(previous)
        None => ()
      }
      current = Some(message(id, name, dlc))
    } else if line.has_prefix("SG_ ") {
      match current {
        None => raise MissingMessage
        Some(item) => {
          let fields = dbc_words(line)
          if fields.length() < 4 {
            raise InvalidSignal
          }
          let layout = dbc_split(fields[3], "|")
          if layout.length() != 2 {
            raise InvalidSignal
          }
          let start_bit = dbc_int(layout[0])
          let size_endian = dbc_split(layout[1], "@")
          let size = dbc_int(size_endian[0])
          let endian_sign = if size_endian.length() > 1 {
            size_endian[1]
          } else {
            "1+"
          }
          let factor_offset = if fields.length() > 4 {
            dbc_parenthesized(fields[4])
          } else {
            ["1", "0"]
          }
          if factor_offset.length() != 2 {
            raise InvalidNumber
          }
          let range = if fields.length() > 5 {
            dbc_parenthesized(fields[5])
          } else {
            ["0", "0"]
          }
          if range.length() != 2 {
            raise InvalidRange
          }
          let unit = if fields.length() > 6 {
            fields[6].replace_all(old="\"", new="")
          } else {
            ""
          }
          item.add_signal(
            signal(
              fields[1],
              start_bit,
              size,
              little_endian=endian_sign.has_prefix("1"),
              signed=endian_sign.has_suffix("-"),
              factor=dbc_double(factor_offset[0]),
              offset=dbc_double(factor_offset[1]),
              minimum=dbc_double(range[0]),
              maximum=dbc_double(range[1]),
              unit~,
            ),
          )
          signal_lines += 1
        }
      }
    } else {
      ignored_lines += 1
    }
  }
  match current {
    Some(last) => messages.push(last)
    None => ()
  }
  { messages, ignored_lines, signal_lines }
}

///|
pub fn DbcParseReport::messages(self : DbcParseReport) -> Array[Message] {
  self.messages.copy()
}

///|
pub fn DbcParseReport::message_count(self : DbcParseReport) -> Int {
  self.messages.length()
}

///|
pub fn DbcParseReport::ignored_lines(self : DbcParseReport) -> Int {
  self.ignored_lines
}

///|
pub fn DbcParseReport::signal_lines(self : DbcParseReport) -> Int {
  self.signal_lines
}

///|
/// Return a message's signals ordered by start bit.
pub fn Message::signals_by_start_bit(self : Message) -> Array[Signal] {
  let result = self.signals.copy()
  result.sort_by((left, right) => {
    if left.start_bit < right.start_bit {
      -1
    } else if left.start_bit > right.start_bit {
      1
    } else {
      0
    }
  })
  result
}

///|
/// Return a message's maximum configured bit end.
pub fn Message::required_bytes(self : Message) -> Int {
  let mut maximum = 0
  for item in self.signals {
    let end = item.start_bit + item.size
    if end > maximum {
      maximum = end
    }
  }
  (maximum + 7) / 8
}

///|
/// Return a stable schema summary for tooling.
pub fn Message::schema_text(self : Message) -> String {
  let builder = StringBuilder()
  builder.write_string(self.name)
  builder.write_string("[")
  for index, item in self.signals {
    if index > 0 {
      builder.write_string(",")
    }
    builder.write_string(item.name)
    builder.write_string(":")
    builder.write_string(item.size.to_string())
  }
  builder.write_string("]")
  builder.to_string()
}

///|
fn dbc_words(input : StringView) -> Array[String] {
  let result : Array[String] = []
  for part in input.split(" ") {
    if !part.is_empty() {
      result.push(part.to_owned())
    }
  }
  result
}

///|
fn dbc_split(input : String, separator : String) -> Array[String] {
  let result : Array[String] = []
  for part in input.split(separator) {
    result.push(part.to_owned())
  }
  result
}

///|
fn dbc_before(input : String, separator : String) -> String {
  match input.split_once(separator) {
    Some((prefix, _)) => prefix.to_owned()
    None => input
  }
}

///|
fn dbc_parenthesized(input : String) -> Array[String] {
  let trimmed = input.trim(chars="()[]")
  let separator = if input.contains("|") { "|" } else { "," }
  dbc_split(trimmed.to_owned(), separator)
}

///|
fn dbc_int(value : String) -> Int raise DbcExtendedError {
  @strconv.from_str(value) catch {
    _ => raise InvalidNumber
  }
}

///|
fn dbc_uint(value : String) -> UInt raise DbcExtendedError {
  @strconv.from_str(value) catch {
    _ => raise InvalidNumber
  }
}

///|
fn dbc_double(value : String) -> Double raise DbcExtendedError {
  @strconv.from_str(value) catch {
    _ => raise InvalidNumber
  }
}
