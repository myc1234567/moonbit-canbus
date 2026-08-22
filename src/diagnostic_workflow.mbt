///|
/// State of a deterministic diagnostic workflow.
pub enum DiagnosticWorkflowState {
  DiagnosticWorkflowIdle
  DiagnosticWorkflowRunning
  DiagnosticWorkflowWaiting
  DiagnosticWorkflowSucceeded
  DiagnosticWorkflowFailed
  DiagnosticWorkflowCancelled
}

///|
pub fn diagnostic_workflow_state_variants() -> Array[DiagnosticWorkflowState] {
  [
    DiagnosticWorkflowIdle,
    DiagnosticWorkflowRunning,
    DiagnosticWorkflowWaiting,
    DiagnosticWorkflowSucceeded,
    DiagnosticWorkflowFailed,
    DiagnosticWorkflowCancelled,
  ]
}

///|
/// Retry policy used by a diagnostic workflow step.
pub struct DiagnosticRetryPolicy {
  max_attempts : Int
  backoff_us : UInt64
  retry_negative : Bool
  mut attempts : Int
}

///|
pub fn diagnostic_retry_policy(
  max_attempts? : Int = 1,
  backoff_us? : UInt64 = 0,
  retry_negative? : Bool = false,
) -> DiagnosticRetryPolicy {
  {
    max_attempts: if max_attempts < 1 {
      1
    } else {
      max_attempts
    },
    backoff_us,
    retry_negative,
    attempts: 0,
  }
}

///|
pub fn DiagnosticRetryPolicy::max_attempts(self : DiagnosticRetryPolicy) -> Int {
  self.max_attempts
}

///|
pub fn DiagnosticRetryPolicy::backoff_us(
  self : DiagnosticRetryPolicy,
) -> UInt64 {
  self.backoff_us
}

///|
pub fn DiagnosticRetryPolicy::retry_negative(
  self : DiagnosticRetryPolicy,
) -> Bool {
  self.retry_negative
}

///|
pub fn DiagnosticRetryPolicy::attempts(self : DiagnosticRetryPolicy) -> Int {
  self.attempts
}

///|
pub fn DiagnosticRetryPolicy::can_retry(self : DiagnosticRetryPolicy) -> Bool {
  self.attempts < self.max_attempts
}

///|
pub fn DiagnosticRetryPolicy::begin_attempt(
  self : DiagnosticRetryPolicy,
) -> Bool {
  if self.can_retry() {
    self.attempts += 1
    true
  } else {
    false
  }
}

///|
pub fn DiagnosticRetryPolicy::reset(self : DiagnosticRetryPolicy) -> Unit {
  self.attempts = 0
}

///|
/// One request scheduled in a diagnostic workflow.
pub struct DiagnosticWorkflowStep {
  name : String
  request : DiagnosticRequest
  timeout_us : UInt64
  retry : DiagnosticRetryPolicy
  mut sent_at_us : UInt64?
  mut completed : Bool
  mut result : DiagnosticResponse?
}

///|
pub fn diagnostic_workflow_step(
  name : String,
  request : DiagnosticRequest,
  timeout_us? : UInt64 = 50_000,
  retry? : DiagnosticRetryPolicy = diagnostic_retry_policy(),
) -> DiagnosticWorkflowStep {
  {
    name,
    request,
    timeout_us,
    retry,
    sent_at_us: None,
    completed: false,
    result: None,
  }
}

///|
pub fn DiagnosticWorkflowStep::name(self : DiagnosticWorkflowStep) -> String {
  self.name
}

///|
pub fn DiagnosticWorkflowStep::request(
  self : DiagnosticWorkflowStep,
) -> DiagnosticRequest {
  self.request
}

///|
pub fn DiagnosticWorkflowStep::timeout_us(
  self : DiagnosticWorkflowStep,
) -> UInt64 {
  self.timeout_us
}

///|
pub fn DiagnosticWorkflowStep::retry(
  self : DiagnosticWorkflowStep,
) -> DiagnosticRetryPolicy {
  self.retry
}

///|
pub fn DiagnosticWorkflowStep::sent_at_us(
  self : DiagnosticWorkflowStep,
) -> UInt64? {
  self.sent_at_us
}

