///|
/// Errors raised when validating or serializing a DBC schema.
pub suberror DbcSchemaError {
  DuplicateMessageId
  InvalidIdentifier
  EmptyMessageName
  InvalidDlc
  InvalidSignalLayout
  OverlappingSignals
} derive(Debug)

///|
/// Stable statistics for a validated DBC schema.
pub struct DbcSchemaReport {
  message_count : Int
  signal_count : Int
  unique_identifier_count : Int
  maximum_required_bytes : Int
}

///|
/// A single schema difference between two message collections.
pub struct DbcSchemaChange {
  id : UInt
  kind : String
  before : String?
  after : String?
}

///|
/// Validate identifiers, payload bounds and signal overlap.
pub fn validate_dbc_schema(
  messages : Array[Message],
) -> DbcSchemaReport raise DbcSchemaError {
  let mut signals = 0
  let mut maximum_required_bytes = 0
  let identifiers : Array[UInt] = []
  for item in messages {
    if item.id() > 0x1FFFFFFF {
      raise InvalidIdentifier
    }
    if item.name().is_empty() {
      raise EmptyMessageName
    }
    if item.dlc() < 0 || item.dlc() > 64 {
      raise InvalidDlc
    }
    for previous in identifiers {
      if previous == item.id() {
        raise DuplicateMessageId
      }
    }
    identifiers.push(item.id())
    let item_signals = item.signals()
    signals += item_signals.length()
    let required = item.required_bytes()
    if required > maximum_required_bytes {
      maximum_required_bytes = required
    }
    for signal in item_signals {
      validate_signal(item, signal) catch {
        error => raise error
      }
    }
    for left_index in 0..<item_signals.length() {
      let left = item_signals[left_index]
      for right_index in (left_index + 1)..<item_signals.length() {
        let right = item_signals[right_index]
        if signals_overlap(left, right) {
          raise OverlappingSignals
        }
      }
    }
  }
  {
    message_count: messages.length(),
    signal_count: signals,
    unique_identifier_count: identifiers.length(),
    maximum_required_bytes,
  }
}

///|
/// Serialize a schema to deterministic DBC text.
pub fn serialize_dbc_schema(
  messages : Array[Message],
) -> String raise DbcSchemaError {
  ignore(validate_dbc_schema(messages))
  let ordered = messages.copy()
  ordered.sort_by((left, right) => {
    if left.id() < right.id() {
      -1
    } else if left.id() > right.id() {
      1
    } else {
      0
    }
  })
  let builder = StringBuilder()
  builder.write_string("VERSION \"\"\n")
  builder.write_string("NS_ :\n\tNS_DESC_\n")
  builder.write_string("BS_:\n")
  builder.write_string("BU_: Vector__XXX\n")
  for message in ordered {
    builder.write_string("BO_ ")
    builder.write_string(message.id().to_string())
    builder.write_string(" ")
    builder.write_string(message.name())
    builder.write_string(": ")
    builder.write_string(message.dlc().to_string())
    builder.write_string(" Vector__XXX\n")
    for signal in message.signals_by_start_bit() {
      builder.write_string(" SG_ ")
      builder.write_string(signal.name())
      builder.write_string(" : ")
      builder.write_string(signal.start_bit().to_string())
      builder.write_string("|")
      builder.write_string(signal.size().to_string())
      builder.write_string("@")
      builder.write_string(if signal.little_endian() { "1" } else { "0" })
      builder.write_string(if signal.is_signed() { "-" } else { "+" })
      builder.write_string(" (")
      builder.write_string(signal.factor().to_string())
      builder.write_string(",")
      builder.write_string(signal.offset().to_string())
      builder.write_string(") [")
      builder.write_string(signal.minimum().to_string())
      builder.write_string("|")
      builder.write_string(signal.maximum().to_string())
      builder.write_string("] \"")
      builder.write_string(signal.unit().replace_all(old="\"", new=""))
      builder.write_string("\" Vector__XXX\n")
    }
  }
  builder.to_string()
}

///|
/// Parse, validate and normalize an extended DBC document.
pub fn canonicalize_dbc(input : String) -> String raise DbcExtendedError {
  let report = parse_dbc_extended(input)
  ignore(
    validate_dbc_schema(report.messages()) catch {
      _ => raise InvalidMessage
    },
  )
  serialize_dbc_schema(report.messages()) catch {
    _ => raise InvalidMessage
  }
}

///|
/// Compare message collections by identifier and canonical schema text.
pub fn diff_dbc_schema(
  before : Array[Message],
  after : Array[Message],
) -> Array[DbcSchemaChange] {
  let result : Array[DbcSchemaChange] = []
  for left in before {
    match message_by_id(after, left.id()) {
      None =>
        result.push({
          id: left.id(),
          kind: "removed",
          before: Some(left.schema_text()),
          after: None,
        })
      Some(right) =>
        if left.schema_text() != right.schema_text() {
          result.push({
            id: left.id(),
            kind: "changed",
            before: Some(left.schema_text()),
            after: Some(right.schema_text()),
          })
        }
    }
  }
  for right in after {
    if message_by_id(before, right.id()) is None {
      result.push({
        id: right.id(),
        kind: "added",
        before: None,
        after: Some(right.schema_text()),
      })
    }
  }
  result.sort_by((left, right) => {
    if left.id < right.id {
      -1
    } else if left.id > right.id {
      1
    } else {
      0
    }
  })
  result
}

///|
pub fn DbcSchemaReport::message_count(self : DbcSchemaReport) -> Int {
  self.message_count
}

///|
pub fn DbcSchemaReport::signal_count(self : DbcSchemaReport) -> Int {
  self.signal_count
}

///|
pub fn DbcSchemaReport::unique_identifier_count(self : DbcSchemaReport) -> Int {
  self.unique_identifier_count
}

///|
pub fn DbcSchemaReport::maximum_required_bytes(self : DbcSchemaReport) -> Int {
  self.maximum_required_bytes
}

///|
pub fn DbcSchemaChange::id(self : DbcSchemaChange) -> UInt {
  self.id
}

///|
pub fn DbcSchemaChange::kind(self : DbcSchemaChange) -> String {
  self.kind
}

///|
pub fn DbcSchemaChange::before(self : DbcSchemaChange) -> String? {
  self.before
}

///|
pub fn DbcSchemaChange::after(self : DbcSchemaChange) -> String? {
  self.after
}

///|
fn validate_signal(
  message : Message,
  signal : Signal,
) -> Unit raise DbcSchemaError {
  if signal.name().is_empty() ||
    signal.start_bit() < 0 ||
    signal.size() <= 0 ||
    signal.size() > 32 ||
    signal.start_bit() + signal.size() > message.dlc() * 8 {
    raise InvalidSignalLayout
  }
  if signal.minimum() > signal.maximum() {
    raise InvalidSignalLayout
  }
}

///|
fn signals_overlap(left : Signal, right : Signal) -> Bool {
  let left_end = left.start_bit() + left.size()
  let right_end = right.start_bit() + right.size()
  left.start_bit() < right_end && right.start_bit() < left_end
}

///|
fn message_by_id(messages : Array[Message], id : UInt) -> Message? {
  for message in messages {
    if message.id() == id {
      return Some(message)
    }
  }
  None
}
