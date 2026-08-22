///|
/// Analysis mode used by a bus observability pipeline.
pub enum BusAnalysisMode {
  BusAnalysisLive
  BusAnalysisOffline
  BusAnalysisReplay
  BusAnalysisCompliance
}

///|
pub fn bus_analysis_mode_variants() -> Array[BusAnalysisMode] {
  [
    BusAnalysisLive,
    BusAnalysisOffline,
    BusAnalysisReplay,
    BusAnalysisCompliance,
  ]
}

///|
/// One timestamped observation supplied to the analyzer.
pub struct BusObservation {
  timestamp_us : UInt64
  frame : Frame
  channel : String
  sequence : UInt
}

///|
pub fn bus_observation(
  timestamp_us : UInt64,
  frame : Frame,
  channel? : String = "can0",
  sequence? : UInt = 0,
) -> BusObservation {
  { timestamp_us, frame, channel, sequence }
}

///|
pub fn BusObservation::timestamp_us(self : BusObservation) -> UInt64 {
  self.timestamp_us
}

///|
pub fn BusObservation::frame(self : BusObservation) -> Frame {
  self.frame
}

///|
pub fn BusObservation::channel(self : BusObservation) -> String {
  self.channel
}

///|
pub fn BusObservation::sequence(self : BusObservation) -> UInt {
  self.sequence
}

///|
/// Per-identifier statistics accumulated by a bus analyzer.
pub struct BusIdentifierProfile {
  identifier : UInt
  frames : Int
  first_seen_us : UInt64
  last_seen_us : UInt64
  mut min_payload : Int
  mut max_payload : Int
  mut wire_bits : Int
  extended : Bool
  intervals : Array[UInt64]
}

///|
pub fn BusIdentifierProfile::identifier(self : BusIdentifierProfile) -> UInt {
  self.identifier
}

///|
pub fn BusIdentifierProfile::frames(self : BusIdentifierProfile) -> Int {
  self.frames
}

///|
pub fn BusIdentifierProfile::first_seen_us(
  self : BusIdentifierProfile,
) -> UInt64 {
  self.first_seen_us
}

///|
pub fn BusIdentifierProfile::last_seen_us(
  self : BusIdentifierProfile,
) -> UInt64 {
  self.last_seen_us
}

///|
pub fn BusIdentifierProfile::min_payload(self : BusIdentifierProfile) -> Int {
  self.min_payload
}

///|
pub fn BusIdentifierProfile::max_payload(self : BusIdentifierProfile) -> Int {
  self.max_payload
}

///|
pub fn BusIdentifierProfile::wire_bits(self : BusIdentifierProfile) -> Int {
  self.wire_bits
}

///|
pub fn BusIdentifierProfile::extended(self : BusIdentifierProfile) -> Bool {
  self.extended
}

///|
pub fn BusIdentifierProfile::intervals(
  self : BusIdentifierProfile,
) -> Array[UInt64] {
  self.intervals.copy()
}

///|
pub fn BusIdentifierProfile::average_interval_us(
  self : BusIdentifierProfile,
) -> UInt64 {
  if self.intervals.is_empty() {
    0
  } else {
    let mut sum : UInt64 = 0
    for item in self.intervals {
      sum += item
    }
    sum / self.intervals.length().to_uint64()
  }
}

///|
pub fn BusIdentifierProfile::frequency_hz(
  self : BusIdentifierProfile,
) -> Double {
  let interval = self.average_interval_us()
  if interval == 0 {
    0.0
  } else {
    1_000_000.0 / interval.to_double()
  }
}

///|
pub fn BusIdentifierProfile::jitter_us(self : BusIdentifierProfile) -> UInt64 {
  if self.intervals.is_empty() {
    0
  } else {
    let mean = self.average_interval_us()
    let mut maximum : UInt64 = 0
    for item in self.intervals {
      let distance = if item >= mean { item - mean } else { mean - item }
      if distance > maximum {
        maximum = distance
      }
    }
    maximum
  }
}

