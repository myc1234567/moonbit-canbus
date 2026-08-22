///|
/// Stable output formats for trace artifacts.
pub enum TraceExportFormat {
  TraceExportCanText
  TraceExportCsv
  TraceExportSummary
  TraceExportReplayScript
}

///|
pub fn trace_export_format_variants() -> Array[TraceExportFormat] {
  [
    TraceExportCanText,
    TraceExportCsv,
    TraceExportSummary,
    TraceExportReplayScript,
  ]
}

///|
/// Options controlling deterministic trace export.
pub struct TraceExportOptions {
  format : TraceExportFormat
  include_channel : Bool
  include_sequence : Bool
  include_header : Bool
  normalize_timestamps : Bool
  max_rows : Int
}

///|
pub fn trace_export_options(
  format? : TraceExportFormat = TraceExportCanText,
  include_channel? : Bool = true,
  include_sequence? : Bool = true,
  include_header? : Bool = true,
  normalize_timestamps? : Bool = false,
  max_rows? : Int = 0,
) -> TraceExportOptions {
  {
    format,
    include_channel,
    include_sequence,
    include_header,
    normalize_timestamps,
    max_rows,
  }
}

///|
pub fn TraceExportOptions::format(
  self : TraceExportOptions,
) -> TraceExportFormat {
  self.format
}

///|
pub fn TraceExportOptions::include_channel(self : TraceExportOptions) -> Bool {
  self.include_channel
}

///|
pub fn TraceExportOptions::include_sequence(self : TraceExportOptions) -> Bool {
  self.include_sequence
}

///|
pub fn TraceExportOptions::include_header(self : TraceExportOptions) -> Bool {
  self.include_header
}

///|
pub fn TraceExportOptions::normalize_timestamps(
  self : TraceExportOptions,
) -> Bool {
  self.normalize_timestamps
}

///|
pub fn TraceExportOptions::max_rows(self : TraceExportOptions) -> Int {
  self.max_rows
}

///|
/// A line-level export record used by CSV and replay tools.
pub struct TraceExportRecord {
  timestamp_us : UInt64
  sequence : Int
  channel : String
  frame : Frame
}

///|
pub fn trace_export_record(
  timestamp_us : UInt64,
  sequence : Int,
  channel : String,
  frame : Frame,
) -> TraceExportRecord {
  { timestamp_us, sequence, channel, frame }
}

///|
pub fn TraceExportRecord::timestamp_us(self : TraceExportRecord) -> UInt64 {
  self.timestamp_us
}

///|
pub fn TraceExportRecord::sequence(self : TraceExportRecord) -> Int {
  self.sequence
}

///|
pub fn TraceExportRecord::channel(self : TraceExportRecord) -> String {
  self.channel
}

///|
pub fn TraceExportRecord::frame(self : TraceExportRecord) -> Frame {
  self.frame
}

///|
pub fn TraceExportRecord::relative_to(
  self : TraceExportRecord,
  base : UInt64,
) -> UInt64 {
  if self.timestamp_us >= base {
    self.timestamp_us - base
  } else {
    0
  }
}

///|
/// Convert a trace into ordered export records.
pub fn trace_export_records(
  trace : Trace,
  channel? : String = "can0",
  normalize_timestamps? : Bool = false,
) -> Array[TraceExportRecord] {
  let entries = trace.entries()
  let base : UInt64 = if entries.is_empty() {
    0
  } else {
    entries[0].timestamp()
  }
  let result : Array[TraceExportRecord] = []
  for index, entry in entries {
    let timestamp = if normalize_timestamps {
      entry.timestamp() - base
    } else {
      entry.timestamp()
    }
    result.push(trace_export_record(timestamp, index, channel, entry.frame()))
  }
  result
}

///|
/// A stateful exporter that can be used incrementally by a logger.
pub struct TraceExporter {
  options : TraceExportOptions
  records : Array[TraceExportRecord]
  mut rows : Int
  mut bytes : Int
  mut errors : Int
}

///|
pub fn new_trace_exporter(
  options? : TraceExportOptions = trace_export_options(),
) -> TraceExporter {
  { options, records: [], rows: 0, bytes: 0, errors: 0 }
}

///|
pub fn TraceExporter::add(
  self : TraceExporter,
  record : TraceExportRecord,
) -> Bool {
  if self.options.max_rows() > 0 &&
    self.records.length() >= self.options.max_rows() {
    self.errors += 1
    false
  } else {
    self.records.push(record)
    self.rows += 1
    true
  }
}

///|
pub fn TraceExporter::add_trace(
  self : TraceExporter,
  trace : Trace,
  channel? : String = "can0",
) -> Int {
  let records = trace_export_records(
    trace,
    channel~,
    normalize_timestamps=self.options.normalize_timestamps(),
  )
  let mut added = 0
  for record in records {
    if self.add(record) {
      added += 1
    }
  }
  added
}

///|
pub fn TraceExporter::records(self : TraceExporter) -> Array[TraceExportRecord] {
  self.records.copy()
}

///|
pub fn TraceExporter::rows(self : TraceExporter) -> Int {
  self.rows
}

///|
pub fn TraceExporter::bytes(self : TraceExporter) -> Int {
  self.bytes
}

///|
pub fn TraceExporter::errors(self : TraceExporter) -> Int {
  self.errors
}

