///|
/// A diagnostic application session defined by ISO 14229.
pub enum DiagnosticSessionKind {
  DefaultSession
  ProgrammingSession
  ExtendedSession
  SafetySystemSession
  SupplierSession(Byte)
}

///|
/// Construct all standard session variants for capability discovery.
pub fn diagnostic_session_kinds() -> Array[DiagnosticSessionKind] {
  [
    DefaultSession,
    ProgrammingSession,
    ExtendedSession,
    SafetySystemSession,
    SupplierSession(0),
  ]
}

///|
/// Addressing modes supported by a diagnostic transport endpoint.
pub enum DiagnosticAddressingMode {
  NormalAddressing
  ExtendedAddressing
  MixedAddressing(Byte)
}

///|
/// Construct the addressing modes accepted by the portable transport layer.
pub fn diagnostic_addressing_modes() -> Array[DiagnosticAddressingMode] {
  [NormalAddressing, ExtendedAddressing, MixedAddressing(0)]
}

///|
/// Timing and security policy for a diagnostic session.
pub struct DiagnosticSessionProfile {
  kind : DiagnosticSessionKind
  p2_server_us : UInt64
  p2_star_server_us : UInt64
  s3_server_us : UInt64
  addressing : DiagnosticAddressingMode
  security_level : Byte
}

///|
/// Create a standard diagnostic session profile.
pub fn diagnostic_session_profile(
  kind : DiagnosticSessionKind,
  p2_server_us : UInt64,
  p2_star_server_us : UInt64,
  s3_server_us : UInt64,
  addressing? : DiagnosticAddressingMode = NormalAddressing,
  security_level? : Byte = 0,
) -> DiagnosticSessionProfile {
  {
    kind,
    p2_server_us,
    p2_star_server_us,
    s3_server_us,
    addressing,
    security_level,
  }
}

///|
/// Return the default session profile used by a tester.
pub fn default_diagnostic_session() -> DiagnosticSessionProfile {
  diagnostic_session_profile(DefaultSession, 50_000, 5_000_000, 5_000_000)
}

///|
/// Return an extended diagnostic session profile.
pub fn extended_diagnostic_session() -> DiagnosticSessionProfile {
  diagnostic_session_profile(ExtendedSession, 50_000, 5_000_000, 5_000_000)
}

///|
/// Return a programming session profile.
pub fn programming_diagnostic_session() -> DiagnosticSessionProfile {
  diagnostic_session_profile(
    ProgrammingSession,
    50_000,
    10_000_000,
    10_000_000,
    addressing=NormalAddressing,
    security_level=1,
  )
}

///|
/// Return the session kind.
pub fn DiagnosticSessionProfile::kind(
  self : DiagnosticSessionProfile,
) -> DiagnosticSessionKind {
  self.kind
}

///|
/// Return the P2 timeout in microseconds.
pub fn DiagnosticSessionProfile::p2_server_us(
  self : DiagnosticSessionProfile,
) -> UInt64 {
  self.p2_server_us
}

///|
/// Return the P2-star timeout in microseconds.
pub fn DiagnosticSessionProfile::p2_star_server_us(
  self : DiagnosticSessionProfile,
) -> UInt64 {
  self.p2_star_server_us
}

///|
/// Return the S3 timeout in microseconds.
pub fn DiagnosticSessionProfile::s3_server_us(
  self : DiagnosticSessionProfile,
) -> UInt64 {
  self.s3_server_us
}

///|
/// Return the addressing mode.
pub fn DiagnosticSessionProfile::addressing(
  self : DiagnosticSessionProfile,
) -> DiagnosticAddressingMode {
  self.addressing
}

///|
/// Return the required security level.
pub fn DiagnosticSessionProfile::security_level(
  self : DiagnosticSessionProfile,
) -> Byte {
  self.security_level
}

///|
/// Return a stable session name for reports.
pub fn diagnostic_session_name(kind : DiagnosticSessionKind) -> String {
  match kind {
    DefaultSession => "default"
    ProgrammingSession => "programming"
    ExtendedSession => "extended"
    SafetySystemSession => "safety-system"
    SupplierSession(number) => "supplier-\{number}"
  }
}

