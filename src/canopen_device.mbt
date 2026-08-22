///|
/// CANopen NMT state maintained by a device model.
pub enum CanOpenDeviceState {
  CanOpenDeviceInitializing
  CanOpenDevicePreOperational
  CanOpenDeviceOperational
  CanOpenDeviceStopped
  CanOpenDeviceResetting
}

///|
pub fn canopen_device_state_variants() -> Array[CanOpenDeviceState] {
  [
    CanOpenDeviceInitializing,
    CanOpenDevicePreOperational,
    CanOpenDeviceOperational,
    CanOpenDeviceStopped,
    CanOpenDeviceResetting,
  ]
}

///|
/// Object-dictionary access rights.
pub enum CanOpenObjectAccess {
  CanOpenObjectReadOnly
  CanOpenObjectWriteOnly
  CanOpenObjectReadWrite
  CanOpenObjectConstant
}

///|
pub fn canopen_object_access_variants() -> Array[CanOpenObjectAccess] {
  [
    CanOpenObjectReadOnly,
    CanOpenObjectWriteOnly,
    CanOpenObjectReadWrite,
    CanOpenObjectConstant,
  ]
}

///|
/// A typed object-dictionary entry.
pub struct CanOpenObjectEntry {
  index : UInt
  sub_index : Byte
  name : String
  access : CanOpenObjectAccess
  mut data : Array[Byte]
  max_length : Int
  mut revision : UInt
}

///|
pub fn canopen_object_entry(
  index : UInt,
  sub_index : Byte,
  name : String,
  access? : CanOpenObjectAccess = CanOpenObjectReadWrite,
  initial? : Array[Byte] = [],
  max_length? : Int = 8,
) -> CanOpenObjectEntry {
  {
    index,
    sub_index,
    name,
    access,
    data: initial.copy(),
    max_length: if max_length < 0 {
      0
    } else {
      max_length
    },
    revision: 0,
  }
}

///|
pub fn CanOpenObjectEntry::index(self : CanOpenObjectEntry) -> UInt {
  self.index
}

///|
pub fn CanOpenObjectEntry::sub_index(self : CanOpenObjectEntry) -> Byte {
  self.sub_index
}

///|
pub fn CanOpenObjectEntry::name(self : CanOpenObjectEntry) -> String {
  self.name
}

///|
pub fn CanOpenObjectEntry::access(
  self : CanOpenObjectEntry,
) -> CanOpenObjectAccess {
  self.access
}

///|
pub fn CanOpenObjectEntry::data(self : CanOpenObjectEntry) -> Array[Byte] {
  self.data.copy()
}

///|
pub fn CanOpenObjectEntry::max_length(self : CanOpenObjectEntry) -> Int {
  self.max_length
}

///|
pub fn CanOpenObjectEntry::revision(self : CanOpenObjectEntry) -> UInt {
  self.revision
}

///|
pub fn CanOpenObjectEntry::readable(self : CanOpenObjectEntry) -> Bool {
  match self.access {
    CanOpenObjectWriteOnly => false
    _ => true
  }
}

///|
pub fn CanOpenObjectEntry::writable(self : CanOpenObjectEntry) -> Bool {
  match self.access {
    CanOpenObjectReadOnly | CanOpenObjectConstant => false
    _ => true
  }
}

///|
pub fn CanOpenObjectEntry::read(self : CanOpenObjectEntry) -> Array[Byte]? {
  if self.readable() {
    Some(self.data.copy())
  } else {
    None
  }
}

///|
pub fn CanOpenObjectEntry::write(
  self : CanOpenObjectEntry,
  data : Array[Byte],
) -> Bool {
  if !self.writable() || data.length() > self.max_length {
    false
  } else {
    self.data = data.copy()
    self.revision += 1
    true
  }
}

///|
pub fn CanOpenObjectEntry::to_text(self : CanOpenObjectEntry) -> String {
  "0x" +
  self.index.to_string() +
  ":" +
  self.sub_index.to_string() +
  " " +
  self.name +
  " len=" +
  self.data.length().to_string()
}

///|
/// A bounded object dictionary.
pub struct CanOpenObjectDictionary {
  entries : Array[CanOpenObjectEntry]
  mut revision : UInt
  capacity : Int
}

