///|
/// A predicate for selecting frames from a capture trace.
pub enum TraceQueryPredicate {
  TraceQueryAny
  TraceQueryIdentifier(UInt)
  TraceQueryExtended(Bool)
  TraceQueryProtocol(Protocol)
  TraceQueryFrameClass(FrameClass)
  TraceQueryPayloadLength(Int)
  TraceQueryPayloadAtLeast(Int)
  TraceQueryPayloadByte(Int, Byte)
  TraceQueryIdentifierRange(UInt, UInt)
}

///|
pub fn trace_query_predicate_variants() -> Array[TraceQueryPredicate] {
  [
    TraceQueryAny,
    TraceQueryIdentifier(0),
    TraceQueryExtended(false),
    TraceQueryProtocol(Can20),
    TraceQueryFrameClass(ClassicData),
    TraceQueryPayloadLength(0),
    TraceQueryPayloadAtLeast(0),
    TraceQueryPayloadByte(0, 0),
    TraceQueryIdentifierRange(0, 1),
  ]
}

///|
/// A time and predicate specification for trace analysis.
pub struct TraceQuerySpec {
  mut start_us : UInt64?
  mut end_us : UInt64?
  predicates : Array[TraceQueryPredicate]
  mut inspected : Int
  mut matched : Int
}

///|
pub fn new_trace_query() -> TraceQuerySpec {
  { start_us: None, end_us: None, predicates: [], inspected: 0, matched: 0 }
}

///|
pub fn TraceQuerySpec::between(
  self : TraceQuerySpec,
  start_us : UInt64,
  end_us : UInt64,
) -> Unit {
  self.start_us = Some(start_us)
  self.end_us = Some(end_us)
}

///|
pub fn TraceQuerySpec::after(self : TraceQuerySpec, start_us : UInt64) -> Unit {
  self.start_us = Some(start_us)
}

///|
pub fn TraceQuerySpec::before(self : TraceQuerySpec, end_us : UInt64) -> Unit {
  self.end_us = Some(end_us)
}

///|
pub fn TraceQuerySpec::where_is(
  self : TraceQuerySpec,
  predicate : TraceQueryPredicate,
) -> Unit {
  self.predicates.push(predicate)
}

///|
pub fn TraceQuerySpec::predicates(
  self : TraceQuerySpec,
) -> Array[TraceQueryPredicate] {
  self.predicates.copy()
}

///|
pub fn TraceQuerySpec::inspected(self : TraceQuerySpec) -> Int {
  self.inspected
}

///|
pub fn TraceQuerySpec::matched(self : TraceQuerySpec) -> Int {
  self.matched
}

///|
pub fn TraceQuerySpec::reset_counters(self : TraceQuerySpec) -> Unit {
  self.inspected = 0
  self.matched = 0
}

///|
/// A selected trace entry with its original position.
pub struct TraceQueryMatch {
  index : Int
  timestamp_us : UInt64
  frame : Frame
}

///|
pub fn TraceQueryMatch::index(self : TraceQueryMatch) -> Int {
  self.index
}

///|
pub fn TraceQueryMatch::timestamp_us(self : TraceQueryMatch) -> UInt64 {
  self.timestamp_us
}

///|
pub fn TraceQueryMatch::frame(self : TraceQueryMatch) -> Frame {
  self.frame
}

///|
pub fn TraceQueryMatch::latency_from(
  self : TraceQueryMatch,
  timestamp_us : UInt64,
) -> UInt64 {
  if self.timestamp_us >= timestamp_us {
    self.timestamp_us - timestamp_us
  } else {
    0
  }
}

///|
/// Return whether a frame matches one predicate.
pub fn trace_query_matches_predicate(
  frame : Frame,
  predicate : TraceQueryPredicate,
) -> Bool {
  match predicate {
    TraceQueryAny => true
    TraceQueryIdentifier(id) => frame.id() == id
    TraceQueryExtended(extended) => frame.is_extended() == extended
    TraceQueryProtocol(protocol) =>
      trace_query_protocol_equal(frame.protocol(), protocol)
    TraceQueryFrameClass(class) =>
      trace_query_class_equal(classify_frame(frame), class)
    TraceQueryPayloadLength(length) => frame.data().length() == length
    TraceQueryPayloadAtLeast(length) => frame.data().length() >= length
    TraceQueryPayloadByte(index, value) =>
      match frame.data().get(index) {
        Some(actual) => actual == value
        None => false
      }
    TraceQueryIdentifierRange(start, end) =>
      frame.id() >= start && frame.id() <= end
  }
}

