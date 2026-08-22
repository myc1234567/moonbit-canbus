///|
/// Lifecycle state of a portable CAN adapter.
pub enum CanAdapterLifecycle {
  CanAdapterCreated
  CanAdapterConfigured
  CanAdapterOpen
  CanAdapterBusOff
  CanAdapterClosed
}

///|
pub fn can_adapter_lifecycle_variants() -> Array[CanAdapterLifecycle] {
  [
    CanAdapterCreated,
    CanAdapterConfigured,
    CanAdapterOpen,
    CanAdapterBusOff,
    CanAdapterClosed,
  ]
}

///|
/// Capabilities exposed by a hardware or virtual CAN backend.
pub struct CanAdapterCapabilities {
  classic : Bool
  can_fd : Bool
  bitrate_switch : Bool
  listen_only : Bool
  loopback : Bool
  timestamping : Bool
  max_rx_queue : Int
  max_tx_queue : Int
}

///|
pub fn can_adapter_capabilities(
  classic? : Bool = true,
  can_fd? : Bool = true,
  bitrate_switch? : Bool = true,
  listen_only? : Bool = true,
  loopback? : Bool = true,
  timestamping? : Bool = true,
  max_rx_queue? : Int = 1024,
  max_tx_queue? : Int = 1024,
) -> CanAdapterCapabilities {
  {
    classic,
    can_fd,
    bitrate_switch,
    listen_only,
    loopback,
    timestamping,
    max_rx_queue,
    max_tx_queue,
  }
}

///|
pub fn CanAdapterCapabilities::classic(self : CanAdapterCapabilities) -> Bool {
  self.classic
}

///|
pub fn CanAdapterCapabilities::can_fd(self : CanAdapterCapabilities) -> Bool {
  self.can_fd
}

///|
pub fn CanAdapterCapabilities::bitrate_switch(
  self : CanAdapterCapabilities,
) -> Bool {
  self.bitrate_switch
}

///|
pub fn CanAdapterCapabilities::listen_only(
  self : CanAdapterCapabilities,
) -> Bool {
  self.listen_only
}

///|
pub fn CanAdapterCapabilities::loopback(self : CanAdapterCapabilities) -> Bool {
  self.loopback
}

///|
pub fn CanAdapterCapabilities::timestamping(
  self : CanAdapterCapabilities,
) -> Bool {
  self.timestamping
}

///|
pub fn CanAdapterCapabilities::max_rx_queue(
  self : CanAdapterCapabilities,
) -> Int {
  self.max_rx_queue
}

///|
pub fn CanAdapterCapabilities::max_tx_queue(
  self : CanAdapterCapabilities,
) -> Int {
  self.max_tx_queue
}

///|
/// Configuration requested from an adapter before opening it.
pub struct CanAdapterConfig {
  nominal_bitrate_kbps : UInt
  data_bitrate_kbps : UInt
  listen_only : Bool
  loopback : Bool
  receive_own : Bool
  filter : Filter?
}

///|
pub fn can_adapter_config(
  nominal_bitrate_kbps? : UInt = 500,
  data_bitrate_kbps? : UInt = 2_000,
  listen_only? : Bool = false,
  loopback? : Bool = false,
  receive_own? : Bool = false,
  filter? : Filter? = None,
) -> CanAdapterConfig {
  {
    nominal_bitrate_kbps,
    data_bitrate_kbps,
    listen_only,
    loopback,
    receive_own,
    filter,
  }
}

///|
pub fn CanAdapterConfig::nominal_bitrate_kbps(self : CanAdapterConfig) -> UInt {
  self.nominal_bitrate_kbps
}

///|
pub fn CanAdapterConfig::data_bitrate_kbps(self : CanAdapterConfig) -> UInt {
  self.data_bitrate_kbps
}

///|
pub fn CanAdapterConfig::listen_only(self : CanAdapterConfig) -> Bool {
  self.listen_only
}

///|
pub fn CanAdapterConfig::loopback(self : CanAdapterConfig) -> Bool {
  self.loopback
}

///|
pub fn CanAdapterConfig::receive_own(self : CanAdapterConfig) -> Bool {
  self.receive_own
}

///|
pub fn CanAdapterConfig::filter(self : CanAdapterConfig) -> Filter? {
  self.filter
}