///|
pub fn new_canopen_object_dictionary(
  capacity? : Int = 1024,
) -> CanOpenObjectDictionary {
  {
    entries: [],
    revision: 0,
    capacity: if capacity < 1 {
      1
    } else {
      capacity
    },
  }
}

///|
pub fn CanOpenObjectDictionary::add(
  self : CanOpenObjectDictionary,
  entry : CanOpenObjectEntry,
) -> Bool {
  if self.entries.length() >= self.capacity ||
    self.find(entry.index(), entry.sub_index()) is Some(_) {
    false
  } else {
    self.entries.push(entry)
    self.revision += 1
    true
  }
}

///|
pub fn CanOpenObjectDictionary::replace(
  self : CanOpenObjectDictionary,
  entry : CanOpenObjectEntry,
) -> Bool {
  match self.find_index(entry.index(), entry.sub_index()) {
    Some(index) => {
      self.entries[index] = entry
      self.revision += 1
      true
    }
    None => false
  }
}

///|
pub fn CanOpenObjectDictionary::find(
  self : CanOpenObjectDictionary,
  index : UInt,
  sub_index : Byte,
) -> CanOpenObjectEntry? {
  match self.find_index(index, sub_index) {
    Some(position) => Some(self.entries[position])
    None => None
  }
}

///|
pub fn CanOpenObjectDictionary::read(
  self : CanOpenObjectDictionary,
  index : UInt,
  sub_index : Byte,
) -> Array[Byte]? {
  match self.find(index, sub_index) {
    Some(entry) => entry.read()
    None => None
  }
}

///|
pub fn CanOpenObjectDictionary::write(
  self : CanOpenObjectDictionary,
  index : UInt,
  sub_index : Byte,
  data : Array[Byte],
) -> Bool {
  match self.find(index, sub_index) {
    Some(entry) => entry.write(data)
    None => false
  }
}

///|
pub fn CanOpenObjectDictionary::entries(
  self : CanOpenObjectDictionary,
) -> Array[CanOpenObjectEntry] {
  self.entries.copy()
}

///|
pub fn CanOpenObjectDictionary::length(self : CanOpenObjectDictionary) -> Int {
  self.entries.length()
}

///|
pub fn CanOpenObjectDictionary::revision(
  self : CanOpenObjectDictionary,
) -> UInt {
  self.revision
}

///|
pub fn CanOpenObjectDictionary::indices(
  self : CanOpenObjectDictionary,
) -> Array[UInt] {
  let result : Array[UInt] = []
  for entry in self.entries {
    if !result.contains(entry.index()) {
      result.push(entry.index())
    }
  }
  result.sort()
  result
}

///|
pub fn CanOpenObjectDictionary::to_text(
  self : CanOpenObjectDictionary,
) -> String {
  let lines : Array[String] = []
  for entry in self.entries {
    lines.push(entry.to_text())
  }
  lines.join("\n")
}

///|
fn CanOpenObjectDictionary::find_index(
  self : CanOpenObjectDictionary,
  index : UInt,
  sub_index : Byte,
) -> Int? {
  for position, entry in self.entries {
    if entry.index() == index && entry.sub_index() == sub_index {
      return Some(position)
    }
  }
  None
}

///|
/// Result of an SDO access handled by a device.
pub enum CanOpenDeviceSdoResult {
  CanOpenDeviceSdoUploaded(Array[Byte])
  CanOpenDeviceSdoDownloaded
  CanOpenDeviceSdoAbort(UInt)
}

///|
pub fn canopen_device_sdo_result_variants() -> Array[CanOpenDeviceSdoResult] {
  [
    CanOpenDeviceSdoUploaded([]),
    CanOpenDeviceSdoDownloaded,
    CanOpenDeviceSdoAbort(0),
  ]
}

///|
/// Stateful SDO transfer context.
pub struct CanOpenDeviceSdoSession {
  index : UInt
  sub_index : Byte
  upload : Bool
  data : Array[Byte]
  mut offset : Int
  mut toggle : Bool
  block_size : Int
}

