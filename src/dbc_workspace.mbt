///|
/// Selection rule for a multiplexed DBC message.
pub enum DbcWorkspaceMuxSelector {
  DbcWorkspaceMuxNone
  DbcWorkspaceMuxValue(UInt)
  DbcWorkspaceMuxRange(UInt, UInt)
}

///|
pub fn dbc_workspace_mux_variants() -> Array[DbcWorkspaceMuxSelector] {
  [DbcWorkspaceMuxNone, DbcWorkspaceMuxValue(0), DbcWorkspaceMuxRange(0, 1)]
}

///|
/// A named group of DBC signals used by a calibration tool.
pub struct DbcWorkspaceSignalGroup {
  name : String
  message_id : UInt
  signals : Array[Signal]
  mut active : Bool
}

///|
pub fn dbc_workspace_signal_group(
  name : String,
  message_id : UInt,
  signals? : Array[Signal] = [],
) -> DbcWorkspaceSignalGroup {
  { name, message_id, signals: signals.copy(), active: true }
}

///|
pub fn DbcWorkspaceSignalGroup::name(self : DbcWorkspaceSignalGroup) -> String {
  self.name
}

///|
pub fn DbcWorkspaceSignalGroup::message_id(
  self : DbcWorkspaceSignalGroup,
) -> UInt {
  self.message_id
}

///|
pub fn DbcWorkspaceSignalGroup::signals(
  self : DbcWorkspaceSignalGroup,
) -> Array[Signal] {
  self.signals.copy()
}

///|
pub fn DbcWorkspaceSignalGroup::active(self : DbcWorkspaceSignalGroup) -> Bool {
  self.active
}

///|
pub fn DbcWorkspaceSignalGroup::set_active(
  self : DbcWorkspaceSignalGroup,
  active : Bool,
) -> Unit {
  self.active = active
}

///|
pub fn DbcWorkspaceSignalGroup::add_signal(
  self : DbcWorkspaceSignalGroup,
  item : Signal,
) -> Bool {
  if self.find(item.name()) is Some(_) {
    false
  } else {
    self.signals.push(item)
    true
  }
}

///|
pub fn DbcWorkspaceSignalGroup::find(
  self : DbcWorkspaceSignalGroup,
  name : String,
) -> Signal? {
  for item in self.signals {
    if item.name() == name {
      return Some(item)
    }
  }
  None
}

///|
pub fn DbcWorkspaceSignalGroup::contains(
  self : DbcWorkspaceSignalGroup,
  name : String,
) -> Bool {
  self.find(name) is Some(_)
}

///|
pub fn DbcWorkspaceSignalGroup::length(self : DbcWorkspaceSignalGroup) -> Int {
  self.signals.length()
}

///|
/// A physical value associated with a named DBC signal.
pub struct DbcWorkspaceValue {
  name : String
  value : Double
}

///|
pub fn dbc_workspace_value(name : String, value : Double) -> DbcWorkspaceValue {
  { name, value }
}

///|
pub fn DbcWorkspaceValue::name(self : DbcWorkspaceValue) -> String {
  self.name
}

///|
pub fn DbcWorkspaceValue::value(self : DbcWorkspaceValue) -> Double {
  self.value
}

///|
/// A deterministic value set that can be converted to a DBC map.
pub struct DbcWorkspaceValueSet {
  values : Array[DbcWorkspaceValue]
  mut revision : UInt
}

///|
pub fn new_dbc_workspace_value_set() -> DbcWorkspaceValueSet {
  { values: [], revision: 0 }
}

///|
pub fn DbcWorkspaceValueSet::put(
  self : DbcWorkspaceValueSet,
  value : DbcWorkspaceValue,
) -> Unit {
  match self.find_index(value.name()) {
    Some(index) => self.values[index] = value
    None => self.values.push(value)
  }
  self.revision += 1
}

///|
pub fn DbcWorkspaceValueSet::put_number(
  self : DbcWorkspaceValueSet,
  name : String,
  value : Double,
) -> Unit {
  self.put(dbc_workspace_value(name, value))
}

///|
pub fn DbcWorkspaceValueSet::find(
  self : DbcWorkspaceValueSet,
  name : String,
) -> DbcWorkspaceValue? {
  match self.find_index(name) {
    Some(index) => Some(self.values[index])
    None => None
  }
}

///|
pub fn DbcWorkspaceValueSet::contains(
  self : DbcWorkspaceValueSet,
  name : String,
) -> Bool {
  self.find(name) is Some(_)
}

