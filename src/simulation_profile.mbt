///|
/// Lifecycle state of a deterministic simulation scenario.
pub enum SimulationScenarioState {
  SimulationScenarioDraft
  SimulationScenarioReady
  SimulationScenarioRunning
  SimulationScenarioPassed
  SimulationScenarioFailed
}

///|
pub fn simulation_scenario_state_variants() -> Array[SimulationScenarioState] {
  [
    SimulationScenarioDraft,
    SimulationScenarioReady,
    SimulationScenarioRunning,
    SimulationScenarioPassed,
    SimulationScenarioFailed,
  ]
}

///|
/// An event scheduled in a reusable simulation scenario.
pub struct SimulationScenarioEvent {
  timestamp_us : UInt64
  frame : Frame
  source : String
}

///|
pub fn simulation_scenario_event(
  timestamp_us : UInt64,
  frame : Frame,
  source? : String = "scenario",
) -> SimulationScenarioEvent {
  { timestamp_us, frame, source }
}

///|
pub fn SimulationScenarioEvent::timestamp_us(
  self : SimulationScenarioEvent,
) -> UInt64 {
  self.timestamp_us
}

///|
pub fn SimulationScenarioEvent::frame(self : SimulationScenarioEvent) -> Frame {
  self.frame
}

///|
pub fn SimulationScenarioEvent::source(
  self : SimulationScenarioEvent,
) -> String {
  self.source
}

///|
/// An assertion applied to a completed simulation report.
pub enum SimulationScenarioAssertion {
  SimulationAssertDeliveredAtLeast(Int)
  SimulationAssertDroppedAtMost(Int)
  SimulationAssertDurationAtMost(UInt64)
  SimulationAssertIdentifierSeen(UInt)
  SimulationAssertHealth(BusHealthState)
}

///|
pub fn simulation_scenario_assertion_variants() -> Array[
  SimulationScenarioAssertion,
] {
  [
    SimulationAssertDeliveredAtLeast(0),
    SimulationAssertDroppedAtMost(0),
    SimulationAssertDurationAtMost(0),
    SimulationAssertIdentifierSeen(0),
    SimulationAssertHealth(Healthy),
  ]
}

///|
/// A result produced by running a scenario.
pub struct SimulationScenarioResult {
  name : String
  state : SimulationScenarioState
  report : SimulationReport
  assertions : Array[SimulationScenarioAssertion]
  failures : Array[String]
}

///|
pub fn SimulationScenarioResult::name(
  self : SimulationScenarioResult,
) -> String {
  self.name
}

///|
pub fn SimulationScenarioResult::state(
  self : SimulationScenarioResult,
) -> SimulationScenarioState {
  self.state
}

///|
pub fn SimulationScenarioResult::report(
  self : SimulationScenarioResult,
) -> SimulationReport {
  self.report
}

///|
pub fn SimulationScenarioResult::assertions(
  self : SimulationScenarioResult,
) -> Array[SimulationScenarioAssertion] {
  self.assertions.copy()
}

///|
pub fn SimulationScenarioResult::failures(
  self : SimulationScenarioResult,
) -> Array[String] {
  self.failures.copy()
}

///|
pub fn SimulationScenarioResult::passed(
  self : SimulationScenarioResult,
) -> Bool {
  self.state is SimulationScenarioPassed
}

///|
pub fn SimulationScenarioResult::to_text(
  self : SimulationScenarioResult,
) -> String {
  self.name +
  " state=" +
  simulation_scenario_state_text(self.state) +
  " failures=" +
  self.failures.length().to_string() +
  " delivered=" +
  self.report.delivered().to_string() +
  " dropped=" +
  self.report.dropped().to_string()
}

///|
pub fn simulation_scenario_state_text(
  state : SimulationScenarioState,
) -> String {
  match state {
    SimulationScenarioDraft => "draft"
    SimulationScenarioReady => "ready"
    SimulationScenarioRunning => "running"
    SimulationScenarioPassed => "passed"
    SimulationScenarioFailed => "failed"
  }
}

///|
/// A reusable deterministic scenario for ECU and gateway testing.
pub struct SimulationScenario {
  name : String
  capacity : Int
  bitrate_kbps : UInt
  events : Array[SimulationScenarioEvent]
  assertions : Array[SimulationScenarioAssertion]
  mut state : SimulationScenarioState
}

///|
pub fn new_simulation_scenario(
  name : String,
  capacity? : Int = 128,
  bitrate_kbps? : UInt = 500,
) -> SimulationScenario {
  {
    name,
    capacity: if capacity < 1 {
      1
    } else {
      capacity
    },
    bitrate_kbps,
    events: [],
    assertions: [],
    state: SimulationScenarioDraft,
  }
}

///|
pub fn SimulationScenario::name(self : SimulationScenario) -> String {
  self.name
}

///|
pub fn SimulationScenario::capacity(self : SimulationScenario) -> Int {
  self.capacity
}

///|
pub fn SimulationScenario::bitrate_kbps(self : SimulationScenario) -> UInt {
  self.bitrate_kbps
}

///|
pub fn SimulationScenario::state(
  self : SimulationScenario,
) -> SimulationScenarioState {
  self.state
}

///|
pub fn SimulationScenario::events(
  self : SimulationScenario,
) -> Array[SimulationScenarioEvent] {
  self.events.copy()
}

///|
pub fn SimulationScenario::assertions(
  self : SimulationScenario,
) -> Array[SimulationScenarioAssertion] {
  self.assertions.copy()
}

