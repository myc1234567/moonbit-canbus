///|
/// Action applied by a deterministic frame-processing rule.
pub(all) enum FramePipelineAction {
  FramePipelineForward
  FramePipelineDrop(String)
  FramePipelineRewriteId(UInt)
  FramePipelinePrefix(Array[Byte])
  FramePipelineReplaceData(Array[Byte])
}

///|
pub fn frame_pipeline_action_variants() -> Array[FramePipelineAction] {
  [
    FramePipelineForward,
    FramePipelineDrop("example"),
    FramePipelineRewriteId(0),
    FramePipelinePrefix([]),
    FramePipelineReplaceData([]),
  ]
}

///|
/// A named frame-processing rule.
pub struct FramePipelineRule {
  name : String
  filter : Filter
  action : FramePipelineAction
  max_payload : Int
  allow_fd : Bool
  mut enabled : Bool
  mut hits : Int
}

///|
pub suberror FramePipelineError {
  FramePipelineInvalidPayload
  FramePipelineRuleExists
  FramePipelineRuleMissing
  FramePipelineCapacity
}

///|
pub fn frame_pipeline_rule(
  name : String,
  filter : Filter,
  action : FramePipelineAction,
  max_payload? : Int = 64,
  allow_fd? : Bool = true,
) -> FramePipelineRule raise FramePipelineError {
  if max_payload < 0 || max_payload > 64 {
    raise FramePipelineInvalidPayload
  }
  { name, filter, action, max_payload, allow_fd, enabled: true, hits: 0 }
}

///|
pub fn FramePipelineRule::name(self : FramePipelineRule) -> String {
  self.name
}

///|
pub fn FramePipelineRule::filter(self : FramePipelineRule) -> Filter {
  self.filter
}

///|
pub fn FramePipelineRule::action(
  self : FramePipelineRule,
) -> FramePipelineAction {
  self.action
}

///|
pub fn FramePipelineRule::max_payload(self : FramePipelineRule) -> Int {
  self.max_payload
}

///|
pub fn FramePipelineRule::allow_fd(self : FramePipelineRule) -> Bool {
  self.allow_fd
}

///|
pub fn FramePipelineRule::enabled(self : FramePipelineRule) -> Bool {
  self.enabled
}

///|
pub fn FramePipelineRule::hits(self : FramePipelineRule) -> Int {
  self.hits
}

///|
pub fn FramePipelineRule::set_enabled(
  self : FramePipelineRule,
  enabled : Bool,
) -> Unit {
  self.enabled = enabled
}

///|
pub fn FramePipelineRule::matches(
  self : FramePipelineRule,
  frame : Frame,
) -> Bool {
  self.enabled &&
  self.filter.matches(frame) &&
  frame.data().length() <= self.max_payload &&
  (self.allow_fd || frame.protocol() is Can20)
}

///|
/// Result emitted by one pipeline invocation.
pub(all) enum FramePipelineResult {
  FramePipelineAccepted(Frame, String)
  FramePipelineRejected(String)
  FramePipelineUnmatched(Frame)
}

///|
pub fn frame_pipeline_result_variants() -> Array[FramePipelineResult] {
  [
    FramePipelineAccepted(error_frame(0), "example"),
    FramePipelineRejected("example"),
    FramePipelineUnmatched(error_frame(0)),
  ]
}

///|
/// A deterministic ordered frame-processing pipeline.
pub struct FramePipeline {
  rules : Array[FramePipelineRule]
  capacity : Int
  mut processed : Int
  mut accepted : Int
  mut rejected : Int
  mut unmatched : Int
  mut failures : Int
}

///|
pub fn new_frame_pipeline(capacity? : Int = 64) -> FramePipeline {
  {
    rules: [],
    capacity: if capacity < 1 {
      1
    } else {
      capacity
    },
    processed: 0,
    accepted: 0,
    rejected: 0,
    unmatched: 0,
    failures: 0,
  }
}

///|
pub fn FramePipeline::add_rule(
  self : FramePipeline,
  rule : FramePipelineRule,
) -> Unit raise FramePipelineError {
  if self.rules.length() >= self.capacity {
    raise FramePipelineCapacity
  }
  if self.find(rule.name()) is Some(_) {
    raise FramePipelineRuleExists
  }
  self.rules.push(rule)
}

///|
pub fn FramePipeline::remove_rule(
  self : FramePipeline,
  name : String,
) -> Unit raise FramePipelineError {
  match self.find_index(name) {
    Some(index) => ignore(self.rules.remove(index))
    None => raise FramePipelineRuleMissing
  }
}

///|
pub fn FramePipeline::find(
  self : FramePipeline,
  name : String,
) -> FramePipelineRule? {
  match self.find_index(name) {
    Some(index) => Some(self.rules[index])
    None => None
  }
}

///|
pub fn FramePipeline::rules(self : FramePipeline) -> Array[FramePipelineRule] {
  self.rules.copy()
}

