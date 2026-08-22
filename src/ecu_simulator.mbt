///|
/// Access permission for a deterministic ECU memory region.
pub enum EcuMemoryPermission {
  EcuMemoryReadable
  EcuMemoryWritable
  EcuMemoryReadWrite
  EcuMemoryLocked
}

///|
pub fn ecu_memory_permission_variants() -> Array[EcuMemoryPermission] {
  [EcuMemoryReadable, EcuMemoryWritable, EcuMemoryReadWrite, EcuMemoryLocked]
}

///|
/// An addressable memory region exposed by an ECU simulator.
pub struct EcuMemoryRegion {
  start : UInt
  length : Int
  permission : EcuMemoryPermission
  bytes : Array[Byte]
}

///|
pub suberror EcuMemoryError {
  EcuMemoryOutOfRange
  EcuMemoryPermissionDenied
  EcuMemoryInvalidLength
  EcuMemoryOverlappingRegion
}

///|
/// Create a zero-initialized ECU memory region.
pub fn ecu_memory_region(
  start : UInt,
  length : Int,
  permission? : EcuMemoryPermission = EcuMemoryReadWrite,
) -> EcuMemoryRegion raise EcuMemoryError {
  if length < 0 {
    raise EcuMemoryInvalidLength
  }
  { start, length, permission, bytes: Array::make(length, 0) }
}

///|
pub fn EcuMemoryRegion::start(self : EcuMemoryRegion) -> UInt {
  self.start
}

///|
pub fn EcuMemoryRegion::length(self : EcuMemoryRegion) -> Int {
  self.length
}

///|
pub fn EcuMemoryRegion::permission(
  self : EcuMemoryRegion,
) -> EcuMemoryPermission {
  self.permission
}

///|
pub fn EcuMemoryRegion::contains(
  self : EcuMemoryRegion,
  address : UInt,
  length : Int,
) -> Bool {
  length >= 0 &&
  address >= self.start &&
  address - self.start <= self.length.reinterpret_as_uint() &&
  length <= self.length - (address - self.start).reinterpret_as_int()
}

///|
pub fn EcuMemoryRegion::read(
  self : EcuMemoryRegion,
  address : UInt,
  length : Int,
) -> Array[Byte] raise EcuMemoryError {
  if !self.contains(address, length) {
    raise EcuMemoryOutOfRange
  }
  match self.permission {
    EcuMemoryWritable | EcuMemoryLocked => raise EcuMemoryPermissionDenied
    _ =>
      self.bytes[address.reinterpret_as_int() - self.start.reinterpret_as_int():address.reinterpret_as_int() -
      self.start.reinterpret_as_int() +
      length].to_owned()
  }
}

///|
pub fn EcuMemoryRegion::write(
  self : EcuMemoryRegion,
  address : UInt,
  data : Array[Byte],
) -> Unit raise EcuMemoryError {
  if !self.contains(address, data.length()) {
    raise EcuMemoryOutOfRange
  }
  match self.permission {
    EcuMemoryReadable | EcuMemoryLocked => raise EcuMemoryPermissionDenied
    _ => {
      let offset = address.reinterpret_as_int() -
        self.start.reinterpret_as_int()
      for index, value in data {
        self.bytes[offset + index] = value
      }
    }
  }
}

///|
pub fn EcuMemoryRegion::fill(
  self : EcuMemoryRegion,
  value : Byte,
) -> Unit raise EcuMemoryError {
  match self.permission {
    EcuMemoryReadable | EcuMemoryLocked => raise EcuMemoryPermissionDenied
    _ =>
      for index in 0..<self.bytes.length() {
        self.bytes[index] = value
      }
  }
}

///|
pub fn EcuMemoryRegion::bytes(self : EcuMemoryRegion) -> Array[Byte] {
  self.bytes.copy()
}