///|
pub fn SimulationScenario::schedule(
  self : SimulationScenario,
  timestamp_us : UInt64,
  frame : Frame,
  source? : String = "scenario",
) -> Bool {
  if self.events.length() >= self.capacity ||
    !(self.state is SimulationScenarioDraft) {
    false
  } else {
    self.events.push(simulation_scenario_event(timestamp_us, frame, source~))
    true
  }
}

///|
pub fn SimulationScenario::schedule_periodic(
  self : SimulationScenario,
  first_timestamp_us : UInt64,
  period_us : UInt64,
  count : Int,
  frame : Frame,
  source? : String = "periodic",
) -> Bool {
  if period_us == 0 || count < 1 {
    false
  } else {
    let mut accepted = true
    for index in 0..<count {
      accepted = accepted &&
        self.schedule(
          first_timestamp_us + index.to_uint64() * period_us,
          frame,
          source~,
        )
    }
    accepted
  }
}

///|
pub fn SimulationScenario::add_assertion(
  self : SimulationScenario,
  assertion : SimulationScenarioAssertion,
) -> Unit {
  self.assertions.push(assertion)
}

///|
pub fn SimulationScenario::ready(self : SimulationScenario) -> Bool {
  if self.events.is_empty() {
    false
  } else {
    self.state = SimulationScenarioReady
    true
  }
}

///|
pub fn SimulationScenario::run(
  self : SimulationScenario,
) -> SimulationScenarioResult raise SimulationError {
  if self.events.is_empty() {
    self.state = SimulationScenarioFailed
  }
  self.state = SimulationScenarioRunning
  let simulation = new_simulation(self.capacity, self.bitrate_kbps)
  let ordered = self.events.copy()
  ordered.sort_by((left, right) => {
    if left.timestamp_us() < right.timestamp_us() {
      -1
    } else if left.timestamp_us() > right.timestamp_us() {
      1
    } else {
      0
    }
  })
  for event in ordered {
    simulation.schedule(
      event.timestamp_us(),
      event.frame(),
      source=event.source(),
    )
  }
  let end_us : UInt64 = if ordered.is_empty() {
    0
  } else {
    ordered[ordered.length() - 1].timestamp_us() + 1
  }
  ignore(simulation.run_until(end_us))
  let report = simulation.report(0)
  let failures = simulation_check_assertions(
    self.assertions,
    report,
    simulation.trace(),
  )
  self.state = if failures.is_empty() {
    SimulationScenarioPassed
  } else {
    SimulationScenarioFailed
  }
  {
    name: self.name,
    state: self.state,
    report,
    assertions: self.assertions.copy(),
    failures,
  }
}

///|
pub fn SimulationScenario::clear(self : SimulationScenario) -> Unit {
  self.events.clear()
  self.assertions.clear()
  self.state = SimulationScenarioDraft
}

///|
pub fn SimulationScenario::to_text(self : SimulationScenario) -> String {
  self.name +
  " state=" +
  simulation_scenario_state_text(self.state) +
  " events=" +
  self.events.length().to_string() +
  " assertions=" +
  self.assertions.length().to_string()
}

///|
fn simulation_check_assertions(
  assertions : Array[SimulationScenarioAssertion],
  report : SimulationReport,
  trace : Trace,
) -> Array[String] {
  let failures : Array[String] = []
  for assertion in assertions {
    match assertion {
      SimulationAssertDeliveredAtLeast(minimum) =>
        if report.delivered() < minimum {
          failures.push("delivered below minimum")
        }
      SimulationAssertDroppedAtMost(maximum) =>
        if report.dropped() > maximum {
          failures.push("dropped above maximum")
        }
      SimulationAssertDurationAtMost(maximum) =>
        if report.duration_us() > maximum {
          failures.push("duration above maximum")
        }
      SimulationAssertIdentifierSeen(identifier) => {
        let seen = trace.frames().exists(frame => frame.id() == identifier)
        if !seen {
          failures.push("identifier not seen " + identifier.to_string())
        }
      }
      SimulationAssertHealth(expected) => {
        let health = assess_bus_health(
          trace_metrics(trace),
          report.dropped(),
          report.duration_us(),
          500,
        )
        if !network_health_state_same(health.state(), expected) {
          failures.push("unexpected bus health")
        }
      }
    }
  }
  failures
}

///|
fn network_health_state_same(
  left : BusHealthState,
  right : BusHealthState,
) -> Bool {
  match left {
    Healthy =>
      match right {
        Healthy => true
        _ => false
      }
    Busy =>
      match right {
        Busy => true
        _ => false
      }
    Degraded =>
      match right {
        Degraded => true
        _ => false
      }
    Overloaded =>
      match right {
        Overloaded => true
        _ => false
      }
    Silent =>
      match right {
        Silent => true
        _ => false
      }
  }
}

///|
/// Run multiple scenarios and return only failed results.
pub fn run_simulation_scenarios(
  scenarios : Array[SimulationScenario],
) -> Array[SimulationScenarioResult] raise SimulationError {
  let results : Array[SimulationScenarioResult] = []
  for scenario in scenarios {
    results.push(scenario.run())
  }
  results
}

///|
/// Produce a regression summary for scenario results.
pub fn simulation_scenario_summary(
  results : Array[SimulationScenarioResult],
) -> String {
  let mut passed = 0
  let mut failed = 0
  let names : Array[String] = []
  for result in results {
    if result.passed() {
      passed += 1
    } else {
      failed += 1
      names.push(result.name())
    }
  }
  "passed=" +
  passed.to_string() +
  " failed=" +
  failed.to_string() +
  " failing=" +
  names.join(",")
}