///|
pub fn FramePipeline::processed(self : FramePipeline) -> Int {
  self.processed
}

///|
pub fn FramePipeline::accepted(self : FramePipeline) -> Int {
  self.accepted
}

///|
pub fn FramePipeline::rejected(self : FramePipeline) -> Int {
  self.rejected
}

///|
pub fn FramePipeline::unmatched(self : FramePipeline) -> Int {
  self.unmatched
}

///|
pub fn FramePipeline::failures(self : FramePipeline) -> Int {
  self.failures
}

///|
pub fn FramePipeline::reset_counters(self : FramePipeline) -> Unit {
  self.processed = 0
  self.accepted = 0
  self.rejected = 0
  self.unmatched = 0
  self.failures = 0
  for rule in self.rules {
    rule.hits = 0
  }
}

///|
pub fn FramePipeline::process(
  self : FramePipeline,
  frame : Frame,
) -> FramePipelineResult {
  self.processed += 1
  for rule in self.rules {
    if rule.matches(frame) {
      rule.hits += 1
      let result = match rule.action() {
        FramePipelineForward => FramePipelineAccepted(frame, rule.name())
        FramePipelineDrop(reason) => FramePipelineRejected(reason)
        FramePipelineRewriteId(id) => {
          let updated = Some(frame_with_id(frame, id)) catch { _ => None }
          match updated {
            Some(value) => FramePipelineAccepted(value, rule.name())
            None => FramePipelineRejected("invalid rewritten identifier")
          }
        }
        FramePipelinePrefix(prefix) => {
          let data = prefix + frame.data()
          let updated = Some(frame_with_data(frame, data)) catch { _ => None }
          match updated {
            Some(value) => FramePipelineAccepted(value, rule.name())
            None => FramePipelineRejected("invalid prefixed payload")
          }
        }
        FramePipelineReplaceData(data) => {
          let updated = Some(frame_with_data(frame, data)) catch { _ => None }
          match updated {
            Some(value) => FramePipelineAccepted(value, rule.name())
            None => FramePipelineRejected("invalid replacement payload")
          }
        }
      }
      match result {
        FramePipelineAccepted(_, _) => self.accepted += 1
        FramePipelineRejected(_) => self.rejected += 1
        FramePipelineUnmatched(_) => self.unmatched += 1
      }
      return result
    }
  }
  self.unmatched += 1
  FramePipelineUnmatched(frame)
}

///|
pub fn FramePipeline::process_batch(
  self : FramePipeline,
  frames : Array[Frame],
) -> Array[Frame] {
  let result : Array[Frame] = []
  for frame in frames {
    match self.process(frame) {
      FramePipelineAccepted(updated, _) => result.push(updated)
      _ => ()
    }
  }
  result
}

///|
pub fn FramePipeline::to_text(self : FramePipeline) -> String {
  "rules=" +
  self.rules.length().to_string() +
  " processed=" +
  self.processed.to_string() +
  " accepted=" +
  self.accepted.to_string() +
  " rejected=" +
  self.rejected.to_string() +
  " unmatched=" +
  self.unmatched.to_string()
}

///|
fn FramePipeline::find_index(self : FramePipeline, name : String) -> Int? {
  for index, rule in self.rules {
    if rule.name() == name {
      return Some(index)
    }
  }
  None
}

///|
/// A duplicate detector for cyclic frames.
pub struct FrameDeduplicator {
  last : Array[(UInt, Array[Byte])]
  window_us : UInt64
  mut duplicates : Int
  mut unique : Int
}

///|
pub fn new_frame_deduplicator(window_us? : UInt64 = 1_000) -> FrameDeduplicator {
  { last: [], window_us, duplicates: 0, unique: 0 }
}

///|
pub fn FrameDeduplicator::duplicates(self : FrameDeduplicator) -> Int {
  self.duplicates
}

///|
pub fn FrameDeduplicator::unique(self : FrameDeduplicator) -> Int {
  self.unique
}

///|
pub fn FrameDeduplicator::reset(self : FrameDeduplicator) -> Unit {
  self.last.clear()
  self.duplicates = 0
  self.unique = 0
}

///|
pub fn FrameDeduplicator::accept(
  self : FrameDeduplicator,
  timestamp_us : UInt64,
  frame : Frame,
) -> Bool {
  let data = frame.data()
  for index, item in self.last {
    if item.0 == frame.id() {
      let duplicate = item.1 == data
      self.last[index] = (frame.id(), data)
      if duplicate {
        self.duplicates += 1
        return false
      }
      self.unique += 1
      return true
    }
  }
  self.last.push((frame.id(), data))
  self.unique += 1
  ignore(timestamp_us)
  true
}

///|
/// A simple per-identifier rate limiter.
pub struct FrameRateLimiter {
  intervals : Array[(UInt, UInt64)]
  last_sent : Array[(UInt, UInt64)]
  mut allowed : Int
  mut limited : Int
}