///|
pub fn TraceExporter::render(self : TraceExporter) -> String {
  let output = match self.options.format() {
    TraceExportCanText => trace_export_can_text(self.records, self.options)
    TraceExportCsv => trace_export_csv(self.records, self.options)
    TraceExportSummary => trace_export_summary(self.records)
    TraceExportReplayScript => trace_export_replay_script(self.records)
  }
  self.bytes = output.length()
  output
}

///|
pub fn trace_export_can_text(
  records : Array[TraceExportRecord],
  options : TraceExportOptions,
) -> String {
  let lines : Array[String] = []
  for record in records {
    let prefix = record.timestamp_us().to_string() + " "
    let channel = if options.include_channel() {
      record.channel() + " "
    } else {
      ""
    }
    lines.push(
      prefix + channel + can_line(record.timestamp_us(), record.frame()),
    )
  }
  lines.join("\n")
}

///|
pub fn trace_export_csv(
  records : Array[TraceExportRecord],
  options : TraceExportOptions,
) -> String {
  let lines : Array[String] = []
  if options.include_header() {
    let header = if options.include_channel() {
      "timestamp_us,sequence,channel,id,extended,data"
    } else {
      "timestamp_us,sequence,id,extended,data"
    }
    lines.push(header)
  }
  for record in records {
    let data = frame_to_hex(record.frame())
    let channel = if options.include_channel() {
      "," + record.channel()
    } else {
      ""
    }
    lines.push(
      record.timestamp_us().to_string() +
      "," +
      record.sequence().to_string() +
      channel +
      "," +
      record.frame().id().to_string() +
      "," +
      record.frame().is_extended().to_string() +
      "," +
      data,
    )
  }
  lines.join("\n")
}

///|
pub fn trace_export_summary(records : Array[TraceExportRecord]) -> String {
  let frames : Array[Frame] = []
  for record in records {
    frames.push(record.frame())
  }
  let metrics = frame_metrics(frames)
  metrics.to_text()
}

///|
pub fn trace_export_replay_script(records : Array[TraceExportRecord]) -> String {
  let lines : Array[String] = ["# moonbit-canbus replay script"]
  for record in records {
    lines.push(
      "at " +
      record.timestamp_us().to_string() +
      " us: id=" +
      record.frame().id().to_string() +
      " data=" +
      frame_to_hex(record.frame()),
    )
  }
  lines.join("\n")
}

///|
/// Parse a compact CAN-text export generated by this package.
pub fn trace_import_can_text(text : String) -> Trace raise CanTextError {
  let trace = new_trace()
  for raw in text.split("\n") {
    let line = raw.trim()
    if line.is_empty() || line.has_prefix("#") {
      continue
    }
    let parts : Array[String] = []
    for part in line.split(" ") {
      if !part.is_empty() {
        parts.push(part.to_owned())
      }
    }
    if parts.length() < 2 {
      continue
    }
    let timestamp : UInt64 = @strconv.from_str(parts[0]) catch {
      _ => raise CanTextError::InvalidTimestamp
    }
    let parsed = parse_can_line(parts[parts.length() - 1]) catch {
      _ => raise CanTextError::InvalidPayload
    }
    trace.record(timestamp, parsed.1)
  }
  trace
}

///|
/// Return the earliest and latest timestamps in an export.
pub fn trace_export_time_range(
  records : Array[TraceExportRecord],
) -> (UInt64, UInt64)? {
  if records.is_empty() {
    None
  } else {
    let mut start = records[0].timestamp_us()
    let mut end = start
    for record in records {
      if record.timestamp_us() < start {
        start = record.timestamp_us()
      }
      if record.timestamp_us() > end {
        end = record.timestamp_us()
      }
    }
    Some((start, end))
  }
}

///|
/// Return records belonging to one identifier.
pub fn trace_export_filter_id(
  records : Array[TraceExportRecord],
  identifier : UInt,
) -> Array[TraceExportRecord] {
  records.filter(record => record.frame().id() == identifier)
}

///|
/// Return records in a closed time interval.
pub fn trace_export_between(
  records : Array[TraceExportRecord],
  start_us : UInt64,
  end_us : UInt64,
) -> Array[TraceExportRecord] {
  records.filter(record => {
    record.timestamp_us() >= start_us && record.timestamp_us() <= end_us
  })
}

///|
/// Calculate inter-arrival times for one identifier.
pub fn trace_export_intervals(
  records : Array[TraceExportRecord],
  identifier : UInt,
) -> Array[UInt64] {
  let selected = trace_export_filter_id(records, identifier)
  let result : Array[UInt64] = []
  for index in 1..<selected.length() {
    result.push(
      selected[index].timestamp_us() - selected[index - 1].timestamp_us(),
    )
  }
  result
}

///|
/// Produce a bounded sample for a large trace export.
pub fn trace_export_sample(
  records : Array[TraceExportRecord],
  stride : Int,
) -> Array[TraceExportRecord] {
  if stride <= 1 {
    records.copy()
  } else {
    let result : Array[TraceExportRecord] = []
    for index, record in records {
      if index % stride == 0 {
        result.push(record)
      }
    }
    result
  }
}

///|
/// Compare two export streams and return a compact diff count.
pub fn trace_export_difference_count(
  left : Array[TraceExportRecord],
  right : Array[TraceExportRecord],
) -> Int {
  let total = if left.length() > right.length() {
    left.length()
  } else {
    right.length()
  }
  let mut differences = 0
  for index in 0..<total {
    if index >= left.length() || index >= right.length() {
      differences += 1
    } else if left[index].frame().id() != right[index].frame().id() ||
      left[index].frame().data() != right[index].frame().data() {
      differences += 1
    }
  }
  differences
}