///|
/// A collection of non-overlapping ECU memory regions.
pub struct EcuMemoryMap {
  regions : Array[EcuMemoryRegion]
  mut reads : Int
  mut writes : Int
}

///|
pub fn new_ecu_memory_map() -> EcuMemoryMap {
  { regions: [], reads: 0, writes: 0 }
}

///|
pub fn EcuMemoryMap::add(
  self : EcuMemoryMap,
  region : EcuMemoryRegion,
) -> Unit raise EcuMemoryError {
  for item in self.regions {
    let overlaps = region.start() <
      item.start() + item.length().reinterpret_as_uint() &&
      item.start() < region.start() + region.length().reinterpret_as_uint()
    if overlaps {
      raise EcuMemoryOverlappingRegion
    }
  }
  self.regions.push(region)
}

///|
pub fn EcuMemoryMap::find(
  self : EcuMemoryMap,
  address : UInt,
  length : Int,
) -> EcuMemoryRegion? {
  for region in self.regions {
    if region.contains(address, length) {
      return Some(region)
    }
  }
  None
}

///|
pub fn EcuMemoryMap::read(
  self : EcuMemoryMap,
  address : UInt,
  length : Int,
) -> Array[Byte] raise EcuMemoryError {
  match self.find(address, length) {
    Some(region) => {
      self.reads += 1
      region.read(address, length)
    }
    None => raise EcuMemoryOutOfRange
  }
}

///|
pub fn EcuMemoryMap::write(
  self : EcuMemoryMap,
  address : UInt,
  data : Array[Byte],
) -> Unit raise EcuMemoryError {
  match self.find(address, data.length()) {
    Some(region) => {
      self.writes += 1
      region.write(address, data)
    }
    None => raise EcuMemoryOutOfRange
  }
}

///|
pub fn EcuMemoryMap::regions(self : EcuMemoryMap) -> Array[EcuMemoryRegion] {
  self.regions.copy()
}

///|
pub fn EcuMemoryMap::length(self : EcuMemoryMap) -> Int {
  self.regions.length()
}

///|
pub fn EcuMemoryMap::reads(self : EcuMemoryMap) -> Int {
  self.reads
}

///|
pub fn EcuMemoryMap::writes(self : EcuMemoryMap) -> Int {
  self.writes
}

///|
/// Security access state maintained by an ECU endpoint.
pub enum EcuSecurityState {
  EcuSecurityLocked
  EcuSecuritySeedIssued(Byte)
  EcuSecurityUnlocked(Byte)
  EcuSecurityDelay(UInt64)
}

///|
pub fn ecu_security_state_variants() -> Array[EcuSecurityState] {
  [
    EcuSecurityLocked,
    EcuSecuritySeedIssued(1),
    EcuSecurityUnlocked(1),
    EcuSecurityDelay(0),
  ]
}

///|
/// Deterministic security access policy for tests and simulation.
pub struct EcuSecurityPolicy {
  level : Byte
  secret : UInt
  max_attempts : Int
  delay_us : UInt64
  mut attempts : Int
  mut state : EcuSecurityState
  mut seed_counter : UInt
}

///|
pub fn ecu_security_policy(
  level : Byte,
  secret : UInt,
  max_attempts? : Int = 3,
  delay_us? : UInt64 = 1_000_000,
) -> EcuSecurityPolicy {
  {
    level,
    secret,
    max_attempts: if max_attempts < 1 {
      1
    } else {
      max_attempts
    },
    delay_us,
    attempts: 0,
    state: EcuSecurityLocked,
    seed_counter: 0x1357,
  }
}

///|
pub fn EcuSecurityPolicy::level(self : EcuSecurityPolicy) -> Byte {
  self.level
}

///|
pub fn EcuSecurityPolicy::attempts(self : EcuSecurityPolicy) -> Int {
  self.attempts
}

///|
pub fn EcuSecurityPolicy::state(self : EcuSecurityPolicy) -> EcuSecurityState {
  self.state
}