///|
pub fn trace_query_matches(
  frame : Frame,
  predicates : Array[TraceQueryPredicate],
) -> Bool {
  for predicate in predicates {
    if !trace_query_matches_predicate(frame, predicate) {
      return false
    }
  }
  true
}

///|
fn trace_query_protocol_equal(left : Protocol, right : Protocol) -> Bool {
  match left {
    Can20 =>
      match right {
        Can20 => true
        _ => false
      }
    CanFd =>
      match right {
        CanFd => true
        _ => false
      }
  }
}

///|
fn trace_query_class_equal(left : FrameClass, right : FrameClass) -> Bool {
  match left {
    ClassicData =>
      match right {
        ClassicData => true
        _ => false
      }
    ClassicRemote =>
      match right {
        ClassicRemote => true
        _ => false
      }
    CanFdData =>
      match right {
        CanFdData => true
        _ => false
      }
    SimulationError =>
      match right {
        SimulationError => true
        _ => false
      }
  }
}

///|
/// Select entries from a trace without changing capture order.
pub fn trace_query(
  trace : Trace,
  query : TraceQuerySpec,
) -> Array[TraceQueryMatch] {
  query.reset_counters()
  let result : Array[TraceQueryMatch] = []
  for index, entry in trace.entries() {
    query.inspected += 1
    let after_start = match query.start_us {
      Some(start) => entry.timestamp() >= start
      None => true
    }
    let before_end = match query.end_us {
      Some(end) => entry.timestamp() <= end
      None => true
    }
    if after_start &&
      before_end &&
      trace_query_matches(entry.frame(), query.predicates) {
      query.matched += 1
      result.push({
        index,
        timestamp_us: entry.timestamp(),
        frame: entry.frame(),
      })
    }
  }
  result
}

///|
/// Return the first query match, if any.
pub fn trace_query_first(
  trace : Trace,
  query : TraceQuerySpec,
) -> TraceQueryMatch? {
  let result = trace_query(trace, query)
  result.get(0)
}

///|
/// Return the last query match, if any.
pub fn trace_query_last(
  trace : Trace,
  query : TraceQuerySpec,
) -> TraceQueryMatch? {
  let result = trace_query(trace, query)
  if result.is_empty() {
    None
  } else {
    Some(result[result.length() - 1])
  }
}

///|
/// Count frames by identifier in a query result.
pub fn trace_query_identifier_counts(
  matches : Array[TraceQueryMatch],
) -> Array[(UInt, Int)] {
  let result : Array[(UInt, Int)] = []
  for item in matches {
    let mut found = false
    for index, pair in result {
      if pair.0 == item.frame().id() {
        result[index] = (pair.0, pair.1 + 1)
        found = true
        break
      }
    }
    if !found {
      result.push((item.frame().id(), 1))
    }
  }
  result.sort_by((left, right) => {
    if left.0 < right.0 {
      -1
    } else if left.0 > right.0 {
      1
    } else {
      0
    }
  })
  result
}

///|
/// A fixed time bucket for frame-rate and load dashboards.
pub struct TraceQueryBucket {
  start_us : UInt64
  end_us : UInt64
  mut frames : Int
  mut payload_bytes : Int
  mut wire_bits : Int
}

///|
pub fn TraceQueryBucket::start_us(self : TraceQueryBucket) -> UInt64 {
  self.start_us
}

///|
pub fn TraceQueryBucket::end_us(self : TraceQueryBucket) -> UInt64 {
  self.end_us
}

///|
pub fn TraceQueryBucket::frames(self : TraceQueryBucket) -> Int {
  self.frames
}

///|
pub fn TraceQueryBucket::payload_bytes(self : TraceQueryBucket) -> Int {
  self.payload_bytes
}

///|
pub fn TraceQueryBucket::wire_bits(self : TraceQueryBucket) -> Int {
  self.wire_bits
}