///|
pub fn canopen_device_sdo_session(
  index : UInt,
  sub_index : Byte,
  upload : Bool,
  data : Array[Byte],
  block_size? : Int = 7,
) -> CanOpenDeviceSdoSession {
  {
    index,
    sub_index,
    upload,
    data: data.copy(),
    offset: 0,
    toggle: false,
    block_size: if block_size < 1 {
      1
    } else {
      block_size
    },
  }
}

///|
pub fn CanOpenDeviceSdoSession::index(self : CanOpenDeviceSdoSession) -> UInt {
  self.index
}

///|
pub fn CanOpenDeviceSdoSession::sub_index(
  self : CanOpenDeviceSdoSession,
) -> Byte {
  self.sub_index
}

///|
pub fn CanOpenDeviceSdoSession::upload(self : CanOpenDeviceSdoSession) -> Bool {
  self.upload
}

///|
pub fn CanOpenDeviceSdoSession::offset(self : CanOpenDeviceSdoSession) -> Int {
  self.offset
}

///|
pub fn CanOpenDeviceSdoSession::remaining(
  self : CanOpenDeviceSdoSession,
) -> Int {
  self.data.length() - self.offset
}

///|
pub fn CanOpenDeviceSdoSession::toggle(self : CanOpenDeviceSdoSession) -> Bool {
  self.toggle
}

///|
pub fn CanOpenDeviceSdoSession::complete(
  self : CanOpenDeviceSdoSession,
) -> Bool {
  self.offset >= self.data.length()
}

///|
pub fn CanOpenDeviceSdoSession::next_segment(
  self : CanOpenDeviceSdoSession,
) -> Array[Byte]? {
  if self.complete() {
    None
  } else {
    let remaining = self.remaining()
    let count = if remaining > self.block_size {
      self.block_size
    } else {
      remaining
    }
    let last = count == remaining
    let command = (if self.toggle { 0x10 } else { 0x00 }) |
      (if last { 1 } else { 0 })
    let result = [(command | ((7 - count) << 1)).to_byte()] +
      self.data[self.offset:self.offset + count].to_owned()
    self.offset += count
    self.toggle = !self.toggle
    Some(result)
  }
}

///|
/// Heartbeat state of a monitored CANopen node.
pub enum CanOpenHeartbeatState {
  CanOpenHeartbeatUnknown
  CanOpenHeartbeatAlive
  CanOpenHeartbeatTimeout
  CanOpenHeartbeatStopped
}

///|
pub fn canopen_heartbeat_state_variants() -> Array[CanOpenHeartbeatState] {
  [
    CanOpenHeartbeatUnknown,
    CanOpenHeartbeatAlive,
    CanOpenHeartbeatTimeout,
    CanOpenHeartbeatStopped,
  ]
}

///|
fn canopen_heartbeat_state_same(
  left : CanOpenHeartbeatState,
  right : CanOpenHeartbeatState,
) -> Bool {
  match left {
    CanOpenHeartbeatUnknown =>
      match right {
        CanOpenHeartbeatUnknown => true
        _ => false
      }
    CanOpenHeartbeatAlive =>
      match right {
        CanOpenHeartbeatAlive => true
        _ => false
      }
    CanOpenHeartbeatTimeout =>
      match right {
        CanOpenHeartbeatTimeout => true
        _ => false
      }
    CanOpenHeartbeatStopped =>
      match right {
        CanOpenHeartbeatStopped => true
        _ => false
      }
  }
}

///|
pub struct CanOpenHeartbeatMonitor {
  node_id : Byte
  timeout_us : UInt64
  mut state : CanOpenHeartbeatState
  mut last_seen_us : UInt64
  mut heartbeats : Int
  mut transitions : Int
}

///|
pub fn canopen_heartbeat_monitor(
  node_id : Byte,
  timeout_us : UInt64,
) -> CanOpenHeartbeatMonitor {
  {
    node_id,
    timeout_us,
    state: CanOpenHeartbeatUnknown,
    last_seen_us: 0,
    heartbeats: 0,
    transitions: 0,
  }
}

///|
pub fn CanOpenHeartbeatMonitor::node_id(self : CanOpenHeartbeatMonitor) -> Byte {
  self.node_id
}

///|
pub fn CanOpenHeartbeatMonitor::timeout_us(
  self : CanOpenHeartbeatMonitor,
) -> UInt64 {
  self.timeout_us
}