///|
pub fn EcuSecurityPolicy::is_unlocked(self : EcuSecurityPolicy) -> Bool {
  self.state is EcuSecurityUnlocked(_)
}

///|
pub fn EcuSecurityPolicy::issue_seed(
  self : EcuSecurityPolicy,
  timestamp_us : UInt64,
) -> UInt {
  match self.state {
    EcuSecurityDelay(until) =>
      if timestamp_us < until {
        0
      } else {
        self.state = EcuSecurityLocked
        self.issue_seed(timestamp_us)
      }
    _ => {
      self.seed_counter = (self.seed_counter * 1103515245 + 12345) & 0x7FFFFFFF
      self.state = EcuSecuritySeedIssued(self.level)
      self.seed_counter
    }
  }
}

///|
pub fn EcuSecurityPolicy::expected_key(
  self : EcuSecurityPolicy,
  seed : UInt,
) -> UInt {
  ((seed ^ self.secret) + self.level.to_uint()) & 0xFFFFFFFF
}

///|
pub fn EcuSecurityPolicy::unlock(
  self : EcuSecurityPolicy,
  key : UInt,
  seed : UInt,
  timestamp_us : UInt64,
) -> Bool {
  if self.state is EcuSecurityDelay(until) && timestamp_us < until {
    false
  } else if self.state is EcuSecuritySeedIssued(_) &&
    key == self.expected_key(seed) {
    self.state = EcuSecurityUnlocked(self.level)
    self.attempts = 0
    true
  } else {
    self.attempts += 1
    if self.attempts >= self.max_attempts {
      self.state = EcuSecurityDelay(timestamp_us + self.delay_us)
      self.attempts = 0
    }
    false
  }
}

///|
pub fn EcuSecurityPolicy::lock(self : EcuSecurityPolicy) -> Unit {
  self.state = EcuSecurityLocked
}

///|
/// ECU reset kinds understood by the simulator.
pub enum EcuResetKind {
  EcuHardReset
  EcuKeyOffOnReset
  EcuSoftReset
  EcuResetBySupplier(Byte)
}

///|
pub fn ecu_reset_kind_variants() -> Array[EcuResetKind] {
  [EcuHardReset, EcuKeyOffOnReset, EcuSoftReset, EcuResetBySupplier(0)]
}

///|
/// The result of handling a diagnostic request at an ECU endpoint.
pub enum EcuRequestOutcome {
  EcuPositiveResponse(Array[Byte])
  EcuNegativeResponse(Byte)
  EcuRequestRejected(String)
}

///|
pub fn ecu_request_outcome_variants() -> Array[EcuRequestOutcome] {
  [
    EcuPositiveResponse([]),
    EcuNegativeResponse(0x11),
    EcuRequestRejected("example"),
  ]
}

///|
/// A deterministic ECU endpoint for integration testing.
pub struct EcuEndpoint {
  address : UInt
  name : String
  mut session : DiagnosticSessionProfile
  data : DiagnosticDataTable
  dtcs : DiagnosticTroubleCodeStore
  memory : EcuMemoryMap
  security : EcuSecurityPolicy
  mut reset_count : Int
  mut request_count : Int
  mut positive_count : Int
  mut negative_count : Int
  mut last_timestamp_us : UInt64
  mut pending_reset : EcuResetKind?
}

///|
/// Create an ECU endpoint with empty data, DTC and memory tables.
pub fn new_ecu_endpoint(
  address : UInt,
  name : String,
  security? : EcuSecurityPolicy = ecu_security_policy(1, 0xA5A55A5A),
) -> EcuEndpoint {
  {
    address,
    name,
    session: default_diagnostic_session(),
    data: new_diagnostic_data_table(),
    dtcs: new_diagnostic_trouble_code_store(64),
    memory: new_ecu_memory_map(),
    security,
    reset_count: 0,
    request_count: 0,
    positive_count: 0,
    negative_count: 0,
    last_timestamp_us: 0,
    pending_reset: None,
  }
}