///|
/// Errors returned by the backend-neutral adapter façade.
pub suberror CanAdapterError {
  CanAdapterNotOpen
  CanAdapterAlreadyOpen
  CanAdapterBusOffError
  CanAdapterQueueFull
  CanAdapterUnsupported
  CanAdapterInvalidConfiguration
  CanAdapterRejectedFrame
}

///|
/// A timestamped frame delivered by an adapter.
pub struct CanAdapterMessage {
  timestamp_us : UInt64
  frame : Frame
  direction_tx : Bool
  sequence : UInt
}

///|
pub fn can_adapter_message(
  timestamp_us : UInt64,
  frame : Frame,
  direction_tx : Bool,
  sequence : UInt,
) -> CanAdapterMessage {
  { timestamp_us, frame, direction_tx, sequence }
}

///|
pub fn CanAdapterMessage::timestamp_us(self : CanAdapterMessage) -> UInt64 {
  self.timestamp_us
}

///|
pub fn CanAdapterMessage::frame(self : CanAdapterMessage) -> Frame {
  self.frame
}

///|
pub fn CanAdapterMessage::direction_tx(self : CanAdapterMessage) -> Bool {
  self.direction_tx
}

///|
pub fn CanAdapterMessage::sequence(self : CanAdapterMessage) -> UInt {
  self.sequence
}

///|
pub fn CanAdapterMessage::direction_text(self : CanAdapterMessage) -> String {
  if self.direction_tx {
    "tx"
  } else {
    "rx"
  }
}

///|
/// Counters maintained by a CAN adapter.
pub struct CanAdapterStats {
  mut transmitted : Int
  mut received : Int
  mut dropped_rx : Int
  mut rejected_tx : Int
  mut bus_off : Int
  mut error_frames : Int
  mut bytes_tx : Int
  mut bytes_rx : Int
}

///|
pub fn new_can_adapter_stats() -> CanAdapterStats {
  {
    transmitted: 0,
    received: 0,
    dropped_rx: 0,
    rejected_tx: 0,
    bus_off: 0,
    error_frames: 0,
    bytes_tx: 0,
    bytes_rx: 0,
  }
}

///|
pub fn CanAdapterStats::transmitted(self : CanAdapterStats) -> Int {
  self.transmitted
}

///|
pub fn CanAdapterStats::received(self : CanAdapterStats) -> Int {
  self.received
}

///|
pub fn CanAdapterStats::dropped_rx(self : CanAdapterStats) -> Int {
  self.dropped_rx
}

///|
pub fn CanAdapterStats::rejected_tx(self : CanAdapterStats) -> Int {
  self.rejected_tx
}

///|
pub fn CanAdapterStats::bus_off(self : CanAdapterStats) -> Int {
  self.bus_off
}

///|
pub fn CanAdapterStats::error_frames(self : CanAdapterStats) -> Int {
  self.error_frames
}

///|
pub fn CanAdapterStats::bytes_tx(self : CanAdapterStats) -> Int {
  self.bytes_tx
}

///|
pub fn CanAdapterStats::bytes_rx(self : CanAdapterStats) -> Int {
  self.bytes_rx
}

///|
pub fn CanAdapterStats::total(self : CanAdapterStats) -> Int {
  self.transmitted + self.received
}

///|
pub fn CanAdapterStats::to_text(self : CanAdapterStats) -> String {
  "tx=" +
  self.transmitted.to_string() +
  " rx=" +
  self.received.to_string() +
  " drop_rx=" +
  self.dropped_rx.to_string() +
  " reject_tx=" +
  self.rejected_tx.to_string()
}

///|
/// A deterministic in-memory adapter implementing the hardware contract.
pub struct CanPort {
  name : String
  capabilities : CanAdapterCapabilities
  mut config : CanAdapterConfig
  mut lifecycle : CanAdapterLifecycle
  rx_queue : Array[CanAdapterMessage]
  tx_queue : Array[CanAdapterMessage]
  mut sequence : UInt
  stats : CanAdapterStats
}

