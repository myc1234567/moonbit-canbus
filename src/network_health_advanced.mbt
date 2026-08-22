///|
/// Operational state used by a network health dashboard.
pub enum NetworkNodeHealthState {
  NetworkNodeUnknown
  NetworkNodeHealthy
  NetworkNodeDegraded
  NetworkNodeOffline
  NetworkNodeMaintenance
}

///|
pub fn network_node_health_state_variants() -> Array[NetworkNodeHealthState] {
  [
    NetworkNodeUnknown,
    NetworkNodeHealthy,
    NetworkNodeDegraded,
    NetworkNodeOffline,
    NetworkNodeMaintenance,
  ]
}

///|
pub fn network_node_health_state_text(state : NetworkNodeHealthState) -> String {
  match state {
    NetworkNodeUnknown => "unknown"
    NetworkNodeHealthy => "healthy"
    NetworkNodeDegraded => "degraded"
    NetworkNodeOffline => "offline"
    NetworkNodeMaintenance => "maintenance"
  }
}

///|
/// A node health sample with counters and timing.
pub struct NetworkNodeHealth {
  node_id : Byte
  name : String
  mut state : NetworkNodeHealthState
  mut last_seen_us : UInt64
  timeout_us : UInt64
  mut received : Int
  mut transmitted : Int
  mut errors : Int
  mut missed_heartbeats : Int
  latency_samples : Array[UInt64]
}

///|
pub fn network_node_health(
  node_id : Byte,
  name : String,
  timeout_us? : UInt64 = 1_000_000,
) -> NetworkNodeHealth {
  {
    node_id,
    name,
    state: NetworkNodeUnknown,
    last_seen_us: 0,
    timeout_us,
    received: 0,
    transmitted: 0,
    errors: 0,
    missed_heartbeats: 0,
    latency_samples: [],
  }
}

///|
pub fn NetworkNodeHealth::node_id(self : NetworkNodeHealth) -> Byte {
  self.node_id
}

///|
pub fn NetworkNodeHealth::name(self : NetworkNodeHealth) -> String {
  self.name
}

///|
pub fn NetworkNodeHealth::state(
  self : NetworkNodeHealth,
) -> NetworkNodeHealthState {
  self.state
}

///|
pub fn NetworkNodeHealth::last_seen_us(self : NetworkNodeHealth) -> UInt64 {
  self.last_seen_us
}

///|
pub fn NetworkNodeHealth::timeout_us(self : NetworkNodeHealth) -> UInt64 {
  self.timeout_us
}

///|
pub fn NetworkNodeHealth::received(self : NetworkNodeHealth) -> Int {
  self.received
}

///|
pub fn NetworkNodeHealth::transmitted(self : NetworkNodeHealth) -> Int {
  self.transmitted
}

///|
pub fn NetworkNodeHealth::errors(self : NetworkNodeHealth) -> Int {
  self.errors
}

///|
pub fn NetworkNodeHealth::missed_heartbeats(self : NetworkNodeHealth) -> Int {
  self.missed_heartbeats
}

///|
pub fn NetworkNodeHealth::latency_samples(
  self : NetworkNodeHealth,
) -> Array[UInt64] {
  self.latency_samples.copy()
}

///|
pub fn NetworkNodeHealth::online(self : NetworkNodeHealth) -> Bool {
  match self.state {
    NetworkNodeOffline => false
    _ => true
  }
}

///|
pub fn NetworkNodeHealth::observe_frame(
  self : NetworkNodeHealth,
  timestamp_us : UInt64,
  transmit : Bool,
) -> Unit {
  self.last_seen_us = timestamp_us
  self.state = NetworkNodeHealthy
  if transmit {
    self.transmitted += 1
  } else {
    self.received += 1
  }
}

///|
pub fn NetworkNodeHealth::observe_heartbeat(
  self : NetworkNodeHealth,
  timestamp_us : UInt64,
  latency_us? : UInt64 = 0,
) -> Unit {
  self.last_seen_us = timestamp_us
  self.state = NetworkNodeHealthy
  if latency_us > 0 {
    self.latency_samples.push(latency_us)
  }
}

///|
pub fn NetworkNodeHealth::observe_error(self : NetworkNodeHealth) -> Unit {
  self.errors += 1
  if self.errors > 3 {
    self.state = NetworkNodeDegraded
  }
}

///|
pub fn NetworkNodeHealth::poll(
  self : NetworkNodeHealth,
  timestamp_us : UInt64,
) -> NetworkNodeHealthState {
  if timestamp_us > self.last_seen_us + self.timeout_us {
    self.missed_heartbeats += 1
    self.state = NetworkNodeOffline
  } else if self.errors > 0 &&
    self.errors * 100 > self.received + self.transmitted + 1 {
    self.state = NetworkNodeDegraded
  }
  self.state
}

