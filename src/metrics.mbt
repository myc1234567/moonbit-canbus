///|
/// Aggregate counters for a collection of CAN frames.
pub struct FrameMetrics {
  total : Int
  classic_data : Int
  classic_remote : Int
  can_fd : Int
  errors : Int
  extended : Int
  payload_bytes : Int
  wire_bits : Int
  minimum_id : UInt?
  maximum_id : UInt?
  identifiers : Array[UInt]
  payload_histogram : Array[Int]
}

///|
/// Calculate deterministic metrics without changing the input order.
pub fn frame_metrics(frames : Array[Frame]) -> FrameMetrics {
  let histogram = Array::make(65, 0)
  let identifiers : Array[UInt] = []
  let mut classic_data = 0
  let mut classic_remote = 0
  let mut can_fd = 0
  let mut errors = 0
  let mut extended = 0
  let mut payload_bytes = 0
  let mut wire_bits = 0
  let mut minimum_id : UInt? = None
  let mut maximum_id : UInt? = None
  for frame in frames {
    match classify_frame(frame) {
      ClassicData => classic_data += 1
      ClassicRemote => classic_remote += 1
      CanFdData => can_fd += 1
      SimulationError => errors += 1
    }
    if frame.is_extended() {
      extended += 1
    }
    let length = frame.data().length()
    histogram[length] += 1
    payload_bytes += length
    wire_bits += frame_wire_bits(frame)
    identifiers.push(frame.id())
    match minimum_id {
      Some(value) => if frame.id() < value { minimum_id = Some(frame.id()) }
      None => minimum_id = Some(frame.id())
    }
    match maximum_id {
      Some(value) => if frame.id() > value { maximum_id = Some(frame.id()) }
      None => maximum_id = Some(frame.id())
    }
  }
  identifiers.sort()
  identifiers.dedup()
  {
    total: frames.length(),
    classic_data,
    classic_remote,
    can_fd,
    errors,
    extended,
    payload_bytes,
    wire_bits,
    minimum_id,
    maximum_id,
    identifiers,
    payload_histogram: histogram,
  }
}

///|
pub fn FrameMetrics::total(self : FrameMetrics) -> Int {
  self.total
}

///|
pub fn FrameMetrics::classic_data(self : FrameMetrics) -> Int {
  self.classic_data
}

///|
pub fn FrameMetrics::classic_remote(self : FrameMetrics) -> Int {
  self.classic_remote
}

///|
pub fn FrameMetrics::can_fd(self : FrameMetrics) -> Int {
  self.can_fd
}

///|
pub fn FrameMetrics::errors(self : FrameMetrics) -> Int {
  self.errors
}

///|
pub fn FrameMetrics::extended(self : FrameMetrics) -> Int {
  self.extended
}

///|
pub fn FrameMetrics::payload_bytes(self : FrameMetrics) -> Int {
  self.payload_bytes
}

///|
pub fn FrameMetrics::wire_bits(self : FrameMetrics) -> Int {
  self.wire_bits
}

///|
pub fn FrameMetrics::minimum_id(self : FrameMetrics) -> UInt? {
  self.minimum_id
}

///|
pub fn FrameMetrics::maximum_id(self : FrameMetrics) -> UInt? {
  self.maximum_id
}

///|
pub fn FrameMetrics::identifiers(self : FrameMetrics) -> Array[UInt] {
  self.identifiers.copy()
}

///|
pub fn FrameMetrics::payload_count(self : FrameMetrics, length : Int) -> Int {
  match self.payload_histogram.get(length) {
    Some(value) => value
    None => 0
  }
}

///|
/// Calculate frames per second over an observation interval.
pub fn frames_per_second(
  metrics : FrameMetrics,
  duration_us : UInt64,
) -> Double {
  if duration_us == 0 {
    0.0
  } else {
    metrics.total.to_double() * 1_000_000.0 / duration_us.to_double()
  }
}

///|
/// Calculate approximate utilization for a bitrate in kbit/s.
pub fn bus_utilization(
  metrics : FrameMetrics,
  duration_us : UInt64,
  bitrate_kbps : UInt,
) -> Double {
  if duration_us == 0 || bitrate_kbps == 0 {
    0.0
  } else {
    metrics.wire_bits.to_double() *
    1000.0 /
    (duration_us.to_double() * bitrate_kbps.to_double())
  }
}

///|
/// Render a stable metrics report for a CLI or CI artifact.
pub fn FrameMetrics::to_text(self : FrameMetrics) -> String {
  "frames=\{self.total} classic_data=\{self.classic_data} classic_remote=\{self.classic_remote} can_fd=\{self.can_fd} errors=\{self.errors} payload_bytes=\{self.payload_bytes} wire_bits=\{self.wire_bits} unique_ids=\{self.identifiers.length()}"
}

///|
/// Compute metrics directly from a trace.
pub fn trace_metrics(trace : Trace) -> FrameMetrics {
  frame_metrics(trace.frames())
}
