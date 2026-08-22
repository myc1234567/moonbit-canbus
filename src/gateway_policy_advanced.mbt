///|
/// Result of evaluating a gateway policy.
pub enum GatewayPolicyDecision {
  GatewayPolicyAllow
  GatewayPolicyDeny(String)
  GatewayPolicyRewrite(Frame)
  GatewayPolicyRateLimited
}

///|
pub fn gateway_policy_decision_variants() -> Array[GatewayPolicyDecision] {
  [
    GatewayPolicyAllow,
    GatewayPolicyDeny("example"),
    GatewayPolicyRewrite(error_frame(0)),
    GatewayPolicyRateLimited,
  ]
}

///|
/// A policy rule for a gateway direction.
pub struct GatewayPolicyRule {
  name : String
  filter : Filter
  output_id : UInt?
  prefix : Array[Byte]
  max_payload : Int
  min_interval_us : UInt64
  allow_remote : Bool
  mut enabled : Bool
  mut hits : Int
  mut denied : Int
  mut last_timestamp_us : UInt64?
}

///|
pub suberror GatewayPolicyError {
  GatewayPolicyInvalidPayload
  GatewayPolicyDuplicateRule
  GatewayPolicyRuleNotFound
  GatewayPolicyInvalidInterval
}

///|
pub fn gateway_policy_error_variants() -> Array[GatewayPolicyError] {
  [
    GatewayPolicyInvalidPayload,
    GatewayPolicyDuplicateRule,
    GatewayPolicyRuleNotFound,
    GatewayPolicyInvalidInterval,
  ]
}

///|
pub fn gateway_policy_rule(
  name : String,
  filter : Filter,
  output_id? : UInt? = None,
  prefix? : Array[Byte] = [],
  max_payload? : Int = 64,
  min_interval_us? : UInt64 = 0,
  allow_remote? : Bool = false,
) -> GatewayPolicyRule raise GatewayPolicyError {
  if max_payload < 0 || max_payload > 64 {
    raise GatewayPolicyInvalidPayload
  }
  if prefix.length() > max_payload {
    raise GatewayPolicyInvalidPayload
  }
  {
    name,
    filter,
    output_id,
    prefix: prefix.copy(),
    max_payload,
    min_interval_us,
    allow_remote,
    enabled: true,
    hits: 0,
    denied: 0,
    last_timestamp_us: None,
  }
}

///|
pub fn GatewayPolicyRule::name(self : GatewayPolicyRule) -> String {
  self.name
}

///|
pub fn GatewayPolicyRule::filter(self : GatewayPolicyRule) -> Filter {
  self.filter
}

///|
pub fn GatewayPolicyRule::output_id(self : GatewayPolicyRule) -> UInt? {
  self.output_id
}

///|
pub fn GatewayPolicyRule::prefix(self : GatewayPolicyRule) -> Array[Byte] {
  self.prefix.copy()
}

///|
pub fn GatewayPolicyRule::max_payload(self : GatewayPolicyRule) -> Int {
  self.max_payload
}

///|
pub fn GatewayPolicyRule::min_interval_us(self : GatewayPolicyRule) -> UInt64 {
  self.min_interval_us
}

///|
pub fn GatewayPolicyRule::allow_remote(self : GatewayPolicyRule) -> Bool {
  self.allow_remote
}

///|
pub fn GatewayPolicyRule::enabled(self : GatewayPolicyRule) -> Bool {
  self.enabled
}

///|
pub fn GatewayPolicyRule::hits(self : GatewayPolicyRule) -> Int {
  self.hits
}

///|
pub fn GatewayPolicyRule::denied(self : GatewayPolicyRule) -> Int {
  self.denied
}

///|
pub fn GatewayPolicyRule::set_enabled(
  self : GatewayPolicyRule,
  enabled : Bool,
) -> Unit {
  self.enabled = enabled
}

///|
pub fn GatewayPolicyRule::matches(
  self : GatewayPolicyRule,
  frame : Frame,
) -> Bool {
  self.enabled &&
  self.filter.matches(frame) &&
  frame.data().length() <= self.max_payload &&
  (self.allow_remote || !frame.is_remote())
}

///|
/// Apply the rewrite portion of a gateway policy rule.
pub fn GatewayPolicyRule::rewrite(
  self : GatewayPolicyRule,
  frame : Frame,
) -> Frame raise FrameError {
  let data = if self.prefix.is_empty() {
    frame.data()
  } else {
    self.prefix + frame.data()
  }
  let updated = frame_with_data(frame, data) catch {
    _ => raise FrameError::InvalidLength
  }
  match self.output_id {
    Some(id) =>
      frame_with_id(updated, id) catch {
        _ => raise FrameError::InvalidIdentifier
      }
    None => updated
  }
}