///|
pub fn NetworkNodeHealth::average_latency_us(
  self : NetworkNodeHealth,
) -> UInt64 {
  if self.latency_samples.is_empty() {
    0
  } else {
    let mut sum : UInt64 = 0
    for sample in self.latency_samples {
      sum += sample
    }
    sum / self.latency_samples.length().to_uint64()
  }
}

///|
pub fn NetworkNodeHealth::p95_latency_us(self : NetworkNodeHealth) -> UInt64 {
  if self.latency_samples.is_empty() {
    0
  } else {
    let values = self.latency_samples.copy()
    values.sort()
    values[(values.length() - 1) * 95 / 100]
  }
}

///|
pub fn NetworkNodeHealth::to_text(self : NetworkNodeHealth) -> String {
  self.name +
  " node=" +
  self.node_id.to_string() +
  " state=" +
  network_node_health_state_text(self.state) +
  " rx=" +
  self.received.to_string() +
  " tx=" +
  self.transmitted.to_string() +
  " errors=" +
  self.errors.to_string()
}

///|
/// An error budget for a production CAN network.
pub struct NetworkErrorBudget {
  max_error_rate : Double
  max_drop_rate : Double
  max_offline_nodes : Int
  mut total_frames : Int
  mut error_frames : Int
  mut dropped_frames : Int
  mut offline_nodes : Int
}

///|
pub fn network_error_budget(
  max_error_rate? : Double = 0.01,
  max_drop_rate? : Double = 0.01,
  max_offline_nodes? : Int = 0,
) -> NetworkErrorBudget {
  {
    max_error_rate,
    max_drop_rate,
    max_offline_nodes,
    total_frames: 0,
    error_frames: 0,
    dropped_frames: 0,
    offline_nodes: 0,
  }
}

///|
pub fn NetworkErrorBudget::record_frame(
  self : NetworkErrorBudget,
  error : Bool,
  dropped : Bool,
) -> Unit {
  self.total_frames += 1
  if error {
    self.error_frames += 1
  }
  if dropped {
    self.dropped_frames += 1
  }
}

///|
pub fn NetworkErrorBudget::set_offline_nodes(
  self : NetworkErrorBudget,
  count : Int,
) -> Unit {
  self.offline_nodes = count
}

///|
pub fn NetworkErrorBudget::error_rate(self : NetworkErrorBudget) -> Double {
  if self.total_frames == 0 {
    0.0
  } else {
    self.error_frames.to_double() / self.total_frames.to_double()
  }
}

///|
pub fn NetworkErrorBudget::drop_rate(self : NetworkErrorBudget) -> Double {
  if self.total_frames == 0 {
    0.0
  } else {
    self.dropped_frames.to_double() / self.total_frames.to_double()
  }
}

///|
pub fn NetworkErrorBudget::within_budget(self : NetworkErrorBudget) -> Bool {
  self.error_rate() <= self.max_error_rate &&
  self.drop_rate() <= self.max_drop_rate &&
  self.offline_nodes <= self.max_offline_nodes
}

///|
pub fn NetworkErrorBudget::total_frames(self : NetworkErrorBudget) -> Int {
  self.total_frames
}

///|
pub fn NetworkErrorBudget::error_frames(self : NetworkErrorBudget) -> Int {
  self.error_frames
}

///|
pub fn NetworkErrorBudget::dropped_frames(self : NetworkErrorBudget) -> Int {
  self.dropped_frames
}

///|
pub fn NetworkErrorBudget::offline_nodes(self : NetworkErrorBudget) -> Int {
  self.offline_nodes
}

///|
pub fn NetworkErrorBudget::max_error_rate(self : NetworkErrorBudget) -> Double {
  self.max_error_rate
}

///|
pub fn NetworkErrorBudget::max_drop_rate(self : NetworkErrorBudget) -> Double {
  self.max_drop_rate
}

///|
/// A summary of network health at one observation point.
pub struct NetworkHealthReport {
  timestamp_us : UInt64
  nodes : Array[NetworkNodeHealth]
  online : Int
  degraded : Int
  offline : Int
  budget : NetworkErrorBudget
}

///|
pub fn NetworkHealthReport::timestamp_us(self : NetworkHealthReport) -> UInt64 {
  self.timestamp_us
}

///|
pub fn NetworkHealthReport::nodes(
  self : NetworkHealthReport,
) -> Array[NetworkNodeHealth] {
  self.nodes.copy()
}

///|
pub fn NetworkHealthReport::online(self : NetworkHealthReport) -> Int {
  self.online
}

///|
pub fn NetworkHealthReport::degraded(self : NetworkHealthReport) -> Int {
  self.degraded
}

///|
pub fn NetworkHealthReport::offline(self : NetworkHealthReport) -> Int {
  self.offline
}

///|
pub fn NetworkHealthReport::budget(
  self : NetworkHealthReport,
) -> NetworkErrorBudget {
  self.budget
}