///|
pub fn new_can_port(
  name : String,
  capabilities? : CanAdapterCapabilities = can_adapter_capabilities(),
) -> CanPort {
  {
    name,
    capabilities,
    config: can_adapter_config(),
    lifecycle: CanAdapterCreated,
    rx_queue: [],
    tx_queue: [],
    sequence: 0,
    stats: new_can_adapter_stats(),
  }
}

///|
pub fn CanPort::name(self : CanPort) -> String {
  self.name
}

///|
pub fn CanPort::capabilities(self : CanPort) -> CanAdapterCapabilities {
  self.capabilities
}

///|
pub fn CanPort::config(self : CanPort) -> CanAdapterConfig {
  self.config
}

///|
pub fn CanPort::lifecycle(self : CanPort) -> CanAdapterLifecycle {
  self.lifecycle
}

///|
pub fn CanPort::stats(self : CanPort) -> CanAdapterStats {
  self.stats
}

///|
pub fn CanPort::configure(
  self : CanPort,
  config : CanAdapterConfig,
) -> Unit raise CanAdapterError {
  if self.lifecycle is CanAdapterOpen {
    raise CanAdapterAlreadyOpen
  }
  if config.nominal_bitrate_kbps() == 0 ||
    (config.data_bitrate_kbps() == 0 && self.capabilities.can_fd()) {
    raise CanAdapterInvalidConfiguration
  }
  if config.listen_only() && !self.capabilities.listen_only() {
    raise CanAdapterUnsupported
  }
  if config.loopback() && !self.capabilities.loopback() {
    raise CanAdapterUnsupported
  }
  self.config = config
  self.lifecycle = CanAdapterConfigured
}

///|
pub fn CanPort::open(self : CanPort) -> Unit raise CanAdapterError {
  match self.lifecycle {
    CanAdapterCreated => raise CanAdapterInvalidConfiguration
    CanAdapterConfigured | CanAdapterClosed => self.lifecycle = CanAdapterOpen
    CanAdapterOpen => raise CanAdapterAlreadyOpen
    CanAdapterBusOff => raise CanAdapterBusOffError
  }
}

///|
pub fn CanPort::close(self : CanPort) -> Unit {
  self.lifecycle = CanAdapterClosed
  self.rx_queue.clear()
  self.tx_queue.clear()
}

///|
pub fn CanPort::set_bus_off(self : CanPort) -> Unit {
  self.lifecycle = CanAdapterBusOff
  self.stats.bus_off += 1
}

///|
pub fn CanPort::recover(self : CanPort) -> Unit {
  self.lifecycle = CanAdapterConfigured
}

///|
pub fn CanPort::transmit(
  self : CanPort,
  timestamp_us : UInt64,
  frame : Frame,
) -> Unit raise CanAdapterError {
  if !(self.lifecycle is CanAdapterOpen) {
    raise CanAdapterNotOpen
  }
  if self.lifecycle is CanAdapterBusOff {
    raise CanAdapterBusOffError
  }
  if frame.is_error() {
    self.stats.rejected_tx += 1
    self.stats.error_frames += 1
    raise CanAdapterRejectedFrame
  }
  if self.config.filter is Some(filter) && !filter.matches(frame) {
    self.stats.rejected_tx += 1
    raise CanAdapterRejectedFrame
  }
  if self.tx_queue.length() >= self.capabilities.max_tx_queue() {
    self.stats.rejected_tx += 1
    raise CanAdapterQueueFull
  }
  self.sequence += 1
  self.tx_queue.push(
    can_adapter_message(timestamp_us, frame, true, self.sequence),
  )
  self.stats.transmitted += 1
  self.stats.bytes_tx += frame.data().length()
  if self.config.loopback() && self.config.receive_own() {
    ignore(self.inject(timestamp_us, frame))
  }
}

///|
pub fn CanPort::inject(
  self : CanPort,
  timestamp_us : UInt64,
  frame : Frame,
) -> Bool {
  if self.rx_queue.length() >= self.capabilities.max_rx_queue() {
    self.stats.dropped_rx += 1
    false
  } else if self.config.filter is Some(filter) && !filter.matches(frame) {
    false
  } else {
    self.sequence += 1
    self.rx_queue.push(
      can_adapter_message(timestamp_us, frame, false, self.sequence),
    )
    self.stats.received += 1
    self.stats.bytes_rx += frame.data().length()
    if frame.is_error() {
      self.stats.error_frames += 1
    }
    true
  }
}