///|
/// Return whether the session should be kept alive by TesterPresent.
pub fn diagnostic_session_requires_keepalive(
  profile : DiagnosticSessionProfile,
) -> Bool {
  profile.s3_server_us > 0
}

///|
/// Return the next TesterPresent deadline.
pub fn diagnostic_keepalive_deadline(
  profile : DiagnosticSessionProfile,
  now_us : UInt64,
) -> UInt64 {
  now_us + profile.s3_server_us / 2
}

///|
/// A status bit set used by a stored diagnostic trouble code.
pub enum DtcStatusBit {
  TestFailed
  TestFailedThisOperationCycle
  PendingDtc
  ConfirmedDtc
  TestNotCompletedSinceClear
  TestFailedSinceClear
  TestNotCompletedThisOperationCycle
  WarningIndicatorRequested
}

///|
/// A normalized diagnostic trouble code record.
pub struct DiagnosticTroubleCode {
  code : UInt
  mut status : Byte
  severity : Byte
  mut occurrence_count : Int
  mut snapshot : Array[Byte]
  mut extended_data : Array[Byte]
  mut last_seen_us : UInt64
}

///|
/// Create a diagnostic trouble code record.
pub fn diagnostic_trouble_code(
  code : UInt,
  status : Byte,
  severity? : Byte = 0,
  snapshot? : Array[Byte] = [],
  extended_data? : Array[Byte] = [],
  timestamp_us? : UInt64 = 0,
) -> DiagnosticTroubleCode {
  {
    code,
    status,
    severity,
    occurrence_count: 1,
    snapshot: snapshot.copy(),
    extended_data: extended_data.copy(),
    last_seen_us: timestamp_us,
  }
}

///|
/// Return the numeric DTC code.
pub fn DiagnosticTroubleCode::code(self : DiagnosticTroubleCode) -> UInt {
  self.code
}

///|
/// Return the raw UDS status byte.
pub fn DiagnosticTroubleCode::status(self : DiagnosticTroubleCode) -> Byte {
  self.status
}

///|
/// Return the configured severity byte.
pub fn DiagnosticTroubleCode::severity(self : DiagnosticTroubleCode) -> Byte {
  self.severity
}

///|
/// Return the number of observed occurrences.
pub fn DiagnosticTroubleCode::occurrence_count(
  self : DiagnosticTroubleCode,
) -> Int {
  self.occurrence_count
}

///|
/// Return a copy of the freeze-frame snapshot.
pub fn DiagnosticTroubleCode::snapshot(
  self : DiagnosticTroubleCode,
) -> Array[Byte] {
  self.snapshot.copy()
}

///|
/// Return a copy of the extended DTC data.
pub fn DiagnosticTroubleCode::extended_data(
  self : DiagnosticTroubleCode,
) -> Array[Byte] {
  self.extended_data.copy()
}

///|
/// Return the most recent observation timestamp.
pub fn DiagnosticTroubleCode::last_seen_us(
  self : DiagnosticTroubleCode,
) -> UInt64 {
  self.last_seen_us
}

///|
/// Return whether a status bit is set.
pub fn DiagnosticTroubleCode::has_status(
  self : DiagnosticTroubleCode,
  bit : DtcStatusBit,
) -> Bool {
  let mask = match bit {
    TestFailed => 0x01
    TestFailedThisOperationCycle => 0x02
    PendingDtc => 0x04
    ConfirmedDtc => 0x08
    TestNotCompletedSinceClear => 0x10
    TestFailedSinceClear => 0x20
    TestNotCompletedThisOperationCycle => 0x40
    WarningIndicatorRequested => 0x80
  }
  (self.status.to_int() & mask) != 0
}

///|
/// Return a human-readable status summary.
pub fn DiagnosticTroubleCode::status_text(
  self : DiagnosticTroubleCode,
) -> String {
  let names : Array[String] = []
  let bits : Array[DtcStatusBit] = [
    TestFailed,
    TestFailedThisOperationCycle,
    PendingDtc,
    ConfirmedDtc,
    TestNotCompletedSinceClear,
    TestFailedSinceClear,
    TestNotCompletedThisOperationCycle,
    WarningIndicatorRequested,
  ]
  let labels : Array[String] = [
    "failed", "failed-this-cycle", "pending", "confirmed", "not-completed-since-clear",
    "failed-since-clear", "not-completed-this-cycle", "warning-requested",
  ]
  for index, item in bits {
    if self.has_status(item) {
      names.push(labels[index])
    }
  }
  if names.is_empty() {
    "clear"
  } else {
    names.join("|")
  }
}