///|
pub fn NetworkHealthReport::healthy(self : NetworkHealthReport) -> Bool {
  self.offline == 0 && self.degraded == 0 && self.budget.within_budget()
}

///|
pub fn NetworkHealthReport::to_text(self : NetworkHealthReport) -> String {
  "t=" +
  self.timestamp_us.to_string() +
  " online=" +
  self.online.to_string() +
  " degraded=" +
  self.degraded.to_string() +
  " offline=" +
  self.offline.to_string() +
  " budget=" +
  self.budget.within_budget().to_string()
}

///|
/// A fleet-level health tracker for virtual or hardware-connected nodes.
pub struct NetworkHealthTracker {
  nodes : Array[NetworkNodeHealth]
  budget : NetworkErrorBudget
  mut samples : Int
  mut last_timestamp_us : UInt64
}

///|
pub fn new_network_health_tracker(
  budget? : NetworkErrorBudget = network_error_budget(),
) -> NetworkHealthTracker {
  { nodes: [], budget, samples: 0, last_timestamp_us: 0 }
}

///|
pub fn NetworkHealthTracker::add_node(
  self : NetworkHealthTracker,
  node : NetworkNodeHealth,
) -> Bool {
  if self.find(node.node_id()) is Some(_) {
    false
  } else {
    self.nodes.push(node)
    true
  }
}

///|
pub fn NetworkHealthTracker::find(
  self : NetworkHealthTracker,
  node_id : Byte,
) -> NetworkNodeHealth? {
  for node in self.nodes {
    if node.node_id() == node_id {
      return Some(node)
    }
  }
  None
}

///|
pub fn NetworkHealthTracker::observe_frame(
  self : NetworkHealthTracker,
  node_id : Byte,
  timestamp_us : UInt64,
  frame : Frame,
  transmit : Bool,
) -> Bool {
  match self.find_index(node_id) {
    Some(index) => {
      self.nodes[index].observe_frame(timestamp_us, transmit)
      self.budget.record_frame(frame.is_error(), false)
      self.last_timestamp_us = timestamp_us
      true
    }
    None => false
  }
}

///|
pub fn NetworkHealthTracker::observe_heartbeat(
  self : NetworkHealthTracker,
  node_id : Byte,
  timestamp_us : UInt64,
  latency_us? : UInt64 = 0,
) -> Bool {
  match self.find_index(node_id) {
    Some(index) => {
      self.nodes[index].observe_heartbeat(timestamp_us, latency_us~)
      true
    }
    None => false
  }
}

///|
pub fn NetworkHealthTracker::observe_drop(self : NetworkHealthTracker) -> Unit {
  self.budget.record_frame(false, true)
}

///|
pub fn NetworkHealthTracker::observe_error(
  self : NetworkHealthTracker,
  node_id : Byte,
) -> Bool {
  match self.find_index(node_id) {
    Some(index) => {
      self.nodes[index].observe_error()
      self.budget.record_frame(true, false)
      true
    }
    None => false
  }
}

///|
pub fn NetworkHealthTracker::poll(
  self : NetworkHealthTracker,
  timestamp_us : UInt64,
) -> NetworkHealthReport {
  let mut online = 0
  let mut degraded = 0
  let mut offline = 0
  for node in self.nodes {
    match node.poll(timestamp_us) {
      NetworkNodeHealthy => online += 1
      NetworkNodeDegraded => degraded += 1
      NetworkNodeOffline => offline += 1
      _ => ()
    }
  }
  self.budget.set_offline_nodes(offline)
  self.samples += 1
  self.last_timestamp_us = timestamp_us
  {
    timestamp_us,
    nodes: self.nodes.copy(),
    online,
    degraded,
    offline,
    budget: self.budget,
  }
}

///|
pub fn NetworkHealthTracker::nodes(
  self : NetworkHealthTracker,
) -> Array[NetworkNodeHealth] {
  self.nodes.copy()
}

///|
pub fn NetworkHealthTracker::budget(
  self : NetworkHealthTracker,
) -> NetworkErrorBudget {
  self.budget
}

///|
pub fn NetworkHealthTracker::samples(self : NetworkHealthTracker) -> Int {
  self.samples
}

///|
pub fn NetworkHealthTracker::last_timestamp_us(
  self : NetworkHealthTracker,
) -> UInt64 {
  self.last_timestamp_us
}

///|
pub fn NetworkHealthTracker::reset(self : NetworkHealthTracker) -> Unit {
  self.samples = 0
  self.last_timestamp_us = 0
  for node in self.nodes {
    node.state = NetworkNodeUnknown
    node.received = 0
    node.transmitted = 0
    node.errors = 0
    node.missed_heartbeats = 0
    node.latency_samples.clear()
  }
}

///|
fn NetworkHealthTracker::find_index(
  self : NetworkHealthTracker,
  node_id : Byte,
) -> Int? {
  for index, node in self.nodes {
    if node.node_id() == node_id {
      return Some(index)
    }
  }
  None
}
