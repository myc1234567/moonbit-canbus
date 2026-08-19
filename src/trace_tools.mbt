///|
/// Errors raised when validating or parsing a trace log.
pub suberror TraceError {
  NonMonotonicTimestamp
  InvalidLine
  InvalidTimestamp
  InvalidFrame
} derive(Debug)

///|
/// Validate timestamps and frame invariants in capture order.
pub fn Trace::validate(self : Trace) -> Unit raise TraceError {
  let mut previous : UInt64? = None
  for entry in self.entries {
    match previous {
      Some(timestamp) =>
        if entry.timestamp_us < timestamp {
          raise NonMonotonicTimestamp
        }
      None => ()
    }
    if !frame_is_valid(entry.frame) {
      raise InvalidFrame
    }
    previous = Some(entry.timestamp_us)
  }
}

///|
/// Return a capture-order copy sorted by timestamp and arbitration id.
pub fn Trace::sorted(self : Trace) -> Trace {
  let result = new_trace()
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
    result.record(entry.timestamp_us, entry.frame)
  }
  result
}

///|
/// Encode a trace in a stable CSV-like text format.
pub fn Trace::to_text(self : Trace) -> String {
  let builder = StringBuilder()
  builder.write_string("timestamp_us,frame_hex\n")
  for entry in self.entries {
    builder.write_string(entry.timestamp_us.to_string())
    builder.write_string(",")
    builder.write_string(frame_to_hex(entry.frame))
    builder.write_string("\n")
  }
  builder.to_string()
}

///|
/// Parse a trace produced by `Trace::to_text`.
pub fn trace_from_text(text : String) -> Trace raise TraceError {
  let result = new_trace()
  let mut index = 0
  for raw in text.split("\n") {
    if index == 0 {
      if raw.trim() != "timestamp_us,frame_hex" {
        raise InvalidLine
      }
    } else {
      let line = raw.trim()
      if !line.is_empty() {
        let fields : Array[String] = []
        for part in line.split(",") {
          fields.push(part.to_owned())
        }
        if fields.length() != 2 {
          raise InvalidLine
        }
        let timestamp : UInt64 = @strconv.from_str(fields[0]) catch {
          _ => raise InvalidTimestamp
        }
        let frame = frame_from_hex(fields[1]) catch { _ => raise InvalidFrame }
        result.record(timestamp, frame)
      }
    }
    index += 1
  }
  result.validate()
  result
}

///|
/// Select entries matching an identifier.
pub fn Trace::filter_id(self : Trace, id : UInt) -> Trace {
  let result = new_trace()
  for entry in self.entries {
    if entry.frame.id() == id {
      result.record(entry.timestamp_us, entry.frame)
    }
  }
  result
}

///|
/// Select entries in a closed timestamp interval.
pub fn Trace::between(
  self : Trace,
  start_us : UInt64,
  end_us : UInt64,
) -> Trace {
  let result = new_trace()
  for entry in self.entries {
    if entry.timestamp_us >= start_us && entry.timestamp_us <= end_us {
      result.record(entry.timestamp_us, entry.frame)
    }
  }
  result
}

///|
/// Return the first and last capture timestamps.
pub fn Trace::time_range(self : Trace) -> (UInt64, UInt64)? {
  if self.entries.is_empty() {
    None
  } else {
    Some(
      (
        self.entries[0].timestamp_us,
        self.entries[self.entries.length() - 1].timestamp_us,
      ),
    )
  }
}

///|
/// Merge two traces and normalize their ordering.
pub fn merge_traces(left : Trace, right : Trace) -> Trace {
  let result = new_trace()
  for entry in left.entries {
    result.record(entry.timestamp_us, entry.frame)
  }
  for entry in right.entries {
    result.record(entry.timestamp_us, entry.frame)
  }
  result.sorted()
}

///|
/// Return all frames in capture order.
pub fn Trace::frames(self : Trace) -> Array[Frame] {
  self.entries.map(entry => entry.frame)
}