///|
/// A compliance or quality anomaly detected from observations.
pub enum BusAnalysisAnomaly {
  BusAnomalyBurst(UInt, Int)
  BusAnomalyJitter(UInt, UInt64)
  BusAnomalyPayloadGrowth(UInt, Int, Int)
  BusAnomalyIdentifierChange(UInt)
  BusAnomalyTimestampRegression(UInt64)
  BusAnomalySequenceGap(UInt, UInt)
  BusAnomalyOverload(Double)
}

///|
pub fn bus_analysis_anomaly_variants() -> Array[BusAnalysisAnomaly] {
  [
    BusAnomalyBurst(0, 0),
    BusAnomalyJitter(0, 0),
    BusAnomalyPayloadGrowth(0, 0, 0),
    BusAnomalyIdentifierChange(0),
    BusAnomalyTimestampRegression(0),
    BusAnomalySequenceGap(0, 0),
    BusAnomalyOverload(0.0),
  ]
}

///|
pub fn bus_analysis_anomaly_text(anomaly : BusAnalysisAnomaly) -> String {
  match anomaly {
    BusAnomalyBurst(id, count) =>
      "burst id=" + id.to_string() + " count=" + count.to_string()
    BusAnomalyJitter(id, jitter) =>
      "jitter id=" + id.to_string() + " us=" + jitter.to_string()
    BusAnomalyPayloadGrowth(id, before, after) =>
      "payload-growth id=" +
      id.to_string() +
      " " +
      before.to_string() +
      "->" +
      after.to_string()
    BusAnomalyIdentifierChange(id) => "identifier-change id=" + id.to_string()
    BusAnomalyTimestampRegression(timestamp) =>
      "timestamp-regression " + timestamp.to_string()
    BusAnomalySequenceGap(expected, actual) =>
      "sequence-gap " + expected.to_string() + "->" + actual.to_string()
    BusAnomalyOverload(utilization) => "overload " + utilization.to_string()
  }
}

///|
/// A completed report from a bus analyzer.
pub struct BusAnalysisReport {
  mode : BusAnalysisMode
  channel : String
  start_us : UInt64?
  end_us : UInt64?
  total_frames : Int
  payload_bytes : Int
  wire_bits : Int
  profiles : Array[BusIdentifierProfile]
  anomalies : Array[BusAnalysisAnomaly]
  utilization : Double
}

///|
pub fn BusAnalysisReport::mode(self : BusAnalysisReport) -> BusAnalysisMode {
  self.mode
}

///|
pub fn BusAnalysisReport::channel(self : BusAnalysisReport) -> String {
  self.channel
}

///|
pub fn BusAnalysisReport::start_us(self : BusAnalysisReport) -> UInt64? {
  self.start_us
}

///|
pub fn BusAnalysisReport::end_us(self : BusAnalysisReport) -> UInt64? {
  self.end_us
}

///|
pub fn BusAnalysisReport::total_frames(self : BusAnalysisReport) -> Int {
  self.total_frames
}

///|
pub fn BusAnalysisReport::payload_bytes(self : BusAnalysisReport) -> Int {
  self.payload_bytes
}

///|
pub fn BusAnalysisReport::wire_bits(self : BusAnalysisReport) -> Int {
  self.wire_bits
}

///|
pub fn BusAnalysisReport::profiles(
  self : BusAnalysisReport,
) -> Array[BusIdentifierProfile] {
  self.profiles.copy()
}

///|
pub fn BusAnalysisReport::anomalies(
  self : BusAnalysisReport,
) -> Array[BusAnalysisAnomaly] {
  self.anomalies.copy()
}

///|
pub fn BusAnalysisReport::utilization(self : BusAnalysisReport) -> Double {
  self.utilization
}

///|
pub fn BusAnalysisReport::healthy(self : BusAnalysisReport) -> Bool {
  self.anomalies.is_empty() && self.utilization <= 0.8
}

///|
pub fn BusAnalysisReport::to_text(self : BusAnalysisReport) -> String {
  let anomaly_text : Array[String] = []
  for item in self.anomalies {
    anomaly_text.push(bus_analysis_anomaly_text(item))
  }
  "channel=" +
  self.channel +
  " frames=" +
  self.total_frames.to_string() +
  " payload_bytes=" +
  self.payload_bytes.to_string() +
  " wire_bits=" +
  self.wire_bits.to_string() +
  " utilization=" +
  self.utilization.to_string() +
  " anomalies=" +
  anomaly_text.join("|")
}