///|
pub fn DiagnosticWorkflowStep::completed(self : DiagnosticWorkflowStep) -> Bool {
  self.completed
}

///|
pub fn DiagnosticWorkflowStep::result(
  self : DiagnosticWorkflowStep,
) -> DiagnosticResponse? {
  self.result
}

///|
pub fn DiagnosticWorkflowStep::begin(
  self : DiagnosticWorkflowStep,
  timestamp_us : UInt64,
) -> Bool {
  if self.completed || !self.retry.begin_attempt() {
    false
  } else {
    self.sent_at_us = Some(timestamp_us)
    true
  }
}

///|
pub fn DiagnosticWorkflowStep::accept(
  self : DiagnosticWorkflowStep,
  payload : Array[Byte],
) -> Bool {
  let response = decode_response(self.request, payload)
  let positive = match response {
    Positive(_) => true
    _ => false
  }
  if positive || !self.retry.retry_negative() {
    self.result = Some(response)
    self.completed = true
  }
  positive
}

///|
pub fn DiagnosticWorkflowStep::timed_out(
  self : DiagnosticWorkflowStep,
  timestamp_us : UInt64,
) -> Bool {
  match self.sent_at_us {
    Some(sent) => !self.completed && timestamp_us > sent + self.timeout_us
    None => false
  }
}

///|
pub fn DiagnosticWorkflowStep::clear_attempt(
  self : DiagnosticWorkflowStep,
) -> Unit {
  self.sent_at_us = None
}

///|
/// A result record retained after a workflow step completes.
pub struct DiagnosticWorkflowResult {
  step_name : String
  service : String
  positive : Bool
  attempts : Int
  duration_us : UInt64
  response : DiagnosticResponse
}

///|
pub fn DiagnosticWorkflowResult::step_name(
  self : DiagnosticWorkflowResult,
) -> String {
  self.step_name
}

///|
pub fn DiagnosticWorkflowResult::service(
  self : DiagnosticWorkflowResult,
) -> String {
  self.service
}

///|
pub fn DiagnosticWorkflowResult::positive(
  self : DiagnosticWorkflowResult,
) -> Bool {
  self.positive
}

///|
pub fn DiagnosticWorkflowResult::attempts(
  self : DiagnosticWorkflowResult,
) -> Int {
  self.attempts
}

///|
pub fn DiagnosticWorkflowResult::duration_us(
  self : DiagnosticWorkflowResult,
) -> UInt64 {
  self.duration_us
}

///|
pub fn DiagnosticWorkflowResult::response(
  self : DiagnosticWorkflowResult,
) -> DiagnosticResponse {
  self.response
}

///|
/// A sequential diagnostic workflow runner.
pub struct DiagnosticWorkflow {
  steps : Array[DiagnosticWorkflowStep]
  results : Array[DiagnosticWorkflowResult]
  mut cursor : Int
  mut state : DiagnosticWorkflowState
  mut started_us : UInt64
  mut last_timestamp_us : UInt64
  mut failures : Int
}

///|
pub fn new_diagnostic_workflow() -> DiagnosticWorkflow {
  {
    steps: [],
    results: [],
    cursor: 0,
    state: DiagnosticWorkflowIdle,
    started_us: 0,
    last_timestamp_us: 0,
    failures: 0,
  }
}

///|
pub fn DiagnosticWorkflow::add(
  self : DiagnosticWorkflow,
  step : DiagnosticWorkflowStep,
) -> Bool {
  if self.state is DiagnosticWorkflowIdle {
    self.steps.push(step)
    true
  } else {
    false
  }
}

///|
pub fn DiagnosticWorkflow::length(self : DiagnosticWorkflow) -> Int {
  self.steps.length()
}

///|
pub fn DiagnosticWorkflow::cursor(self : DiagnosticWorkflow) -> Int {
  self.cursor
}

///|
pub fn DiagnosticWorkflow::state(
  self : DiagnosticWorkflow,
) -> DiagnosticWorkflowState {
  self.state
}

///|
pub fn DiagnosticWorkflow::started_us(self : DiagnosticWorkflow) -> UInt64 {
  self.started_us
}