///|
/// A policy evaluation context used for audit and rate limiting.
pub struct GatewayPolicyContext {
  timestamp_us : UInt64
  source_channel : String
  destination_channel : String
  frame : Frame
}

///|
pub fn gateway_policy_context(
  timestamp_us : UInt64,
  source_channel : String,
  destination_channel : String,
  frame : Frame,
) -> GatewayPolicyContext {
  { timestamp_us, source_channel, destination_channel, frame }
}

///|
pub fn GatewayPolicyContext::timestamp_us(
  self : GatewayPolicyContext,
) -> UInt64 {
  self.timestamp_us
}

///|
pub fn GatewayPolicyContext::source_channel(
  self : GatewayPolicyContext,
) -> String {
  self.source_channel
}

///|
pub fn GatewayPolicyContext::destination_channel(
  self : GatewayPolicyContext,
) -> String {
  self.destination_channel
}

///|
pub fn GatewayPolicyContext::frame(self : GatewayPolicyContext) -> Frame {
  self.frame
}

///|
/// An immutable audit record produced by the policy engine.
pub struct GatewayPolicyAudit {
  timestamp_us : UInt64
  rule_name : String
  source_channel : String
  destination_channel : String
  decision : GatewayPolicyDecision
  input_id : UInt
  output_id : UInt?
}

///|
pub fn GatewayPolicyAudit::timestamp_us(self : GatewayPolicyAudit) -> UInt64 {
  self.timestamp_us
}

///|
pub fn GatewayPolicyAudit::rule_name(self : GatewayPolicyAudit) -> String {
  self.rule_name
}

///|
pub fn GatewayPolicyAudit::source_channel(self : GatewayPolicyAudit) -> String {
  self.source_channel
}

///|
pub fn GatewayPolicyAudit::destination_channel(
  self : GatewayPolicyAudit,
) -> String {
  self.destination_channel
}

///|
pub fn GatewayPolicyAudit::decision(
  self : GatewayPolicyAudit,
) -> GatewayPolicyDecision {
  self.decision
}

///|
pub fn GatewayPolicyAudit::input_id(self : GatewayPolicyAudit) -> UInt {
  self.input_id
}

///|
pub fn GatewayPolicyAudit::output_id(self : GatewayPolicyAudit) -> UInt? {
  self.output_id
}

///|
/// An ordered, rate-limited gateway policy engine.
pub struct GatewayPolicyEngine {
  rules : Array[GatewayPolicyRule]
  audits : Array[GatewayPolicyAudit]
  capacity : Int
  mut evaluated : Int
  mut allowed : Int
  mut denied : Int
  mut rewritten : Int
  mut rate_limited : Int
}

///|
pub fn new_gateway_policy_engine(capacity? : Int = 64) -> GatewayPolicyEngine {
  {
    rules: [],
    audits: [],
    capacity: if capacity < 1 {
      1
    } else {
      capacity
    },
    evaluated: 0,
    allowed: 0,
    denied: 0,
    rewritten: 0,
    rate_limited: 0,
  }
}

///|
pub fn GatewayPolicyEngine::add_rule(
  self : GatewayPolicyEngine,
  rule : GatewayPolicyRule,
) -> Bool {
  if self.rules.length() >= self.capacity || self.find(rule.name()) is Some(_) {
    false
  } else {
    self.rules.push(rule)
    true
  }
}

///|
pub fn GatewayPolicyEngine::remove_rule(
  self : GatewayPolicyEngine,
  name : String,
) -> Bool {
  match self.find_index(name) {
    Some(index) => {
      ignore(self.rules.remove(index))
      true
    }
    None => false
  }
}

///|
pub fn GatewayPolicyEngine::find(
  self : GatewayPolicyEngine,
  name : String,
) -> GatewayPolicyRule? {
  match self.find_index(name) {
    Some(index) => Some(self.rules[index])
    None => None
  }
}

///|
pub fn GatewayPolicyEngine::rules(
  self : GatewayPolicyEngine,
) -> Array[GatewayPolicyRule] {
  self.rules.copy()
}

///|
pub fn GatewayPolicyEngine::audits(
  self : GatewayPolicyEngine,
) -> Array[GatewayPolicyAudit] {
  self.audits.copy()
}

///|
pub fn GatewayPolicyEngine::evaluated(self : GatewayPolicyEngine) -> Int {
  self.evaluated
}

///|
pub fn GatewayPolicyEngine::allowed(self : GatewayPolicyEngine) -> Int {
  self.allowed
}

///|
pub fn GatewayPolicyEngine::denied(self : GatewayPolicyEngine) -> Int {
  self.denied
}

///|
pub fn GatewayPolicyEngine::rewritten(self : GatewayPolicyEngine) -> Int {
  self.rewritten
}

///|
pub fn GatewayPolicyEngine::rate_limited(self : GatewayPolicyEngine) -> Int {
  self.rate_limited
}