///|
pub fn TraceQueryBucket::utilization(
  self : TraceQueryBucket,
  bitrate_kbps : UInt,
) -> Double {
  let duration = self.end_us - self.start_us
  if duration == 0 || bitrate_kbps == 0 {
    0.0
  } else {
    self.wire_bits.to_double() *
    1000.0 /
    (duration.to_double() * bitrate_kbps.to_double())
  }
}

///|
/// Partition a trace into fixed-width buckets.
pub fn trace_query_buckets(
  trace : Trace,
  start_us : UInt64,
  end_us : UInt64,
  bucket_us : UInt64,
) -> Array[TraceQueryBucket] {
  if bucket_us == 0 || end_us <= start_us {
    []
  } else {
    let count = ((end_us - start_us + bucket_us - 1) / bucket_us).to_int()
    let buckets : Array[TraceQueryBucket] = []
    for index in 0..<count {
      buckets.push({
        start_us: start_us + index.to_uint64() * bucket_us,
        end_us: if start_us + (index.to_uint64() + 1) * bucket_us > end_us {
          end_us
        } else {
          start_us + (index.to_uint64() + 1) * bucket_us
        },
        frames: 0,
        payload_bytes: 0,
        wire_bits: 0,
      })
    }
    for entry in trace.entries() {
      if entry.timestamp() >= start_us && entry.timestamp() < end_us {
        let index = ((entry.timestamp() - start_us) / bucket_us).to_int()
        if index < buckets.length() {
          buckets[index].frames += 1
          buckets[index].payload_bytes += entry.frame().data().length()
          buckets[index].wire_bits += frame_wire_bits(entry.frame())
        }
      }
    }
    buckets
  }
}

///|
/// A normalized replay event with a relative timestamp.
pub struct TraceReplayEvent {
  offset_us : UInt64
  frame : Frame
  original_index : Int
}

///|
pub fn TraceReplayEvent::offset_us(self : TraceReplayEvent) -> UInt64 {
  self.offset_us
}

///|
pub fn TraceReplayEvent::frame(self : TraceReplayEvent) -> Frame {
  self.frame
}

///|
pub fn TraceReplayEvent::original_index(self : TraceReplayEvent) -> Int {
  self.original_index
}

///|
/// A replay plan that supports deterministic time scaling and filtering.
pub struct TraceReplayPlan {
  events : Array[TraceReplayEvent]
  scale_num : UInt64
  scale_den : UInt64
  mut cursor : Int
}

///|
pub fn trace_replay_plan(
  trace : Trace,
  scale_num? : UInt64 = 1,
  scale_den? : UInt64 = 1,
) -> TraceReplayPlan {
  let entries = trace.entries()
  let base : UInt64 = if entries.is_empty() {
    0
  } else {
    entries[0].timestamp()
  }
  let numerator : UInt64 = if scale_num == 0 { 1 } else { scale_num }
  let denominator : UInt64 = if scale_den == 0 { 1 } else { scale_den }
  let events : Array[TraceReplayEvent] = []
  for index, entry in entries {
    let delta = if entry.timestamp() >= base {
      entry.timestamp() - base
    } else {
      0
    }
    events.push({
      offset_us: delta * denominator / numerator,
      frame: entry.frame(),
      original_index: index,
    })
  }
  { events, scale_num: numerator, scale_den: denominator, cursor: 0 }
}

///|
pub fn TraceReplayPlan::events(
  self : TraceReplayPlan,
) -> Array[TraceReplayEvent] {
  self.events.copy()
}

///|
pub fn TraceReplayPlan::scale_num(self : TraceReplayPlan) -> UInt64 {
  self.scale_num
}

///|
pub fn TraceReplayPlan::scale_den(self : TraceReplayPlan) -> UInt64 {
  self.scale_den
}

///|
pub fn TraceReplayPlan::cursor(self : TraceReplayPlan) -> Int {
  self.cursor
}

///|
pub fn TraceReplayPlan::reset(self : TraceReplayPlan) -> Unit {
  self.cursor = 0
}

///|
pub fn TraceReplayPlan::next(self : TraceReplayPlan) -> TraceReplayEvent? {
  if self.cursor >= self.events.length() {
    None
  } else {
    let result = self.events[self.cursor]
    self.cursor += 1
    Some(result)
  }
}