///|
pub fn EcuEndpoint::address(self : EcuEndpoint) -> UInt {
  self.address
}

///|
pub fn EcuEndpoint::name(self : EcuEndpoint) -> String {
  self.name
}

///|
pub fn EcuEndpoint::session(self : EcuEndpoint) -> DiagnosticSessionProfile {
  self.session
}

///|
pub fn EcuEndpoint::data(self : EcuEndpoint) -> DiagnosticDataTable {
  self.data
}

///|
pub fn EcuEndpoint::dtcs(self : EcuEndpoint) -> DiagnosticTroubleCodeStore {
  self.dtcs
}

///|
pub fn EcuEndpoint::memory(self : EcuEndpoint) -> EcuMemoryMap {
  self.memory
}

///|
pub fn EcuEndpoint::security(self : EcuEndpoint) -> EcuSecurityPolicy {
  self.security
}

///|
pub fn EcuEndpoint::reset_count(self : EcuEndpoint) -> Int {
  self.reset_count
}

///|
pub fn EcuEndpoint::request_count(self : EcuEndpoint) -> Int {
  self.request_count
}

///|
pub fn EcuEndpoint::positive_count(self : EcuEndpoint) -> Int {
  self.positive_count
}

///|
pub fn EcuEndpoint::negative_count(self : EcuEndpoint) -> Int {
  self.negative_count
}

///|
pub fn EcuEndpoint::pending_reset(self : EcuEndpoint) -> EcuResetKind? {
  self.pending_reset
}

///|
pub fn EcuEndpoint::register_data(
  self : EcuEndpoint,
  item : DiagnosticDataIdentifier,
) -> Bool {
  self.data.add(item)
}

///|
pub fn EcuEndpoint::register_memory(
  self : EcuEndpoint,
  region : EcuMemoryRegion,
) -> Bool {
  try {
    self.memory.add(region)
    true
  } catch {
    _ => false
  }
}

///|
pub fn EcuEndpoint::record_dtc(
  self : EcuEndpoint,
  item : DiagnosticTroubleCode,
) -> Unit {
  self.dtcs.record(item)
}

///|
pub fn EcuEndpoint::clear_dtcs(
  self : EcuEndpoint,
  timestamp_us : UInt64,
) -> Unit {
  self.dtcs.clear(timestamp_us)
}

///|
/// Handle a request and update endpoint counters.
pub fn EcuEndpoint::handle(
  self : EcuEndpoint,
  request : DiagnosticRequest,
  timestamp_us : UInt64,
) -> EcuRequestOutcome {
  self.request_count += 1
  self.last_timestamp_us = timestamp_us
  let result = match request.service() {
    DiagnosticSessionControl => self.handle_session(request.payload())
    EcuReset => self.handle_reset(request.payload())
    ReadDataByIdentifier => self.handle_read_data(request.payload())
    WriteDataByIdentifier => self.handle_write_data(request.payload())
    ReadMemoryByAddress => self.handle_read_memory(request.payload())
    WriteMemoryByAddress => self.handle_write_memory(request.payload())
    SecurityAccess => self.handle_security(request.payload(), timestamp_us)
    ClearDiagnosticInformation =>
      self.handle_clear_dtc(request.payload(), timestamp_us)
    ReadDtcInformation => EcuPositiveResponse(self.dtcs.encode_report(AllDtc))
    TesterPresent => EcuPositiveResponse([0x7E, 0x00])
    _ => EcuNegativeResponse(0x11)
  }
  match result {
    EcuPositiveResponse(_) => self.positive_count += 1
    _ => self.negative_count += 1
  }
  result
}