///|
pub fn CanOpenHeartbeatMonitor::state(
  self : CanOpenHeartbeatMonitor,
) -> CanOpenHeartbeatState {
  self.state
}

///|
pub fn CanOpenHeartbeatMonitor::last_seen_us(
  self : CanOpenHeartbeatMonitor,
) -> UInt64 {
  self.last_seen_us
}

///|
pub fn CanOpenHeartbeatMonitor::heartbeats(
  self : CanOpenHeartbeatMonitor,
) -> Int {
  self.heartbeats
}

///|
pub fn CanOpenHeartbeatMonitor::transitions(
  self : CanOpenHeartbeatMonitor,
) -> Int {
  self.transitions
}

///|
pub fn CanOpenHeartbeatMonitor::observe(
  self : CanOpenHeartbeatMonitor,
  state_byte : Byte,
  timestamp_us : UInt64,
) -> Unit {
  let next = if state_byte == 0x04 {
    CanOpenHeartbeatStopped
  } else {
    CanOpenHeartbeatAlive
  }
  if !canopen_heartbeat_state_same(self.state, next) {
    self.transitions += 1
  }
  self.state = next
  self.last_seen_us = timestamp_us
  self.heartbeats += 1
}

///|
pub fn CanOpenHeartbeatMonitor::poll(
  self : CanOpenHeartbeatMonitor,
  timestamp_us : UInt64,
) -> CanOpenHeartbeatState {
  if self.heartbeats > 0 && timestamp_us > self.last_seen_us + self.timeout_us {
    if !(self.state is CanOpenHeartbeatTimeout) {
      self.transitions += 1
    }
    self.state = CanOpenHeartbeatTimeout
  }
  self.state
}

///|
/// A CANopen device model with NMT, SDO and heartbeat support.
pub struct CanOpenDevice {
  node_id : Byte
  name : String
  mut state : CanOpenDeviceState
  dictionary : CanOpenObjectDictionary
  heartbeat : CanOpenHeartbeatMonitor
  mut nmt_commands : Int
  mut sdo_uploads : Int
  mut sdo_downloads : Int
}

///|
pub fn new_canopen_device(
  node_id : Byte,
  name : String,
  heartbeat_timeout_us? : UInt64 = 1_000_000,
) -> CanOpenDevice {
  {
    node_id,
    name,
    state: CanOpenDeviceInitializing,
    dictionary: new_canopen_object_dictionary(),
    heartbeat: canopen_heartbeat_monitor(node_id, heartbeat_timeout_us),
    nmt_commands: 0,
    sdo_uploads: 0,
    sdo_downloads: 0,
  }
}

///|
pub fn CanOpenDevice::node_id(self : CanOpenDevice) -> Byte {
  self.node_id
}

///|
pub fn CanOpenDevice::name(self : CanOpenDevice) -> String {
  self.name
}

///|
pub fn CanOpenDevice::state(self : CanOpenDevice) -> CanOpenDeviceState {
  self.state
}

///|
pub fn CanOpenDevice::dictionary(
  self : CanOpenDevice,
) -> CanOpenObjectDictionary {
  self.dictionary
}

///|
pub fn CanOpenDevice::heartbeat(
  self : CanOpenDevice,
) -> CanOpenHeartbeatMonitor {
  self.heartbeat
}

///|
pub fn CanOpenDevice::nmt_commands(self : CanOpenDevice) -> Int {
  self.nmt_commands
}

///|
pub fn CanOpenDevice::sdo_uploads(self : CanOpenDevice) -> Int {
  self.sdo_uploads
}

///|
pub fn CanOpenDevice::sdo_downloads(self : CanOpenDevice) -> Int {
  self.sdo_downloads
}

///|
pub fn CanOpenDevice::add_object(
  self : CanOpenDevice,
  entry : CanOpenObjectEntry,
) -> Bool {
  self.dictionary.add(entry)
}

///|
pub fn CanOpenDevice::nmt(
  self : CanOpenDevice,
  command : CanOpenNmtCommand,
) -> CanOpenDeviceState {
  self.nmt_commands += 1
  self.state = match command {
    Start => CanOpenDeviceOperational
    Stop => CanOpenDeviceStopped
    EnterPreOperational => CanOpenDevicePreOperational
    ResetNode | ResetCommunication => CanOpenDeviceResetting
  }
  self.state
}

