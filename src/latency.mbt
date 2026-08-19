///|
/// Errors raised by a latency measurement window.
pub suberror LatencyError {
  InvalidCapacity
  InvalidTimestamp
  InvalidPercentile
} derive(Debug)

///|
/// One completed request/response timing sample.
pub struct LatencySample {
  sequence : UInt
  created_us : UInt64
  completed_us : UInt64
  payload_bytes : Int
}

///|
/// A summary of samples currently retained by a latency window.
pub struct LatencyStats {
  count : Int
  minimum_us : UInt64?
  maximum_us : UInt64?
  average_us : Double
  p95_us : UInt64?
  jitter_us : UInt64
  payload_bytes : Int
}

///|
/// A bounded rolling timing window for transport and diagnostic paths.
pub struct LatencyWindow {
  capacity : Int
  mut next_sequence : UInt
  samples : Array[LatencySample]
  mut last_completed_us : UInt64?
}

///|
pub fn new_latency_window(capacity : Int) -> LatencyWindow raise LatencyError {
  if capacity < 0 {
    raise InvalidCapacity
  }
  { capacity, next_sequence: 1, samples: [], last_completed_us: None }
}

///|
/// Record a completed sample and return its sequence number.
pub fn LatencyWindow::record(
  self : LatencyWindow,
  created_us : UInt64,
  completed_us : UInt64,
  payload_bytes : Int,
) -> UInt raise LatencyError {
  if completed_us < created_us || payload_bytes < 0 {
    raise InvalidTimestamp
  }
  match self.last_completed_us {
    Some(previous) => if completed_us < previous { raise InvalidTimestamp }
    None => ()
  }
  if self.capacity > 0 && self.samples.length() >= self.capacity {
    ignore(self.samples.remove(0))
  }
  let sequence = self.next_sequence
  self.next_sequence = if sequence == 0xFFFFFFFF { 1 } else { sequence + 1 }
  self.samples.push({ sequence, created_us, completed_us, payload_bytes })
  self.last_completed_us = Some(completed_us)
  sequence
}

///|
/// Calculate a stable summary of the retained timing samples.
pub fn LatencyWindow::stats(self : LatencyWindow) -> LatencyStats {
  if self.samples.is_empty() {
    return {
      count: 0,
      minimum_us: None,
      maximum_us: None,
      average_us: 0.0,
      p95_us: None,
      jitter_us: 0,
      payload_bytes: 0,
    }
  }
  let durations : Array[UInt64] = []
  let mut total : UInt64 = 0
  let mut payload_bytes = 0
  for sample in self.samples {
    let duration = sample.completed_us - sample.created_us
    durations.push(duration)
    total += duration
    payload_bytes += sample.payload_bytes
  }
  durations.sort()
  let count = durations.length()
  let p95_index = (count * 95 + 99) / 100 - 1
  let minimum = durations[0]
  let maximum = durations[count - 1]
  {
    count,
    minimum_us: Some(minimum),
    maximum_us: Some(maximum),
    average_us: total.to_double() / count.to_double(),
    p95_us: Some(durations[p95_index]),
    jitter_us: maximum - minimum,
    payload_bytes,
  }
}

///|
/// Return an arbitrary percentile using nearest-rank selection.
pub fn LatencyWindow::percentile(
  self : LatencyWindow,
  percent : Int,
) -> UInt64 raise LatencyError {
  if percent < 0 || percent > 100 || self.samples.is_empty() {
    raise InvalidPercentile
  }
  let values : Array[UInt64] = []
  for sample in self.samples {
    values.push(sample.completed_us - sample.created_us)
  }
  values.sort()
  let rank = ((values.length() * percent + 99) / 100).max(1)
  values[rank - 1]
}

///|
pub fn LatencyWindow::length(self : LatencyWindow) -> Int {
  self.samples.length()
}

///|
pub fn LatencyWindow::capacity(self : LatencyWindow) -> Int {
  self.capacity
}

///|
pub fn LatencyWindow::samples(self : LatencyWindow) -> Array[LatencySample] {
  self.samples.copy()
}

///|
pub fn LatencySample::sequence(self : LatencySample) -> UInt {
  self.sequence
}

///|
pub fn LatencySample::created_at(self : LatencySample) -> UInt64 {
  self.created_us
}

///|
pub fn LatencySample::completed_at(self : LatencySample) -> UInt64 {
  self.completed_us
}

///|
pub fn LatencySample::duration(self : LatencySample) -> UInt64 {
  self.completed_us - self.created_us
}

///|
pub fn LatencySample::payload_bytes(self : LatencySample) -> Int {
  self.payload_bytes
}

///|
pub fn LatencyStats::count(self : LatencyStats) -> Int {
  self.count
}

///|
pub fn LatencyStats::minimum(self : LatencyStats) -> UInt64? {
  self.minimum_us
}

///|
pub fn LatencyStats::maximum(self : LatencyStats) -> UInt64? {
  self.maximum_us
}

///|
pub fn LatencyStats::average(self : LatencyStats) -> Double {
  self.average_us
}

///|
pub fn LatencyStats::p95(self : LatencyStats) -> UInt64? {
  self.p95_us
}

///|
pub fn LatencyStats::jitter(self : LatencyStats) -> UInt64 {
  self.jitter_us
}

///|
pub fn LatencyStats::payload_bytes(self : LatencyStats) -> Int {
  self.payload_bytes
}

///|
/// Calculate payload throughput over an observation interval.
pub fn LatencyStats::throughput_bytes_per_second(
  self : LatencyStats,
  duration_us : UInt64,
) -> Double {
  if duration_us == 0 {
    0.0
  } else {
    self.payload_bytes.to_double() * 1_000_000.0 / duration_us.to_double()
  }
}

///|
/// Render a compact, stable summary for benchmark artifacts.
pub fn LatencyStats::to_text(self : LatencyStats) -> String {
  "samples=\{self.count} average_us=\{self.average_us} jitter_us=\{self.jitter_us} payload_bytes=\{self.payload_bytes}"
}

///|
/// Return the newest retained sample, if any.
pub fn LatencyWindow::latest(self : LatencyWindow) -> LatencySample? {
  if self.samples.is_empty() {
    None
  } else {
    Some(self.samples[self.samples.length() - 1])
  }
}

///|
/// Return the oldest retained sample, if any.
pub fn LatencyWindow::oldest(self : LatencyWindow) -> LatencySample? {
  if self.samples.is_empty() {
    None
  } else {
    Some(self.samples[0])
  }
}

///|
pub fn LatencyWindow::is_empty(self : LatencyWindow) -> Bool {
  self.samples.is_empty()
}

///|
pub fn LatencyStats::has_data(self : LatencyStats) -> Bool {
  self.count > 0
}