///|
fn EcuEndpoint::handle_session(
  self : EcuEndpoint,
  payload : Array[Byte],
) -> EcuRequestOutcome {
  if payload.length() < 2 {
    EcuNegativeResponse(0x13)
  } else {
    let kind = match payload[1].to_int() {
      0x01 => DiagnosticSessionKind::DefaultSession
      0x02 => DiagnosticSessionKind::ProgrammingSession
      0x03 => DiagnosticSessionKind::ExtendedSession
      0x04 => DiagnosticSessionKind::SafetySystemSession
      value => DiagnosticSessionKind::SupplierSession(value.to_byte())
    }
    self.session = diagnostic_session_profile(
      kind, 50_000, 5_000_000, 5_000_000,
    )
    EcuPositiveResponse([0x50, payload[1], 0x00, 0x32, 0x01, 0xF4])
  }
}

///|
fn EcuEndpoint::handle_reset(
  self : EcuEndpoint,
  payload : Array[Byte],
) -> EcuRequestOutcome {
  if payload.length() < 2 {
    EcuNegativeResponse(0x13)
  } else {
    let kind = match payload[1].to_int() {
      0x01 => EcuHardReset
      0x02 => EcuKeyOffOnReset
      0x03 => EcuSoftReset
      value => EcuResetBySupplier(value.to_byte())
    }
    self.pending_reset = Some(kind)
    self.reset_count += 1
    EcuPositiveResponse([0x51, payload[1]])
  }
}

///|
fn EcuEndpoint::handle_read_data(
  self : EcuEndpoint,
  payload : Array[Byte],
) -> EcuRequestOutcome {
  if payload.length() < 3 {
    EcuNegativeResponse(0x13)
  } else {
    let identifier = (payload[1].to_uint() << 8) | payload[2].to_uint()
    match self.data.read(identifier) {
      Some(value) => EcuPositiveResponse([0x62, payload[1], payload[2]] + value)
      None => EcuNegativeResponse(0x31)
    }
  }
}

///|
fn EcuEndpoint::handle_write_data(
  self : EcuEndpoint,
  payload : Array[Byte],
) -> EcuRequestOutcome {
  if payload.length() < 3 {
    EcuNegativeResponse(0x13)
  } else {
    let identifier = (payload[1].to_uint() << 8) | payload[2].to_uint()
    if self.data.write(identifier, payload[3:].to_owned()) {
      EcuPositiveResponse([0x6E, payload[1], payload[2]])
    } else {
      EcuNegativeResponse(0x31)
    }
  }
}

///|
fn EcuEndpoint::handle_read_memory(
  self : EcuEndpoint,
  payload : Array[Byte],
) -> EcuRequestOutcome {
  if payload.length() < 5 {
    EcuNegativeResponse(0x13)
  } else {
    let address = (payload[1].to_uint() << 24) |
      (payload[2].to_uint() << 16) |
      (payload[3].to_uint() << 8) |
      payload[4].to_uint()
    let length = if payload.length() > 5 { payload[5].to_int() } else { 0 }
    let data = self.memory.read(address, length) catch { _ => [] }
    if data.length() != length {
      EcuNegativeResponse(0x31)
    } else {
      EcuPositiveResponse([0x63] + data)
    }
  }
}

///|
fn EcuEndpoint::handle_write_memory(
  self : EcuEndpoint,
  payload : Array[Byte],
) -> EcuRequestOutcome {
  if payload.length() < 6 {
    EcuNegativeResponse(0x13)
  } else {
    let address = (payload[1].to_uint() << 24) |
      (payload[2].to_uint() << 16) |
      (payload[3].to_uint() << 8) |
      payload[4].to_uint()
    let data = payload[5:].to_owned()
    if self.memory.find(address, data.length()) is None {
      EcuNegativeResponse(0x31)
    } else {
      ignore(self.memory.write(address, data) catch { _ => () })
      EcuPositiveResponse([0x7D])
    }
  }
}