///|
pub fn CanPort::receive(self : CanPort) -> CanAdapterMessage? {
  if self.rx_queue.is_empty() {
    None
  } else {
    Some(self.rx_queue.remove(0))
  }
}

///|
pub fn CanPort::drain_rx(
  self : CanPort,
  limit? : Int = 0,
) -> Array[CanAdapterMessage] {
  let result : Array[CanAdapterMessage] = []
  let maximum = if limit <= 0 || limit > self.rx_queue.length() {
    self.rx_queue.length()
  } else {
    limit
  }
  for _ in 0..<maximum {
    result.push(self.rx_queue.remove(0))
  }
  result
}

///|
pub fn CanPort::drain_tx(
  self : CanPort,
  limit? : Int = 0,
) -> Array[CanAdapterMessage] {
  let result : Array[CanAdapterMessage] = []
  let maximum = if limit <= 0 || limit > self.tx_queue.length() {
    self.tx_queue.length()
  } else {
    limit
  }
  for _ in 0..<maximum {
    result.push(self.tx_queue.remove(0))
  }
  result
}

///|
pub fn CanPort::rx_pending(self : CanPort) -> Int {
  self.rx_queue.length()
}

///|
pub fn CanPort::tx_pending(self : CanPort) -> Int {
  self.tx_queue.length()
}

///|
pub fn CanPort::is_ready(self : CanPort) -> Bool {
  self.lifecycle is CanAdapterOpen
}

///|
/// Estimate the wire completion time for a queued frame.
pub fn CanPort::completion_time_us(
  self : CanPort,
  message : CanAdapterMessage,
) -> UInt64 {
  let arbitration = can_frame_duration_us(
    message.frame(),
    self.config.nominal_bitrate_kbps(),
    self.config.data_bitrate_kbps(),
  )
  message.timestamp_us() + arbitration
}

///|
/// Return a queue snapshot ordered by timestamp then sequence.
pub fn CanPort::pending_tx(self : CanPort) -> Array[CanAdapterMessage] {
  let result = self.tx_queue.copy()
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
/// A collection of adapter ports used by a test harness.
pub struct CanAdapterHub {
  ports : Array[CanPort]
  mut routed : Int
  mut missed : Int
}

///|
pub fn new_can_adapter_hub() -> CanAdapterHub {
  { ports: [], routed: 0, missed: 0 }
}

///|
pub fn CanAdapterHub::add(self : CanAdapterHub, port : CanPort) -> Bool {
  if self.find(port.name()) is Some(_) {
    false
  } else {
    self.ports.push(port)
    true
  }
}

///|
pub fn CanAdapterHub::find(self : CanAdapterHub, name : String) -> CanPort? {
  for port in self.ports {
    if port.name() == name {
      return Some(port)
    }
  }
  None
}

///|
pub fn CanAdapterHub::broadcast(
  self : CanAdapterHub,
  source : String,
  timestamp_us : UInt64,
  frame : Frame,
) -> Int {
  let mut delivered = 0
  for port in self.ports {
    if port.name() != source && port.inject(timestamp_us, frame) {
      delivered += 1
    }
  }
  if delivered == 0 {
    self.missed += 1
  } else {
    self.routed += delivered
  }
  delivered
}

///|
pub fn CanAdapterHub::ports(self : CanAdapterHub) -> Array[CanPort] {
  self.ports.copy()
}

///|
pub fn CanAdapterHub::routed(self : CanAdapterHub) -> Int {
  self.routed
}

///|
pub fn CanAdapterHub::missed(self : CanAdapterHub) -> Int {
  self.missed
}

///|
pub fn CanAdapterHub::to_text(self : CanAdapterHub) -> String {
  let lines : Array[String] = []
  for port in self.ports {
    lines.push(port.name() + " " + port.stats().to_text())
  }
  lines.join("\n")
}

///|
/// Estimate a frame duration using the nominal and data bitrates.
pub fn can_frame_duration_us(
  frame : Frame,
  nominal_bitrate_kbps : UInt,
  data_bitrate_kbps : UInt,
) -> UInt64 {
  estimate_transmission_us(frame, nominal_bitrate_kbps, data_bitrate_kbps)
}