///|
pub fn DbcWorkspaceValueSet::remove(
  self : DbcWorkspaceValueSet,
  name : String,
) -> Bool {
  match self.find_index(name) {
    Some(index) => {
      ignore(self.values.remove(index))
      self.revision += 1
      true
    }
    None => false
  }
}

///|
pub fn DbcWorkspaceValueSet::values(
  self : DbcWorkspaceValueSet,
) -> Array[DbcWorkspaceValue] {
  self.values.copy()
}

///|
pub fn DbcWorkspaceValueSet::names(
  self : DbcWorkspaceValueSet,
) -> Array[String] {
  self.values.map(item => item.name())
}

///|
pub fn DbcWorkspaceValueSet::revision(self : DbcWorkspaceValueSet) -> UInt {
  self.revision
}

///|
pub fn DbcWorkspaceValueSet::to_map(
  self : DbcWorkspaceValueSet,
) -> Map[String, Double] {
  let result : Map[String, Double] = Map([])
  for item in self.values {
    result[item.name()] = item.value()
  }
  result
}

///|
fn DbcWorkspaceValueSet::find_index(
  self : DbcWorkspaceValueSet,
  name : String,
) -> Int? {
  for index, item in self.values {
    if item.name() == name {
      return Some(index)
    }
  }
  None
}

///|
/// A message binding with a stable runtime name and mux selector.
pub struct DbcWorkspaceBinding {
  name : String
  message : Message
  selector : DbcWorkspaceMuxSelector
  extended : Bool
  mut default_values : DbcWorkspaceValueSet
  mut encoded : Int
  mut decoded : Int
}

///|
pub fn dbc_workspace_binding(
  name : String,
  message : Message,
  selector? : DbcWorkspaceMuxSelector = DbcWorkspaceMuxNone,
  extended? : Bool = false,
) -> DbcWorkspaceBinding {
  {
    name,
    message,
    selector,
    extended,
    default_values: new_dbc_workspace_value_set(),
    encoded: 0,
    decoded: 0,
  }
}

///|
pub fn DbcWorkspaceBinding::name(self : DbcWorkspaceBinding) -> String {
  self.name
}

///|
pub fn DbcWorkspaceBinding::message(self : DbcWorkspaceBinding) -> Message {
  self.message
}

///|
pub fn DbcWorkspaceBinding::selector(
  self : DbcWorkspaceBinding,
) -> DbcWorkspaceMuxSelector {
  self.selector
}

///|
pub fn DbcWorkspaceBinding::extended(self : DbcWorkspaceBinding) -> Bool {
  self.extended
}

///|
pub fn DbcWorkspaceBinding::set_default(
  self : DbcWorkspaceBinding,
  values : DbcWorkspaceValueSet,
) -> Unit {
  self.default_values = values
}

///|
pub fn DbcWorkspaceBinding::defaults(
  self : DbcWorkspaceBinding,
) -> DbcWorkspaceValueSet {
  self.default_values
}

///|
pub fn DbcWorkspaceBinding::encoded(self : DbcWorkspaceBinding) -> Int {
  self.encoded
}

///|
pub fn DbcWorkspaceBinding::decoded(self : DbcWorkspaceBinding) -> Int {
  self.decoded
}

///|
pub fn DbcWorkspaceBinding::matches_mux(
  self : DbcWorkspaceBinding,
  mux : UInt,
) -> Bool {
  match self.selector {
    DbcWorkspaceMuxNone => true
    DbcWorkspaceMuxValue(value) => mux == value
    DbcWorkspaceMuxRange(start, end) => mux >= start && mux <= end
  }
}

///|
pub fn DbcWorkspaceBinding::encode(
  self : DbcWorkspaceBinding,
  values : DbcWorkspaceValueSet,
) -> Frame raise DbcRuntimeError {
  let data = self.message.encode_values(values.to_map(), initial=[])
  self.encoded += 1
  if self.message.dlc() > 8 {
    fd_frame(self.message.id(), data, extended=self.extended) catch {
      _ => raise DbcRuntimeError::PayloadTooLong
    }
  } else {
    data_frame(self.message.id(), data, extended=self.extended) catch {
      _ => raise DbcRuntimeError::PayloadTooLong
    }
  }
}

///|
pub fn DbcWorkspaceBinding::decode(
  self : DbcWorkspaceBinding,
  frame : Frame,
) -> DecodedMessage raise DbcRuntimeError {
  self.decoded += 1
  self.message.decode(frame.data())
}

///|
/// A schema finding returned by workspace validation.
pub enum DbcWorkspaceIssue {
  DbcWorkspaceDuplicateId(UInt)
  DbcWorkspaceDuplicateName(String)
  DbcWorkspaceInvalidMessage(String)
  DbcWorkspaceMissingBinding(UInt)
  DbcWorkspaceEmptyGroup(String)
  DbcWorkspaceMuxConflict(String)
}