///|
pub fn CanOpenDevice::heartbeat_tick(
  self : CanOpenDevice,
  timestamp_us : UInt64,
) -> CanOpenHeartbeatState {
  self.heartbeat.poll(timestamp_us)
}

///|
pub fn CanOpenDevice::heartbeat_receive(
  self : CanOpenDevice,
  state_byte : Byte,
  timestamp_us : UInt64,
) -> Unit {
  self.heartbeat.observe(state_byte, timestamp_us)
}

///|
pub fn CanOpenDevice::sdo_upload(
  self : CanOpenDevice,
  index : UInt,
  sub_index : Byte,
) -> CanOpenDeviceSdoResult {
  match self.dictionary.read(index, sub_index) {
    Some(data) => {
      self.sdo_uploads += 1
      CanOpenDeviceSdoUploaded(data)
    }
    None => CanOpenDeviceSdoAbort(0x06020000)
  }
}

///|
pub fn CanOpenDevice::sdo_download(
  self : CanOpenDevice,
  index : UInt,
  sub_index : Byte,
  data : Array[Byte],
) -> CanOpenDeviceSdoResult {
  if self.dictionary.write(index, sub_index, data) {
    self.sdo_downloads += 1
    CanOpenDeviceSdoDownloaded
  } else {
    CanOpenDeviceSdoAbort(0x06010002)
  }
}

///|
pub fn CanOpenDevice::to_text(self : CanOpenDevice) -> String {
  self.name +
  " node=" +
  self.node_id.to_string() +
  " objects=" +
  self.dictionary.length().to_string() +
  " state=" +
  canopen_device_state_text(self.state)
}

///|
pub fn canopen_device_state_text(state : CanOpenDeviceState) -> String {
  match state {
    CanOpenDeviceInitializing => "initializing"
    CanOpenDevicePreOperational => "pre-operational"
    CanOpenDeviceOperational => "operational"
    CanOpenDeviceStopped => "stopped"
    CanOpenDeviceResetting => "resetting"
  }
}

///|
/// A deterministic collection of CANopen devices.
pub struct CanOpenDeviceNetwork {
  devices : Array[CanOpenDevice]
  mut commands : Int
  mut unknown_nodes : Int
}

///|
pub fn new_canopen_device_network() -> CanOpenDeviceNetwork {
  { devices: [], commands: 0, unknown_nodes: 0 }
}

///|
pub fn CanOpenDeviceNetwork::add(
  self : CanOpenDeviceNetwork,
  device : CanOpenDevice,
) -> Bool {
  if self.find(device.node_id()) is Some(_) {
    false
  } else {
    self.devices.push(device)
    true
  }
}

///|
pub fn CanOpenDeviceNetwork::find(
  self : CanOpenDeviceNetwork,
  node_id : Byte,
) -> CanOpenDevice? {
  for device in self.devices {
    if device.node_id() == node_id {
      return Some(device)
    }
  }
  None
}

///|
pub fn CanOpenDeviceNetwork::broadcast_nmt(
  self : CanOpenDeviceNetwork,
  command : CanOpenNmtCommand,
) -> Int {
  let mut changed = 0
  for device in self.devices {
    ignore(device.nmt(command))
    changed += 1
  }
  self.commands += changed
  changed
}

///|
pub fn CanOpenDeviceNetwork::sdo_upload(
  self : CanOpenDeviceNetwork,
  node_id : Byte,
  index : UInt,
  sub_index : Byte,
) -> CanOpenDeviceSdoResult {
  match self.find(node_id) {
    Some(device) => device.sdo_upload(index, sub_index)
    None => {
      self.unknown_nodes += 1
      CanOpenDeviceSdoAbort(0x060A0023)
    }
  }
}

///|
pub fn CanOpenDeviceNetwork::devices(
  self : CanOpenDeviceNetwork,
) -> Array[CanOpenDevice] {
  self.devices.copy()
}

///|
pub fn CanOpenDeviceNetwork::commands(self : CanOpenDeviceNetwork) -> Int {
  self.commands
}

///|
pub fn CanOpenDeviceNetwork::unknown_nodes(self : CanOpenDeviceNetwork) -> Int {
  self.unknown_nodes
}