///|
pub fn TraceReplayPlan::at(
  self : TraceReplayPlan,
  offset_us : UInt64,
) -> Array[TraceReplayEvent] {
  let result : Array[TraceReplayEvent] = []
  for event in self.events {
    if event.offset_us() <= offset_us {
      result.push(event)
    } else {
      break
    }
  }
  result
}

///|
pub fn TraceReplayPlan::duration_us(self : TraceReplayPlan) -> UInt64 {
  if self.events.is_empty() {
    0
  } else {
    self.events[self.events.length() - 1].offset_us()
  }
}

///|
/// A difference between two captures at a matching ordinal.
pub enum TraceDiffKind {
  TraceDiffMissingLeft
  TraceDiffMissingRight
  TraceDiffIdentifier
  TraceDiffPayload
  TraceDiffTimestamp
}

///|
pub fn trace_diff_kind_variants() -> Array[TraceDiffKind] {
  [
    TraceDiffMissingLeft,
    TraceDiffMissingRight,
    TraceDiffIdentifier,
    TraceDiffPayload,
    TraceDiffTimestamp,
  ]
}

///|
pub struct TraceDiff {
  ordinal : Int
  kind : TraceDiffKind
  left : TraceQueryMatch?
  right : TraceQueryMatch?
}

///|
pub fn TraceDiff::ordinal(self : TraceDiff) -> Int {
  self.ordinal
}

///|
pub fn TraceDiff::kind(self : TraceDiff) -> TraceDiffKind {
  self.kind
}

///|
pub fn TraceDiff::left(self : TraceDiff) -> TraceQueryMatch? {
  self.left
}

///|
pub fn TraceDiff::right(self : TraceDiff) -> TraceQueryMatch? {
  self.right
}

///|
/// Compare two captures in order, reporting only observable differences.
pub fn trace_diff(
  left : Trace,
  right : Trace,
  compare_timestamp? : Bool = true,
) -> Array[TraceDiff] {
  let left_entries = left.entries()
  let right_entries = right.entries()
  let total = if left_entries.length() > right_entries.length() {
    left_entries.length()
  } else {
    right_entries.length()
  }
  let result : Array[TraceDiff] = []
  for ordinal in 0..<total {
    let left_match = if ordinal < left_entries.length() {
      Some({
        index: ordinal,
        timestamp_us: left_entries[ordinal].timestamp(),
        frame: left_entries[ordinal].frame(),
      })
    } else {
      None
    }
    let right_match = if ordinal < right_entries.length() {
      Some({
        index: ordinal,
        timestamp_us: right_entries[ordinal].timestamp(),
        frame: right_entries[ordinal].frame(),
      })
    } else {
      None
    }
    match left_match {
      None =>
        match right_match {
          None => ()
          Some(right_item) =>
            result.push({
              ordinal,
              kind: TraceDiffMissingLeft,
              left: None,
              right: Some(right_item),
            })
        }
      Some(left_item) =>
        match right_match {
          None =>
            result.push({
              ordinal,
              kind: TraceDiffMissingRight,
              left: Some(left_item),
              right: None,
            })
          Some(right_item) =>
            if left_item.frame().id() != right_item.frame().id() {
              result.push({
                ordinal,
                kind: TraceDiffIdentifier,
                left: Some(left_item),
                right: Some(right_item),
              })
            } else if left_item.frame().data() != right_item.frame().data() {
              result.push({
                ordinal,
                kind: TraceDiffPayload,
                left: Some(left_item),
                right: Some(right_item),
              })
            } else if compare_timestamp &&
              left_item.timestamp_us() != right_item.timestamp_us() {
              result.push({
                ordinal,
                kind: TraceDiffTimestamp,
                left: Some(left_item),
                right: Some(right_item),
              })
            }
        }
    }
  }
  result
}

///|
/// Return a stable textual summary of a trace query.
pub fn trace_query_summary(matches : Array[TraceQueryMatch]) -> String {
  let counts = trace_query_identifier_counts(matches)
  let parts : Array[String] = []
  for item in counts {
    parts.push(item.0.to_string() + ":" + item.1.to_string())
  }
  "matches=" + matches.length().to_string() + " ids=" + parts.join(",")
}