///|
pub fn dbc_workspace_issue_variants() -> Array[DbcWorkspaceIssue] {
  [
    DbcWorkspaceDuplicateId(0),
    DbcWorkspaceDuplicateName("example"),
    DbcWorkspaceInvalidMessage("example"),
    DbcWorkspaceMissingBinding(0),
    DbcWorkspaceEmptyGroup("example"),
    DbcWorkspaceMuxConflict("example"),
  ]
}

///|
/// A runtime registry for DBC schemas, groups and bindings.
pub struct DbcWorkspace {
  messages : Array[Message]
  groups : Array[DbcWorkspaceSignalGroup]
  bindings : Array[DbcWorkspaceBinding]
  mut revision : UInt
  mut encoded_frames : Int
  mut decoded_frames : Int
}

///|
pub fn new_dbc_workspace() -> DbcWorkspace {
  {
    messages: [],
    groups: [],
    bindings: [],
    revision: 0,
    encoded_frames: 0,
    decoded_frames: 0,
  }
}

///|
pub fn DbcWorkspace::add_message(self : DbcWorkspace, item : Message) -> Bool {
  if self.by_id(item.id()) is Some(_) || self.by_name(item.name()) is Some(_) {
    false
  } else {
    self.messages.push(item)
    self.revision += 1
    true
  }
}

///|
pub fn DbcWorkspace::replace_message(
  self : DbcWorkspace,
  item : Message,
) -> Bool {
  match self.find_message_index(item.id()) {
    Some(index) => {
      self.messages[index] = item
      self.revision += 1
      true
    }
    None => false
  }
}

///|
pub fn DbcWorkspace::add_group(
  self : DbcWorkspace,
  group : DbcWorkspaceSignalGroup,
) -> Bool {
  if self.find_group(group.name()) is Some(_) {
    false
  } else if group.length() == 0 {
    false
  } else {
    self.groups.push(group)
    self.revision += 1
    true
  }
}

///|
pub fn DbcWorkspace::add_binding(
  self : DbcWorkspace,
  binding : DbcWorkspaceBinding,
) -> Bool {
  if self.by_id(binding.message().id()) is None ||
    self.find_binding(binding.name()) is Some(_) {
    false
  } else {
    self.bindings.push(binding)
    self.revision += 1
    true
  }
}

///|
pub fn DbcWorkspace::messages(self : DbcWorkspace) -> Array[Message] {
  self.messages.copy()
}

///|
pub fn DbcWorkspace::groups(
  self : DbcWorkspace,
) -> Array[DbcWorkspaceSignalGroup] {
  self.groups.copy()
}

///|
pub fn DbcWorkspace::bindings(
  self : DbcWorkspace,
) -> Array[DbcWorkspaceBinding] {
  self.bindings.copy()
}

///|
pub fn DbcWorkspace::revision(self : DbcWorkspace) -> UInt {
  self.revision
}

///|
pub fn DbcWorkspace::encoded_frames(self : DbcWorkspace) -> Int {
  self.encoded_frames
}

///|
pub fn DbcWorkspace::decoded_frames(self : DbcWorkspace) -> Int {
  self.decoded_frames
}

///|
pub fn DbcWorkspace::by_id(self : DbcWorkspace, id : UInt) -> Message? {
  for item in self.messages {
    if item.id() == id {
      return Some(item)
    }
  }
  None
}

///|
pub fn DbcWorkspace::by_name(self : DbcWorkspace, name : String) -> Message? {
  for item in self.messages {
    if item.name() == name {
      return Some(item)
    }
  }
  None
}

///|
pub fn DbcWorkspace::find_group(
  self : DbcWorkspace,
  name : String,
) -> DbcWorkspaceSignalGroup? {
  for item in self.groups {
    if item.name() == name {
      return Some(item)
    }
  }
  None
}

///|
pub fn DbcWorkspace::find_binding(
  self : DbcWorkspace,
  name : String,
) -> DbcWorkspaceBinding? {
  for item in self.bindings {
    if item.name() == name {
      return Some(item)
    }
  }
  None
}

///|
/// Encode a named binding into a CAN frame.
pub fn DbcWorkspace::encode(
  self : DbcWorkspace,
  name : String,
  values : DbcWorkspaceValueSet,
) -> Frame raise DbcRuntimeError {
  match self.find_binding(name) {
    Some(binding) => {
      let frame = binding.encode(values)
      self.encoded_frames += 1
      frame
    }
    None => raise DbcRuntimeError::MissingSignalValue
  }
}

