///|
/// Errors raised by text log parsing.
pub suberror CanTextError {
  InvalidHeader
  InvalidFieldCount
  InvalidTimestamp
  InvalidPayload
} derive(Debug)

///|
/// A human-readable CAN log record.
pub struct CanLogEntry {
  timestamp_us : UInt64
  frame : Frame
  channel : String
}

///|
/// A portable text log with stable ordering.
pub struct CanLog {
  entries : Array[CanLogEntry]
}

///|
pub fn new_can_log() -> CanLog {
  { entries: [] }
}

///|
pub fn CanLog::push(
  self : CanLog,
  timestamp_us : UInt64,
  frame : Frame,
  channel? : String = "can0",
) -> Unit {
  self.entries.push({ timestamp_us, frame, channel })
}

///|
pub fn CanLog::length(self : CanLog) -> Int {
  self.entries.length()
}

///|
pub fn CanLog::entries(self : CanLog) -> Array[CanLogEntry] {
  self.entries.copy()
}

///|
/// Encode a log with a header and one comma-separated record per line.
pub fn CanLog::to_text(self : CanLog) -> String {
  let builder = StringBuilder()
  builder.write_string("timestamp_us,channel,frame_hex\n")
  for entry in self.entries {
    builder.write_string(entry.timestamp_us.to_string())
    builder.write_string(",")
    builder.write_string(entry.channel)
    builder.write_string(",")
    builder.write_string(frame_to_hex(entry.frame))
    builder.write_string("\n")
  }
  builder.to_string()
}

///|
/// Parse a log produced by `CanLog::to_text`.
pub fn can_log_from_text(text : String) -> CanLog raise CanTextError {
  let result = new_can_log()
  let mut line_number = 0
  for raw in text.split("\n") {
    if line_number == 0 {
      if raw.trim() != "timestamp_us,channel,frame_hex" {
        raise InvalidHeader
      }
    } else {
      let line = raw.trim()
      if !line.is_empty() {
        let fields : Array[String] = []
        for part in line.split(",") {
          fields.push(part.to_owned())
        }
        if fields.length() != 3 {
          raise InvalidFieldCount
        }
        let timestamp : UInt64 = @strconv.from_str(fields[0]) catch {
          _ => raise InvalidTimestamp
        }
        let frame = frame_from_hex(fields[2]) catch {
          _ => raise InvalidPayload
        }
        result.push(timestamp, frame, channel=fields[1])
      }
    }
    line_number += 1
  }
  result
}

///|
pub fn CanLog::sorted(self : CanLog) -> CanLog {
  let result = new_can_log()
  let entries = self.entries.copy()
  entries.sort_by((left, right) => {
    if left.timestamp_us < right.timestamp_us {
      -1
    } else if left.timestamp_us > right.timestamp_us {
      1
    } else {
      compare_frames(left.frame, right.frame)
    }
  })
  for entry in entries {
    result.push(entry.timestamp_us, entry.frame, channel=entry.channel)
  }
  result
}

///|
pub fn CanLog::filter_channel(self : CanLog, channel : String) -> CanLog {
  let result = new_can_log()
  for entry in self.entries {
    if entry.channel == channel {
      result.push(entry.timestamp_us, entry.frame, channel~)
    }
  }
  result
}

///|
pub fn CanLogEntry::timestamp(self : CanLogEntry) -> UInt64 {
  self.timestamp_us
}

///|
pub fn CanLogEntry::frame(self : CanLogEntry) -> Frame {
  self.frame
}

///|
pub fn CanLogEntry::channel(self : CanLogEntry) -> String {
  self.channel
}

///|
/// Encode a single compact line for shell tools.
pub fn can_line(timestamp_us : UInt64, frame : Frame) -> String {
  "\{timestamp_us},\{frame_to_hex(frame)}"
}

///|
/// Parse a compact two-field line.
pub fn parse_can_line(line : String) -> (UInt64, Frame) raise CanTextError {
  let fields : Array[String] = []
  for part in line.trim().split(",") {
    fields.push(part.to_owned())
  }
  if fields.length() != 2 {
    raise InvalidFieldCount
  }
  let timestamp : UInt64 = @strconv.from_str(fields[0]) catch {
    _ => raise InvalidTimestamp
  }
  let frame = frame_from_hex(fields[1]) catch { _ => raise InvalidPayload }
  (timestamp, frame)
}