///|
/// Apply a new observation to a DTC record.
pub fn DiagnosticTroubleCode::observe(
  self : DiagnosticTroubleCode,
  status : Byte,
  timestamp_us : UInt64,
) -> Unit {
  self.status = status
  self.last_seen_us = timestamp_us
  self.occurrence_count += 1
}

///|
/// Add or update a freeze-frame snapshot.
pub fn DiagnosticTroubleCode::set_snapshot(
  self : DiagnosticTroubleCode,
  data : Array[Byte],
) -> Unit {
  self.snapshot = data.copy()
}

///|
/// Add or update extended DTC data.
pub fn DiagnosticTroubleCode::set_extended_data(
  self : DiagnosticTroubleCode,
  data : Array[Byte],
) -> Unit {
  self.extended_data = data.copy()
}

///|
/// Serialize a DTC into the three-byte code plus status byte form.
pub fn DiagnosticTroubleCode::to_bytes(
  self : DiagnosticTroubleCode,
) -> Array[Byte] {
  [
    (self.code >> 16).to_byte(),
    (self.code >> 8).to_byte(),
    self.code.to_byte(),
    self.status,
  ]
}

///|
/// A DTC query selector.
pub enum DtcQuery {
  AllDtc
  ByCode(UInt)
  ByStatusMask(Byte)
  BySeverityAtLeast(Byte)
  ConfirmedOnly
  WarningOnly
  SeenAfter(UInt64)
}

///|
/// Construct representative selectors for a diagnostic UI.
pub fn diagnostic_dtc_queries() -> Array[DtcQuery] {
  [
    AllDtc,
    ByCode(0),
    ByStatusMask(0x08),
    BySeverityAtLeast(1),
    ConfirmedOnly,
    WarningOnly,
    SeenAfter(0),
  ]
}

///|
/// Return whether a DTC matches a query selector.
pub fn dtc_matches(dtc : DiagnosticTroubleCode, query : DtcQuery) -> Bool {
  match query {
    AllDtc => true
    ByCode(code) => dtc.code() == code
    ByStatusMask(mask) => (dtc.status().to_int() & mask.to_int()) != 0
    BySeverityAtLeast(level) => dtc.severity().to_int() >= level.to_int()
    ConfirmedOnly => dtc.has_status(ConfirmedDtc)
    WarningOnly => dtc.has_status(WarningIndicatorRequested)
    SeenAfter(timestamp) => dtc.last_seen_us() > timestamp
  }
}

///|
/// A bounded DTC store suitable for an ECU simulator or gateway.
pub struct DiagnosticTroubleCodeStore {
  capacity : Int
  records : Array[DiagnosticTroubleCode]
  mut generation : UInt
  mut cleared_at_us : UInt64
}

///|
/// Create an empty bounded DTC store.
pub fn new_diagnostic_trouble_code_store(
  capacity : Int,
) -> DiagnosticTroubleCodeStore {
  {
    capacity: if capacity < 1 {
      1
    } else {
      capacity
    },
    records: [],
    generation: 0,
    cleared_at_us: 0,
  }
}

///|
/// Return the configured store capacity.
pub fn DiagnosticTroubleCodeStore::capacity(
  self : DiagnosticTroubleCodeStore,
) -> Int {
  self.capacity
}

///|
/// Return the number of stored DTCs.
pub fn DiagnosticTroubleCodeStore::length(
  self : DiagnosticTroubleCodeStore,
) -> Int {
  self.records.length()
}

///|
/// Return the mutation generation.
pub fn DiagnosticTroubleCodeStore::generation(
  self : DiagnosticTroubleCodeStore,
) -> UInt {
  self.generation
}

///|
/// Return the timestamp of the last clear operation.
pub fn DiagnosticTroubleCodeStore::cleared_at_us(
  self : DiagnosticTroubleCodeStore,
) -> UInt64 {
  self.cleared_at_us
}