///|
fn EcuEndpoint::handle_security(
  self : EcuEndpoint,
  payload : Array[Byte],
  timestamp_us : UInt64,
) -> EcuRequestOutcome {
  if payload.length() < 2 {
    EcuNegativeResponse(0x13)
  } else if (payload[1].to_int() & 1) == 1 {
    let seed = self.security.issue_seed(timestamp_us)
    EcuPositiveResponse([
      0x67,
      payload[1],
      (seed >> 8).to_byte(),
      seed.to_byte(),
    ])
  } else if payload.length() < 4 {
    EcuNegativeResponse(0x13)
  } else {
    let key = (payload[2].to_uint() << 8) | payload[3].to_uint()
    let unlocked = self.security.unlock(key, 0, timestamp_us)
    if unlocked {
      EcuPositiveResponse([0x67, payload[1]])
    } else {
      EcuNegativeResponse(0x35)
    }
  }
}

///|
fn EcuEndpoint::handle_clear_dtc(
  self : EcuEndpoint,
  payload : Array[Byte],
  timestamp_us : UInt64,
) -> EcuRequestOutcome {
  if payload.length() < 4 {
    EcuNegativeResponse(0x13)
  } else {
    self.dtcs.clear(timestamp_us)
    EcuPositiveResponse([0x54])
  }
}

///|
/// Return a compact endpoint health line for a simulation report.
pub fn EcuEndpoint::to_text(self : EcuEndpoint) -> String {
  "ecu=\{self.name} address=\{self.address} session=\{diagnostic_session_name(self.session.kind())} requests=\{self.request_count} positive=\{self.positive_count} negative=\{self.negative_count} dtcs=\{self.dtcs.length()}"
}

///|
/// A deterministic fleet of ECU endpoints.
pub struct EcuFleet {
  endpoints : Array[EcuEndpoint]
  mut routed : Int
  mut missed : Int
}

///|
pub fn new_ecu_fleet() -> EcuFleet {
  { endpoints: [], routed: 0, missed: 0 }
}

///|
pub fn EcuFleet::add(self : EcuFleet, endpoint : EcuEndpoint) -> Bool {
  if self.find(endpoint.address()) is Some(_) {
    false
  } else {
    self.endpoints.push(endpoint)
    true
  }
}

///|
pub fn EcuFleet::remove(self : EcuFleet, address : UInt) -> Bool {
  match self.find_index(address) {
    Some(index) => {
      ignore(self.endpoints.remove(index))
      true
    }
    None => false
  }
}

///|
pub fn EcuFleet::find(self : EcuFleet, address : UInt) -> EcuEndpoint? {
  match self.find_index(address) {
    Some(index) => Some(self.endpoints[index])
    None => None
  }
}

///|
pub fn EcuFleet::handle(
  self : EcuFleet,
  address : UInt,
  request : DiagnosticRequest,
  timestamp_us : UInt64,
) -> EcuRequestOutcome {
  match self.find(address) {
    Some(endpoint) => {
      self.routed += 1
      endpoint.handle(request, timestamp_us)
    }
    None => {
      self.missed += 1
      EcuRequestRejected("unknown ECU address")
    }
  }
}

///|
pub fn EcuFleet::length(self : EcuFleet) -> Int {
  self.endpoints.length()
}

///|
pub fn EcuFleet::routed(self : EcuFleet) -> Int {
  self.routed
}

///|
pub fn EcuFleet::missed(self : EcuFleet) -> Int {
  self.missed
}

///|
pub fn EcuFleet::endpoints(self : EcuFleet) -> Array[EcuEndpoint] {
  self.endpoints.copy()
}

///|
pub fn EcuFleet::to_text(self : EcuFleet) -> String {
  let lines : Array[String] = []
  for endpoint in self.endpoints {
    lines.push(endpoint.to_text())
  }
  lines.join("\n")
}

///|
fn EcuFleet::find_index(self : EcuFleet, address : UInt) -> Int? {
  for index, endpoint in self.endpoints {
    if endpoint.address() == address {
      return Some(index)
    }
  }
  None
}