///|
/// A stateful analyzer that can be fed by a live adapter or a trace.
pub struct BusAnalyzer {
  mode : BusAnalysisMode
  channel : String
  bitrate_kbps : UInt
  burst_window_us : UInt64
  jitter_limit_us : UInt64
  observations : Array[BusObservation]
  mut last_timestamp_us : UInt64?
  mut last_sequence : UInt?
}

///|
pub fn new_bus_analyzer(
  mode : BusAnalysisMode,
  channel? : String = "can0",
  bitrate_kbps? : UInt = 500,
  burst_window_us? : UInt64 = 10_000,
  jitter_limit_us? : UInt64 = 1_000,
) -> BusAnalyzer {
  {
    mode,
    channel,
    bitrate_kbps,
    burst_window_us,
    jitter_limit_us,
    observations: [],
    last_timestamp_us: None,
    last_sequence: None,
  }
}

///|
pub fn BusAnalyzer::mode(self : BusAnalyzer) -> BusAnalysisMode {
  self.mode
}

///|
pub fn BusAnalyzer::channel(self : BusAnalyzer) -> String {
  self.channel
}

///|
pub fn BusAnalyzer::bitrate_kbps(self : BusAnalyzer) -> UInt {
  self.bitrate_kbps
}

///|
pub fn BusAnalyzer::length(self : BusAnalyzer) -> Int {
  self.observations.length()
}

///|
pub fn BusAnalyzer::observations(self : BusAnalyzer) -> Array[BusObservation] {
  self.observations.copy()
}

///|
pub fn BusAnalyzer::reset(self : BusAnalyzer) -> Unit {
  self.observations.clear()
  self.last_timestamp_us = None
  self.last_sequence = None
}

///|
pub fn BusAnalyzer::observe(self : BusAnalyzer, item : BusObservation) -> Unit {
  self.observations.push(item)
  self.last_timestamp_us = Some(item.timestamp_us())
  self.last_sequence = Some(item.sequence())
}

///|
pub fn BusAnalyzer::observe_frame(
  self : BusAnalyzer,
  timestamp_us : UInt64,
  frame : Frame,
) -> Unit {
  let sequence = self.observations.length().reinterpret_as_uint()
  self.observe(
    bus_observation(timestamp_us, frame, channel=self.channel, sequence~),
  )
}

///|
pub fn BusAnalyzer::sorted_observations(
  self : BusAnalyzer,
) -> Array[BusObservation] {
  let result = self.observations.copy()
  result.sort_by((left, right) => {
    if left.timestamp_us() < right.timestamp_us() {
      -1
    } else if left.timestamp_us() > right.timestamp_us() {
      1
    } else {
      left.sequence().reinterpret_as_int() -
      right.sequence().reinterpret_as_int()
    }
  })
  result
}

///|
pub fn BusAnalyzer::profile(
  self : BusAnalyzer,
  identifier : UInt,
) -> BusIdentifierProfile? {
  let items = self.sorted_observations()
  let selected = items.filter(item => item.frame().id() == identifier)
  if selected.is_empty() {
    None
  } else {
    let first = selected[0]
    let first_length = first.frame().data().length()
    let profile = {
      identifier,
      frames: selected.length(),
      first_seen_us: first.timestamp_us(),
      last_seen_us: selected[selected.length() - 1].timestamp_us(),
      min_payload: first_length,
      max_payload: first_length,
      wire_bits: 0,
      extended: first.frame().is_extended(),
      intervals: [],
    }
    for index, item in selected {
      profile.wire_bits += frame_wire_bits(item.frame())
      let length = item.frame().data().length()
      if length < profile.min_payload {
        profile.min_payload = length
      }
      if length > profile.max_payload {
        profile.max_payload = length
      }
      if index > 0 {
        profile.intervals.push(
          item.timestamp_us() - selected[index - 1].timestamp_us(),
        )
      }
    }
    Some(profile)
  }
}