///|
pub fn DiagnosticWorkflow::last_timestamp_us(
  self : DiagnosticWorkflow,
) -> UInt64 {
  self.last_timestamp_us
}

///|
pub fn DiagnosticWorkflow::failures(self : DiagnosticWorkflow) -> Int {
  self.failures
}

///|
pub fn DiagnosticWorkflow::results(
  self : DiagnosticWorkflow,
) -> Array[DiagnosticWorkflowResult] {
  self.results.copy()
}

///|
pub fn DiagnosticWorkflow::start(
  self : DiagnosticWorkflow,
  timestamp_us : UInt64,
) -> Bool {
  if self.steps.is_empty() || !(self.state is DiagnosticWorkflowIdle) {
    false
  } else {
    self.cursor = 0
    self.started_us = timestamp_us
    self.last_timestamp_us = timestamp_us
    self.state = DiagnosticWorkflowRunning
    true
  }
}

///|
pub fn DiagnosticWorkflow::current(
  self : DiagnosticWorkflow,
) -> DiagnosticWorkflowStep? {
  if self.cursor < self.steps.length() {
    Some(self.steps[self.cursor])
  } else {
    None
  }
}

///|
pub fn DiagnosticWorkflow::begin_current(
  self : DiagnosticWorkflow,
  timestamp_us : UInt64,
) -> Bool {
  match self.current() {
    Some(step) => {
      self.last_timestamp_us = timestamp_us
      step.begin(timestamp_us)
    }
    None => false
  }
}

///|
pub fn DiagnosticWorkflow::accept_current(
  self : DiagnosticWorkflow,
  payload : Array[Byte],
  timestamp_us : UInt64,
) -> Bool {
  match self.current() {
    Some(step) => {
      let positive = step.accept(payload)
      self.last_timestamp_us = timestamp_us
      if step.completed() {
        self.results.push({
          step_name: step.name(),
          service: step.request().service_name(),
          positive,
          attempts: step.retry().attempts(),
          duration_us: timestamp_us - self.started_us,
          response: match step.result() {
            Some(value) => value
            None => Malformed
          },
        })
        if positive {
          self.advance()
        } else {
          self.failures += 1
          self.state = DiagnosticWorkflowFailed
        }
      }
      positive
    }
    None => false
  }
}

///|
pub fn DiagnosticWorkflow::poll_timeout(
  self : DiagnosticWorkflow,
  timestamp_us : UInt64,
) -> Bool {
  match self.current() {
    Some(step) =>
      if step.timed_out(timestamp_us) {
        if step.retry().can_retry() {
          step.clear_attempt()
          self.state = DiagnosticWorkflowWaiting
          true
        } else {
          self.failures += 1
          self.state = DiagnosticWorkflowFailed
          false
        }
      } else {
        false
      }
    None => false
  }
}

///|
pub fn DiagnosticWorkflow::continue_after_wait(
  self : DiagnosticWorkflow,
) -> Bool {
  if self.state is DiagnosticWorkflowWaiting {
    self.state = DiagnosticWorkflowRunning
    true
  } else {
    false
  }
}

///|
fn DiagnosticWorkflow::advance(self : DiagnosticWorkflow) -> Unit {
  self.cursor += 1
  if self.cursor >= self.steps.length() {
    self.state = DiagnosticWorkflowSucceeded
  } else {
    self.state = DiagnosticWorkflowRunning
  }
}

///|
pub fn DiagnosticWorkflow::cancel(self : DiagnosticWorkflow) -> Unit {
  self.state = DiagnosticWorkflowCancelled
}

///|
pub fn DiagnosticWorkflow::reset(self : DiagnosticWorkflow) -> Unit {
  for step in self.steps {
    step.retry().reset()
    step.clear_attempt()
  }
  self.cursor = 0
  self.results.clear()
  self.failures = 0
  self.state = DiagnosticWorkflowIdle
}

///|
pub fn DiagnosticWorkflow::progress_percent(self : DiagnosticWorkflow) -> Int {
  if self.steps.is_empty() {
    0
  } else {
    self.cursor * 100 / self.steps.length()
  }
}

///|
pub fn DiagnosticWorkflow::successful(self : DiagnosticWorkflow) -> Bool {
  self.state is DiagnosticWorkflowSucceeded
}