///|
pub fn new_frame_rate_limiter() -> FrameRateLimiter {
  { intervals: [], last_sent: [], allowed: 0, limited: 0 }
}

///|
pub fn FrameRateLimiter::set_interval(
  self : FrameRateLimiter,
  identifier : UInt,
  interval_us : UInt64,
) -> Unit {
  for index, item in self.intervals {
    if item.0 == identifier {
      self.intervals[index] = (identifier, interval_us)
      return
    }
  }
  self.intervals.push((identifier, interval_us))
}

///|
pub fn FrameRateLimiter::allow(
  self : FrameRateLimiter,
  identifier : UInt,
  timestamp_us : UInt64,
) -> Bool {
  let interval = match self.find_interval(identifier) {
    Some(value) => value
    None => 0
  }
  match self.find_last(identifier) {
    Some(last) =>
      if timestamp_us < last + interval {
        self.limited += 1
        false
      } else {
        self.update_last(identifier, timestamp_us)
        self.allowed += 1
        true
      }
    None => {
      self.last_sent.push((identifier, timestamp_us))
      self.allowed += 1
      true
    }
  }
}

///|
pub fn FrameRateLimiter::allowed(self : FrameRateLimiter) -> Int {
  self.allowed
}

///|
pub fn FrameRateLimiter::limited(self : FrameRateLimiter) -> Int {
  self.limited
}

///|
pub fn FrameRateLimiter::reset(self : FrameRateLimiter) -> Unit {
  self.last_sent.clear()
  self.allowed = 0
  self.limited = 0
}

///|
fn FrameRateLimiter::find_interval(
  self : FrameRateLimiter,
  identifier : UInt,
) -> UInt64? {
  for item in self.intervals {
    if item.0 == identifier {
      return Some(item.1)
    }
  }
  None
}

///|
fn FrameRateLimiter::find_last(
  self : FrameRateLimiter,
  identifier : UInt,
) -> UInt64? {
  for item in self.last_sent {
    if item.0 == identifier {
      return Some(item.1)
    }
  }
  None
}

///|
fn FrameRateLimiter::update_last(
  self : FrameRateLimiter,
  identifier : UInt,
  timestamp_us : UInt64,
) -> Unit {
  for index, item in self.last_sent {
    if item.0 == identifier {
      self.last_sent[index] = (identifier, timestamp_us)
      return
    }
  }
  self.last_sent.push((identifier, timestamp_us))
}

///|
/// A rolling batch window for aggregating frames before analysis.
pub struct FramePipelineWindow {
  mut start_us : UInt64?
  duration_us : UInt64
  frames : Array[Frame]
  mut closed : Bool
}

///|
pub fn new_frame_pipeline_window(duration_us : UInt64) -> FramePipelineWindow {
  { start_us: None, duration_us, frames: [], closed: false }
}

///|
pub fn FramePipelineWindow::start_us(self : FramePipelineWindow) -> UInt64? {
  self.start_us
}

///|
pub fn FramePipelineWindow::duration_us(self : FramePipelineWindow) -> UInt64 {
  self.duration_us
}

///|
pub fn FramePipelineWindow::length(self : FramePipelineWindow) -> Int {
  self.frames.length()
}

///|
pub fn FramePipelineWindow::closed(self : FramePipelineWindow) -> Bool {
  self.closed
}

///|
pub fn FramePipelineWindow::push(
  self : FramePipelineWindow,
  timestamp_us : UInt64,
  frame : Frame,
) -> Bool {
  if self.closed {
    false
  } else {
    match self.start_us {
      None => {
        self.start_us = Some(timestamp_us)
        self.frames.push(frame)
        true
      }
      Some(start) =>
        if timestamp_us <= start + self.duration_us {
          self.frames.push(frame)
          true
        } else {
          self.closed = true
          false
        }
    }
  }
}

///|
pub fn FramePipelineWindow::frames(self : FramePipelineWindow) -> Array[Frame] {
  self.frames.copy()
}

///|
pub fn FramePipelineWindow::close(self : FramePipelineWindow) -> Unit {
  self.closed = true
}

///|
pub fn FramePipelineWindow::metrics(self : FramePipelineWindow) -> FrameMetrics {
  frame_metrics(self.frames)
}

///|
/// Run a pipeline and rate limiter together over a timestamped batch.
pub fn process_frame_batch(
  pipeline : FramePipeline,
  limiter : FrameRateLimiter,
  frames : Array[(UInt64, Frame)],
) -> Array[Frame] {
  let result : Array[Frame] = []
  for item in frames {
    if limiter.allow(item.1.id(), item.0) {
      match pipeline.process(item.1) {
        FramePipelineAccepted(frame, _) => result.push(frame)
        _ => ()
      }
    }
  }
  result
}