///|
pub fn GatewayPolicyEngine::reset(self : GatewayPolicyEngine) -> Unit {
  self.audits.clear()
  self.evaluated = 0
  self.allowed = 0
  self.denied = 0
  self.rewritten = 0
  self.rate_limited = 0
  for rule in self.rules {
    rule.hits = 0
    rule.denied = 0
    rule.last_timestamp_us = None
  }
}

///|
pub fn GatewayPolicyEngine::evaluate(
  self : GatewayPolicyEngine,
  context : GatewayPolicyContext,
) -> GatewayPolicyDecision {
  self.evaluated += 1
  for rule in self.rules {
    if rule.matches(context.frame()) {
      let limited = match rule.last_timestamp_us {
        Some(last) => context.timestamp_us() < last + rule.min_interval_us()
        None => false
      }
      if limited {
        rule.denied += 1
        self.rate_limited += 1
        let decision = GatewayPolicyRateLimited
        self.record_audit(context, rule, decision, None)
        return decision
      }
      rule.last_timestamp_us = Some(context.timestamp_us())
      rule.hits += 1
      let decision = if rule.output_id() is Some(_) || !rule.prefix().is_empty() {
        let updated = Some(rule.rewrite(context.frame())) catch { _ => None }
        match updated {
          Some(frame) => GatewayPolicyRewrite(frame)
          None => GatewayPolicyDeny("invalid rewrite")
        }
      } else {
        GatewayPolicyAllow
      }
      match decision {
        GatewayPolicyAllow => self.allowed += 1
        GatewayPolicyRewrite(_) => self.rewritten += 1
        _ => ()
      }
      let output_id = match decision {
        GatewayPolicyRewrite(frame) => Some(frame.id())
        _ => None
      }
      self.record_audit(context, rule, decision, output_id)
      return decision
    }
  }
  self.denied += 1
  let decision = GatewayPolicyDeny("no matching policy")
  self.record_audit(context, self.default_rule(), decision, None)
  decision
}

///|
pub fn GatewayPolicyEngine::forward(
  self : GatewayPolicyEngine,
  context : GatewayPolicyContext,
) -> Frame? {
  match self.evaluate(context) {
    GatewayPolicyAllow => Some(context.frame())
    GatewayPolicyRewrite(frame) => Some(frame)
    _ => None
  }
}

///|
pub fn GatewayPolicyEngine::audit_count(self : GatewayPolicyEngine) -> Int {
  self.audits.length()
}

///|
pub fn GatewayPolicyEngine::to_text(self : GatewayPolicyEngine) -> String {
  "rules=" +
  self.rules.length().to_string() +
  " evaluated=" +
  self.evaluated.to_string() +
  " allowed=" +
  self.allowed.to_string() +
  " denied=" +
  self.denied.to_string() +
  " rewritten=" +
  self.rewritten.to_string() +
  " limited=" +
  self.rate_limited.to_string()
}

///|
fn GatewayPolicyEngine::record_audit(
  self : GatewayPolicyEngine,
  context : GatewayPolicyContext,
  rule : GatewayPolicyRule,
  decision : GatewayPolicyDecision,
  output_id : UInt?,
) -> Unit {
  self.audits.push({
    timestamp_us: context.timestamp_us(),
    rule_name: rule.name(),
    source_channel: context.source_channel(),
    destination_channel: context.destination_channel(),
    decision,
    input_id: context.frame().id(),
    output_id,
  })
}

///|
fn GatewayPolicyEngine::default_rule(
  self : GatewayPolicyEngine,
) -> GatewayPolicyRule {
  ignore(self)
  gateway_policy_rule("default", exact_filter(0xFFFFFFFF), max_payload=64) catch {
    _ => panic()
  }
}

///|
fn GatewayPolicyEngine::find_index(
  self : GatewayPolicyEngine,
  name : String,
) -> Int? {
  for index, rule in self.rules {
    if rule.name() == name {
      return Some(index)
    }
  }
  None
}

///|
/// Evaluate one frame against a pair of channel-specific engines.
pub fn gateway_policy_pair(
  left : GatewayPolicyEngine,
  right : GatewayPolicyEngine,
  source : String,
  destination : String,
  timestamp_us : UInt64,
  frame : Frame,
) -> Frame? {
  ignore(right)
  let context = gateway_policy_context(timestamp_us, source, destination, frame)
  left.forward(context)
}

///|
/// Return a stable policy decision label.
pub fn gateway_policy_decision_text(decision : GatewayPolicyDecision) -> String {
  match decision {
    GatewayPolicyAllow => "allow"
    GatewayPolicyDeny(reason) => "deny:" + reason
    GatewayPolicyRewrite(frame) => "rewrite:" + frame.id().to_string()
    GatewayPolicyRateLimited => "rate-limited"
  }
}