///|
pub fn BusAnalyzer::profiles(self : BusAnalyzer) -> Array[BusIdentifierProfile] {
  let ids : Array[UInt] = []
  for item in self.observations {
    if !ids.contains(item.frame().id()) {
      ids.push(item.frame().id())
    }
  }
  ids.sort()
  let result : Array[BusIdentifierProfile] = []
  for id in ids {
    match self.profile(id) {
      Some(profile) => result.push(profile)
      None => ()
    }
  }
  result
}

///|
pub fn BusAnalyzer::anomalies(self : BusAnalyzer) -> Array[BusAnalysisAnomaly] {
  let result : Array[BusAnalysisAnomaly] = []
  let items = self.sorted_observations()
  match self.last_timestamp_us {
    Some(last) =>
      for item in items {
        if item.timestamp_us() > last + self.burst_window_us {
          break
        }
      }
    None => ()
  }
  for profile in self.profiles() {
    if profile.frames() > 100 {
      result.push(BusAnomalyBurst(profile.identifier(), profile.frames()))
    }
    if profile.jitter_us() > self.jitter_limit_us {
      result.push(BusAnomalyJitter(profile.identifier(), profile.jitter_us()))
    }
    if profile.min_payload() != profile.max_payload() &&
      profile.max_payload() - profile.min_payload() >= 4 {
      result.push(
        BusAnomalyPayloadGrowth(
          profile.identifier(),
          profile.min_payload(),
          profile.max_payload(),
        ),
      )
    }
  }
  for index, item in items {
    if index > 0 && item.timestamp_us() < items[index - 1].timestamp_us() {
      result.push(BusAnomalyTimestampRegression(item.timestamp_us()))
    }
    if index > 0 && item.sequence() > items[index - 1].sequence() + 1 {
      result.push(
        BusAnomalySequenceGap(items[index - 1].sequence() + 1, item.sequence()),
      )
    }
  }
  result
}

///|
pub fn BusAnalyzer::report(self : BusAnalyzer) -> BusAnalysisReport {
  let items = self.sorted_observations()
  let start_us : UInt64? = if items.is_empty() {
    None
  } else {
    Some(items[0].timestamp_us())
  }
  let end_us : UInt64? = if items.is_empty() {
    None
  } else {
    Some(items[items.length() - 1].timestamp_us())
  }
  let mut payload_bytes = 0
  let mut wire_bits = 0
  for item in items {
    payload_bytes += item.frame().data().length()
    wire_bits += frame_wire_bits(item.frame())
  }
  let utilization = match start_us {
    Some(start) =>
      match end_us {
        Some(end) =>
          if end == start || self.bitrate_kbps == 0 {
            0.0
          } else {
            wire_bits.to_double() *
            1000.0 /
            ((end - start).to_double() * self.bitrate_kbps.to_double())
          }
        None => 0.0
      }
    None => 0.0
  }
  {
    mode: self.mode,
    channel: self.channel,
    start_us,
    end_us,
    total_frames: self.observations.length(),
    payload_bytes,
    wire_bits,
    profiles: self.profiles(),
    anomalies: self.anomalies(),
    utilization,
  }
}

///|
/// Calculate a stable percentile from interval samples.
pub fn bus_interval_percentile(
  intervals : Array[UInt64],
  percentile : Int,
) -> UInt64 {
  if intervals.is_empty() {
    0
  } else {
    let result = intervals.copy()
    result.sort()
    let p = if percentile < 0 {
      0
    } else if percentile > 100 {
      100
    } else {
      percentile
    }
    let index = (result.length() - 1) * p / 100
    result[index]
  }
}

///|
/// Return one report for each channel represented by a trace.
pub fn bus_analysis_trace(
  trace : Trace,
  channel : String,
  mode? : BusAnalysisMode = BusAnalysisOffline,
  bitrate_kbps? : UInt = 500,
) -> BusAnalysisReport {
  let analyzer = new_bus_analyzer(mode, channel~, bitrate_kbps~)
  for index, entry in trace.entries() {
    analyzer.observe(
      bus_observation(
        entry.timestamp(),
        entry.frame(),
        channel~,
        sequence=index.reinterpret_as_uint(),
      ),
    )
  }
  analyzer.report()
}