///|
/// Add a new DTC or update an existing code.
pub fn DiagnosticTroubleCodeStore::record(
  self : DiagnosticTroubleCodeStore,
  item : DiagnosticTroubleCode,
) -> Unit {
  match self.find_index(item.code()) {
    Some(index) => {
      self.records[index].observe(item.status(), item.last_seen_us())
      self.records[index].set_snapshot(item.snapshot())
      self.records[index].set_extended_data(item.extended_data())
    }
    None => {
      if self.records.length() >= self.capacity {
        ignore(self.records.remove(0))
      }
      self.records.push(item)
    }
  }
  self.generation += 1
}

///|
/// Find a DTC by numeric code.
pub fn DiagnosticTroubleCodeStore::find(
  self : DiagnosticTroubleCodeStore,
  code : UInt,
) -> DiagnosticTroubleCode? {
  match self.find_index(code) {
    Some(index) => Some(self.records[index])
    None => None
  }
}

///|
/// Query all matching DTCs in insertion order.
pub fn DiagnosticTroubleCodeStore::query(
  self : DiagnosticTroubleCodeStore,
  selector : DtcQuery,
) -> Array[DiagnosticTroubleCode] {
  let result : Array[DiagnosticTroubleCode] = []
  for item in self.records {
    if dtc_matches(item, selector) {
      result.push(item)
    }
  }
  result
}

///|
/// Return a defensive copy of all records.
pub fn DiagnosticTroubleCodeStore::records(
  self : DiagnosticTroubleCodeStore,
) -> Array[DiagnosticTroubleCode] {
  self.records.copy()
}

///|
/// Clear all records and update the clear timestamp.
pub fn DiagnosticTroubleCodeStore::clear(
  self : DiagnosticTroubleCodeStore,
  timestamp_us : UInt64,
) -> Unit {
  self.records.clear()
  self.cleared_at_us = timestamp_us
  self.generation += 1
}

///|
/// Remove one DTC by code and return whether it existed.
pub fn DiagnosticTroubleCodeStore::remove(
  self : DiagnosticTroubleCodeStore,
  code : UInt,
) -> Bool {
  match self.find_index(code) {
    Some(index) => {
      ignore(self.records.remove(index))
      self.generation += 1
      true
    }
    None => false
  }
}

///|
/// Mark every stored DTC as not completed since clear.
pub fn DiagnosticTroubleCodeStore::mark_cycle_start(
  self : DiagnosticTroubleCodeStore,
) -> Unit {
  for index in 0..<self.records.length() {
    let item = self.records[index]
    self.records[index].status = (item.status().to_int() | 0x10).to_byte()
  }
  self.generation += 1
}

///|
/// Return all DTC codes sorted numerically.
pub fn DiagnosticTroubleCodeStore::codes(
  self : DiagnosticTroubleCodeStore,
) -> Array[UInt] {
  let result : Array[UInt] = []
  for item in self.records {
    result.push(item.code())
  }
  result.sort()
  result
}

///|
/// Encode a DTC response payload for ReadDTCInformation.
pub fn DiagnosticTroubleCodeStore::encode_report(
  self : DiagnosticTroubleCodeStore,
  selector : DtcQuery,
  limit? : Int = 0,
) -> Array[Byte] {
  let items = self.query(selector)
  let result : Array[Byte] = [items.length().to_byte()]
  let maximum = if limit <= 0 || limit > items.length() {
    items.length()
  } else {
    limit
  }
  for index in 0..<maximum {
    result.append(items[index].to_bytes())
  }
  result
}

///|
fn DiagnosticTroubleCodeStore::find_index(
  self : DiagnosticTroubleCodeStore,
  code : UInt,
) -> Int? {
  for index, item in self.records {
    if item.code() == code {
      return Some(index)
    }
  }
  None
}

///|
/// A data identifier entry exposed by an ECU.
pub struct DiagnosticDataIdentifier {
  identifier : UInt
  name : String
  length : Int
  readable : Bool
  writable : Bool
  mut value : Array[Byte]
}