///|
/// Decode a frame using its message identifier.
pub fn DbcWorkspace::decode(
  self : DbcWorkspace,
  frame : Frame,
) -> DecodedMessage? raise DbcRuntimeError {
  match self.by_id(frame.id()) {
    Some(message) => {
      self.decoded_frames += 1
      Some(message.decode(frame.data()))
    }
    None => None
  }
}

///|
/// Return all message identifiers sorted for deterministic reports.
pub fn DbcWorkspace::ids(self : DbcWorkspace) -> Array[UInt] {
  let result = self.messages.map(item => item.id())
  result.sort()
  result
}

///|
/// Validate messages, groups, bindings and duplicate identifiers.
pub fn DbcWorkspace::validate(self : DbcWorkspace) -> Array[DbcWorkspaceIssue] {
  let issues : Array[DbcWorkspaceIssue] = []
  for index, left in self.messages {
    if !left.validate() {
      issues.push(DbcWorkspaceInvalidMessage(left.name()))
    }
    for right in self.messages[index + 1:] {
      if left.id() == right.id() {
        issues.push(DbcWorkspaceDuplicateId(left.id()))
      }
      if left.name() == right.name() {
        issues.push(DbcWorkspaceDuplicateName(left.name()))
      }
    }
  }
  for group in self.groups {
    if group.length() == 0 {
      issues.push(DbcWorkspaceEmptyGroup(group.name()))
    } else if self.by_id(group.message_id()) is None {
      issues.push(DbcWorkspaceMissingBinding(group.message_id()))
    }
  }
  for binding in self.bindings {
    if self.by_id(binding.message().id()) is None {
      issues.push(DbcWorkspaceMissingBinding(binding.message().id()))
    }
  }
  issues
}

///|
pub fn dbc_workspace_issue_text(issue : DbcWorkspaceIssue) -> String {
  match issue {
    DbcWorkspaceDuplicateId(id) => "duplicate id " + id.to_string()
    DbcWorkspaceDuplicateName(name) => "duplicate name " + name
    DbcWorkspaceInvalidMessage(name) => "invalid message " + name
    DbcWorkspaceMissingBinding(id) => "missing message " + id.to_string()
    DbcWorkspaceEmptyGroup(name) => "empty group " + name
    DbcWorkspaceMuxConflict(name) => "mux conflict " + name
  }
}

///|
/// Return a stable, human-readable workspace schema summary.
pub fn DbcWorkspace::schema_text(self : DbcWorkspace) -> String {
  let lines : Array[String] = []
  for item in self.messages {
    lines.push(
      "BO_ " +
      item.id().to_string() +
      " " +
      item.name() +
      " " +
      item.dlc().to_string() +
      " " +
      item.signal_count().to_string(),
    )
    for signal in item.signals() {
      lines.push(
        "  SG_ " +
        signal.name() +
        " " +
        signal.start_bit().to_string() +
        " " +
        signal.size().to_string(),
      )
    }
  }
  lines.join("\n")
}

///|
/// Return a compact fingerprint for cache keys and CI artifacts.
pub fn DbcWorkspace::fingerprint(self : DbcWorkspace) -> UInt {
  let mut hash : UInt = 2166136261
  for byte in self.schema_text() {
    hash = (hash ^ byte.to_uint()) * 16777619
  }
  hash
}

///|
/// Create a workspace from a parsed DBC document.
pub fn dbc_workspace_from_text(input : String) -> DbcWorkspace raise DbcError {
  let workspace = new_dbc_workspace()
  for item in parse_dbc(input) {
    ignore(workspace.add_message(item))
  }
  workspace
}

///|
/// Build a value set from parallel signal names and values.
pub fn dbc_workspace_values(
  names : Array[String],
  values : Array[Double],
) -> DbcWorkspaceValueSet {
  let result = new_dbc_workspace_value_set()
  let count = if names.length() < values.length() {
    names.length()
  } else {
    values.length()
  }
  for index in 0..<count {
    result.put_number(names[index], values[index])
  }
  result
}

///|
/// Return whether a mux selector accepts a value.
pub fn dbc_workspace_mux_accepts(
  selector : DbcWorkspaceMuxSelector,
  value : UInt,
) -> Bool {
  match selector {
    DbcWorkspaceMuxNone => true
    DbcWorkspaceMuxValue(expected) => value == expected
    DbcWorkspaceMuxRange(start, end) => value >= start && value <= end
  }
}

///|
fn DbcWorkspace::find_message_index(self : DbcWorkspace, id : UInt) -> Int? {
  for index, item in self.messages {
    if item.id() == id {
      return Some(index)
    }
  }
  None
}
