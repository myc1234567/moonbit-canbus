///|
/// Errors raised by a frame admission policy.
pub suberror AdmissionError {
  InvalidRule
  NoMatchingRule
  ProtocolNotAllowed
  PayloadTooLarge
  RemoteNotAllowed
  RateExceeded
  TimestampReversed
} derive(Debug)

///|
/// A named rule for a group of accepted frames.
pub struct AdmissionRule {
  name : String
  filter : Filter
  max_payload : Int
  allow_fd : Bool
  allow_remote : Bool
  min_interval_us : UInt64
  mut last_seen_us : UInt64?
}

///|
/// The result of an admission check.
pub struct AdmissionDecision {
  accepted : Bool
  rule_name : String
  reason : String
}

///|
/// A first-match frame admission policy with counters and timing guards.
pub struct AdmissionPolicy {
  rules : Array[AdmissionRule]
  mut accepted_count : Int
  mut rejected_count : Int
  mut last_timestamp_us : UInt64?
}

///|
/// Construct a policy rule.
pub fn admission_rule(
  name : String,
  filter : Filter,
  max_payload? : Int = 64,
  allow_fd? : Bool = true,
  allow_remote? : Bool = false,
  min_interval_us? : UInt64 = 0,
) -> AdmissionRule raise AdmissionError {
  if name.is_empty() || max_payload < 0 || max_payload > 64 {
    raise InvalidRule
  }
  {
    name,
    filter,
    max_payload,
    allow_fd,
    allow_remote,
    min_interval_us,
    last_seen_us: None,
  }
}

///|
pub fn new_admission_policy() -> AdmissionPolicy {
  { rules: [], accepted_count: 0, rejected_count: 0, last_timestamp_us: None }
}

///|
pub fn AdmissionPolicy::add_rule(
  self : AdmissionPolicy,
  rule : AdmissionRule,
) -> Unit {
  self.rules.push(rule)
}

///|
/// Evaluate the first matching rule and update its rate window on success.
pub fn AdmissionPolicy::evaluate(
  self : AdmissionPolicy,
  frame : Frame,
  timestamp_us : UInt64,
) -> AdmissionDecision raise AdmissionError {
  match self.last_timestamp_us {
    Some(previous) => if timestamp_us < previous { raise TimestampReversed }
    None => ()
  }
  self.last_timestamp_us = Some(timestamp_us)
  for index in 0..<self.rules.length() {
    if self.rules[index].filter.matches(frame) {
      let rule = self.rules[index]
      if frame.protocol() is CanFd && !rule.allow_fd {
        self.rejected_count += 1
        raise ProtocolNotAllowed
      }
      if frame.is_remote() && !rule.allow_remote {
        self.rejected_count += 1
        raise RemoteNotAllowed
      }
      if frame.data().length() > rule.max_payload {
        self.rejected_count += 1
        raise PayloadTooLarge
      }
      match rule.last_seen_us {
        Some(previous) => {
          if timestamp_us < previous {
            self.rejected_count += 1
            raise TimestampReversed
          }
          if rule.min_interval_us > 0 &&
            timestamp_us - previous < rule.min_interval_us {
            self.rejected_count += 1
            raise RateExceeded
          }
        }
        None => ()
      }
      self.rules[index].last_seen_us = Some(timestamp_us)
      self.accepted_count += 1
      return { accepted: true, rule_name: rule.name, reason: "accepted" }
    }
  }
  self.rejected_count += 1
  raise NoMatchingRule
}

///|
/// Return whether a frame is admitted, preserving the policy counters.
pub fn AdmissionPolicy::admit(
  self : AdmissionPolicy,
  frame : Frame,
  timestamp_us : UInt64,
) -> Bool {
  try self.evaluate(frame, timestamp_us) catch {
    _ => false
  } noraise {
    _ => true
  }
}

///|
/// Reset all per-rule timing windows and counters.
pub fn AdmissionPolicy::reset(self : AdmissionPolicy) -> Unit {
  for index in 0..<self.rules.length() {
    self.rules[index].last_seen_us = None
  }
  self.accepted_count = 0
  self.rejected_count = 0
  self.last_timestamp_us = None
}

///|
pub fn AdmissionPolicy::rule_count(self : AdmissionPolicy) -> Int {
  self.rules.length()
}

///|
pub fn AdmissionPolicy::accepted(self : AdmissionPolicy) -> Int {
  self.accepted_count
}

///|
pub fn AdmissionPolicy::rejected(self : AdmissionPolicy) -> Int {
  self.rejected_count
}

///|
pub fn AdmissionDecision::accepted(self : AdmissionDecision) -> Bool {
  self.accepted
}

///|
pub fn AdmissionDecision::rule_name(self : AdmissionDecision) -> String {
  self.rule_name
}

///|
pub fn AdmissionDecision::reason(self : AdmissionDecision) -> String {
  self.reason
}

///|
pub fn AdmissionRule::name(self : AdmissionRule) -> String {
  self.name
}

///|
pub fn AdmissionRule::max_payload(self : AdmissionRule) -> Int {
  self.max_payload
}

///|
pub fn AdmissionRule::allows_fd(self : AdmissionRule) -> Bool {
  self.allow_fd
}

///|
pub fn AdmissionRule::allows_remote(self : AdmissionRule) -> Bool {
  self.allow_remote
}

///|
pub fn AdmissionRule::minimum_interval(self : AdmissionRule) -> UInt64 {
  self.min_interval_us
}