///|
/// Create a data identifier entry.
pub fn diagnostic_data_identifier(
  identifier : UInt,
  name : String,
  length : Int,
  readable? : Bool = true,
  writable? : Bool = false,
  initial? : Array[Byte] = [],
) -> DiagnosticDataIdentifier {
  {
    identifier,
    name,
    length: if length < 0 {
      0
    } else {
      length
    },
    readable,
    writable,
    value: initial.copy(),
  }
}

///|
pub fn DiagnosticDataIdentifier::identifier(
  self : DiagnosticDataIdentifier,
) -> UInt {
  self.identifier
}

///|
pub fn DiagnosticDataIdentifier::name(
  self : DiagnosticDataIdentifier,
) -> String {
  self.name
}

///|
pub fn DiagnosticDataIdentifier::length(self : DiagnosticDataIdentifier) -> Int {
  self.length
}

///|
pub fn DiagnosticDataIdentifier::readable(
  self : DiagnosticDataIdentifier,
) -> Bool {
  self.readable
}

///|
pub fn DiagnosticDataIdentifier::writable(
  self : DiagnosticDataIdentifier,
) -> Bool {
  self.writable
}

///|
pub fn DiagnosticDataIdentifier::value(
  self : DiagnosticDataIdentifier,
) -> Array[Byte] {
  self.value.copy()
}

///|
/// Update a DID value, applying the configured maximum length.
pub fn DiagnosticDataIdentifier::set_value(
  self : DiagnosticDataIdentifier,
  value : Array[Byte],
) -> Bool {
  if !self.writable || value.length() > self.length {
    false
  } else {
    self.value = value.copy()
    true
  }
}

///|
/// Return the readable value padded to the configured length.
pub fn DiagnosticDataIdentifier::read_value(
  self : DiagnosticDataIdentifier,
) -> Array[Byte] {
  let result = self.value.copy()
  while result.length() < self.length {
    result.push(0)
  }
  result
}

///|
/// A table of ECU data identifiers.
pub struct DiagnosticDataTable {
  entries : Array[DiagnosticDataIdentifier]
  mut revision : UInt
}

///|
pub fn new_diagnostic_data_table() -> DiagnosticDataTable {
  { entries: [], revision: 0 }
}

///|
pub fn DiagnosticDataTable::add(
  self : DiagnosticDataTable,
  entry : DiagnosticDataIdentifier,
) -> Bool {
  if self.find(entry.identifier()) is Some(_) {
    false
  } else {
    self.entries.push(entry)
    self.revision += 1
    true
  }
}

///|
pub fn DiagnosticDataTable::replace(
  self : DiagnosticDataTable,
  entry : DiagnosticDataIdentifier,
) -> Bool {
  match self.find_index(entry.identifier()) {
    Some(index) => {
      self.entries[index] = entry
      self.revision += 1
      true
    }
    None => false
  }
}

///|
pub fn DiagnosticDataTable::find(
  self : DiagnosticDataTable,
  identifier : UInt,
) -> DiagnosticDataIdentifier? {
  match self.find_index(identifier) {
    Some(index) => Some(self.entries[index])
    None => None
  }
}

///|
pub fn DiagnosticDataTable::read(
  self : DiagnosticDataTable,
  identifier : UInt,
) -> Array[Byte]? {
  match self.find(identifier) {
    Some(entry) =>
      if entry.readable() {
        Some(entry.read_value())
      } else {
        None
      }
    None => None
  }
}

///|
pub fn DiagnosticDataTable::write(
  self : DiagnosticDataTable,
  identifier : UInt,
  value : Array[Byte],
) -> Bool {
  match self.find_index(identifier) {
    Some(index) => {
      let changed = self.entries[index].set_value(value)
      if changed {
        self.revision += 1
      }
      changed
    }
    None => false
  }
}

///|
pub fn DiagnosticDataTable::length(self : DiagnosticDataTable) -> Int {
  self.entries.length()
}

///|
pub fn DiagnosticDataTable::revision(self : DiagnosticDataTable) -> UInt {
  self.revision
}

///|
pub fn DiagnosticDataTable::entries(
  self : DiagnosticDataTable,
) -> Array[DiagnosticDataIdentifier] {
  self.entries.copy()
}

///|
pub fn DiagnosticDataTable::identifiers(
  self : DiagnosticDataTable,
) -> Array[UInt] {
  let result : Array[UInt] = []
  for entry in self.entries {
    result.push(entry.identifier())
  }
  result.sort()
  result
}