///|
pub fn DiagnosticWorkflow::to_text(self : DiagnosticWorkflow) -> String {
  "state=" +
  diagnostic_workflow_state_text(self.state) +
  " progress=" +
  self.progress_percent().to_string() +
  "% results=" +
  self.results.length().to_string() +
  " failures=" +
  self.failures.to_string()
}

///|
pub fn diagnostic_workflow_state_text(
  state : DiagnosticWorkflowState,
) -> String {
  match state {
    DiagnosticWorkflowIdle => "idle"
    DiagnosticWorkflowRunning => "running"
    DiagnosticWorkflowWaiting => "waiting"
    DiagnosticWorkflowSucceeded => "succeeded"
    DiagnosticWorkflowFailed => "failed"
    DiagnosticWorkflowCancelled => "cancelled"
  }
}

///|
/// A readiness check used before programming or calibration.
pub struct DiagnosticReadiness {
  session_ok : Bool
  security_ok : Bool
  voltage_ok : Bool
  temperature_ok : Bool
  dtc_ok : Bool
  reasons : Array[String]
}

///|
pub fn diagnostic_readiness(
  session_ok : Bool,
  security_ok : Bool,
  voltage_ok : Bool,
  temperature_ok : Bool,
  dtc_ok : Bool,
) -> DiagnosticReadiness {
  let reasons : Array[String] = []
  if !session_ok {
    reasons.push("invalid diagnostic session")
  }
  if !security_ok {
    reasons.push("security access is locked")
  }
  if !voltage_ok {
    reasons.push("battery voltage outside programming range")
  }
  if !temperature_ok {
    reasons.push("temperature outside calibration range")
  }
  if !dtc_ok {
    reasons.push("blocking DTC is present")
  }
  { session_ok, security_ok, voltage_ok, temperature_ok, dtc_ok, reasons }
}

///|
pub fn DiagnosticReadiness::ready(self : DiagnosticReadiness) -> Bool {
  self.reasons.is_empty()
}

///|
pub fn DiagnosticReadiness::reasons(
  self : DiagnosticReadiness,
) -> Array[String] {
  self.reasons.copy()
}

///|
pub fn DiagnosticReadiness::session_ok(self : DiagnosticReadiness) -> Bool {
  self.session_ok
}

///|
pub fn DiagnosticReadiness::security_ok(self : DiagnosticReadiness) -> Bool {
  self.security_ok
}

///|
pub fn DiagnosticReadiness::voltage_ok(self : DiagnosticReadiness) -> Bool {
  self.voltage_ok
}

///|
pub fn DiagnosticReadiness::temperature_ok(self : DiagnosticReadiness) -> Bool {
  self.temperature_ok
}

///|
pub fn DiagnosticReadiness::dtc_ok(self : DiagnosticReadiness) -> Bool {
  self.dtc_ok
}

///|
/// Aggregate the outcome of multiple readiness checks.
pub fn diagnostic_readiness_all(
  checks : Array[DiagnosticReadiness],
) -> DiagnosticReadiness {
  let mut session_ok = true
  let mut security_ok = true
  let mut voltage_ok = true
  let mut temperature_ok = true
  let mut dtc_ok = true
  let reasons : Array[String] = []
  for check in checks {
    session_ok = session_ok && check.session_ok()
    security_ok = security_ok && check.security_ok()
    voltage_ok = voltage_ok && check.voltage_ok()
    temperature_ok = temperature_ok && check.temperature_ok()
    dtc_ok = dtc_ok && check.dtc_ok()
    reasons.append(check.reasons())
  }
  { session_ok, security_ok, voltage_ok, temperature_ok, dtc_ok, reasons }
}

///|
/// Build a standard ECU identification workflow.
pub fn diagnostic_identification_workflow(
  identifiers : Array[UInt],
) -> DiagnosticWorkflow {
  let workflow = new_diagnostic_workflow()
  for identifier in identifiers {
    ignore(
      workflow.add(
        diagnostic_workflow_step(
          "read-data-" + identifier.to_string(),
          read_data(identifier),
        ),
      ),
    )
  }
  workflow
}