///|
pub fn DiagnosticDataTable::to_text(self : DiagnosticDataTable) -> String {
  let lines : Array[String] = []
  for entry in self.entries {
    lines.push(
      "0x\{entry.identifier().to_string()} \{entry.name()} len=\{entry.length()} read=\{entry.readable()} write=\{entry.writable()}",
    )
  }
  lines.join("\n")
}

///|
fn DiagnosticDataTable::find_index(
  self : DiagnosticDataTable,
  identifier : UInt,
) -> Int? {
  for index, entry in self.entries {
    if entry.identifier() == identifier {
      return Some(index)
    }
  }
  None
}

///|
/// A diagnostic event suitable for a tester trace.
pub struct DiagnosticEvent {
  timestamp_us : UInt64
  request : DiagnosticRequest
  response : Array[Byte]
  positive : Bool
  duration_us : UInt64
}

///|
pub fn diagnostic_event(
  timestamp_us : UInt64,
  request : DiagnosticRequest,
  response : Array[Byte],
  duration_us : UInt64,
) -> DiagnosticEvent {
  {
    timestamp_us,
    request,
    response: response.copy(),
    positive: !response.is_empty() && response[0].to_int() != 0x7F,
    duration_us,
  }
}

///|
pub fn DiagnosticEvent::timestamp_us(self : DiagnosticEvent) -> UInt64 {
  self.timestamp_us
}

///|
pub fn DiagnosticEvent::request(self : DiagnosticEvent) -> DiagnosticRequest {
  self.request
}

///|
pub fn DiagnosticEvent::response(self : DiagnosticEvent) -> Array[Byte] {
  self.response.copy()
}

///|
pub fn DiagnosticEvent::positive(self : DiagnosticEvent) -> Bool {
  self.positive
}

///|
pub fn DiagnosticEvent::duration_us(self : DiagnosticEvent) -> UInt64 {
  self.duration_us
}

///|
/// An ordered diagnostic exchange log.
pub struct DiagnosticExchangeLog {
  events : Array[DiagnosticEvent]
  mut positive_count : Int
  mut negative_count : Int
}

///|
pub fn new_diagnostic_exchange_log() -> DiagnosticExchangeLog {
  { events: [], positive_count: 0, negative_count: 0 }
}

///|
pub fn DiagnosticExchangeLog::record(
  self : DiagnosticExchangeLog,
  event : DiagnosticEvent,
) -> Unit {
  self.events.push(event)
  if event.positive() {
    self.positive_count += 1
  } else {
    self.negative_count += 1
  }
}

///|
pub fn DiagnosticExchangeLog::events(
  self : DiagnosticExchangeLog,
) -> Array[DiagnosticEvent] {
  self.events.copy()
}

///|
pub fn DiagnosticExchangeLog::length(self : DiagnosticExchangeLog) -> Int {
  self.events.length()
}

///|
pub fn DiagnosticExchangeLog::positive_count(
  self : DiagnosticExchangeLog,
) -> Int {
  self.positive_count
}

///|
pub fn DiagnosticExchangeLog::negative_count(
  self : DiagnosticExchangeLog,
) -> Int {
  self.negative_count
}

///|
pub fn DiagnosticExchangeLog::average_duration_us(
  self : DiagnosticExchangeLog,
) -> UInt64 {
  if self.events.is_empty() {
    0
  } else {
    let mut total : UInt64 = 0
    for event in self.events {
      total += event.duration_us()
    }
    total / self.events.length().to_uint64()
  }
}

///|
pub fn DiagnosticExchangeLog::failed_services(
  self : DiagnosticExchangeLog,
) -> Array[String] {
  let result : Array[String] = []
  for event in self.events {
    if !event.positive() {
      result.push(event.request().service_name())
    }
  }
  result
}

///|
pub fn DiagnosticExchangeLog::to_text(self : DiagnosticExchangeLog) -> String {
  let lines : Array[String] = []
  for event in self.events {
    lines.push(
      "t=\{event.timestamp_us()} service=\{event.request().service_name()} positive=\{event.positive()} duration_us=\{event.duration_us()}",
    )
  }
  lines.join("\n")
}
