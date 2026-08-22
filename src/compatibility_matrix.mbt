///|
/// Protocol families that can be checked by a deployment compatibility matrix.
pub(all) enum CompatibilityProtocol {
  CompatibilityClassicCan
  CompatibilityCanFd
  CompatibilityIsoTp
  CompatibilityUds
  CompatibilityCanOpen
  CompatibilityJ1939
  CompatibilityGateway
  CompatibilityCustom
}

///|
pub fn compatibility_protocol_variants() -> Array[CompatibilityProtocol] {
  [
    CompatibilityClassicCan,
    CompatibilityCanFd,
    CompatibilityIsoTp,
    CompatibilityUds,
    CompatibilityCanOpen,
    CompatibilityJ1939,
    CompatibilityGateway,
    CompatibilityCustom,
  ]
}

///|
pub fn compatibility_protocol_text(protocol : CompatibilityProtocol) -> String {
  match protocol {
    CompatibilityClassicCan => "classic-can"
    CompatibilityCanFd => "can-fd"
    CompatibilityIsoTp => "isotp"
    CompatibilityUds => "uds"
    CompatibilityCanOpen => "canopen"
    CompatibilityJ1939 => "j1939"
    CompatibilityGateway => "gateway"
    CompatibilityCustom => "custom"
  }
}

///|
/// The level attached to a requirement or finding.
pub(all) enum CompatibilitySeverity {
  CompatibilityInfo
  CompatibilityWarning
  CompatibilityError
}

///|
pub fn compatibility_severity_variants() -> Array[CompatibilitySeverity] {
  [CompatibilityInfo, CompatibilityWarning, CompatibilityError]
}

///|
pub fn compatibility_severity_text(severity : CompatibilitySeverity) -> String {
  match severity {
    CompatibilityInfo => "info"
    CompatibilityWarning => "warning"
    CompatibilityError => "error"
  }
}

///|
/// A machine-readable kind of capability requirement.
pub(all) enum CompatibilityRequirementKind {
  CompatibilityMinimumBitrate
  CompatibilityMinimumDataBitrate
  CompatibilityMinimumPayload
  CompatibilityMinimumIdentifierBits
  CompatibilityMinimumNodeCapacity
  CompatibilityProtocolIs
  CompatibilityRequiresFeature
  CompatibilityForbidsFeature
  CompatibilityRequiresFd
  CompatibilityRequiresClassic
  CompatibilityRequiresIsoTp
  CompatibilityRequiresDiagnostics
}

///|
pub fn compatibility_requirement_kind_variants() -> Array[
  CompatibilityRequirementKind,
] {
  [
    CompatibilityMinimumBitrate,
    CompatibilityMinimumDataBitrate,
    CompatibilityMinimumPayload,
    CompatibilityMinimumIdentifierBits,
    CompatibilityMinimumNodeCapacity,
    CompatibilityProtocolIs,
    CompatibilityRequiresFeature,
    CompatibilityForbidsFeature,
    CompatibilityRequiresFd,
    CompatibilityRequiresClassic,
    CompatibilityRequiresIsoTp,
    CompatibilityRequiresDiagnostics,
  ]
}

///|
pub fn compatibility_requirement_kind_text(
  kind : CompatibilityRequirementKind,
) -> String {
  match kind {
    CompatibilityMinimumBitrate => "minimum-bitrate"
    CompatibilityMinimumDataBitrate => "minimum-data-bitrate"
    CompatibilityMinimumPayload => "minimum-payload"
    CompatibilityMinimumIdentifierBits => "minimum-identifier-bits"
    CompatibilityMinimumNodeCapacity => "minimum-node-capacity"
    CompatibilityProtocolIs => "protocol-is"
    CompatibilityRequiresFeature => "requires-feature"
    CompatibilityForbidsFeature => "forbids-feature"
    CompatibilityRequiresFd => "requires-fd"
    CompatibilityRequiresClassic => "requires-classic"
    CompatibilityRequiresIsoTp => "requires-isotp"
    CompatibilityRequiresDiagnostics => "requires-diagnostics"
  }
}

///|
/// A deployment target and the capabilities it advertises.
pub struct CompatibilityTarget {
  name : String
  protocol : CompatibilityProtocol
  nominal_bitrate : Int
  data_bitrate : Int
  max_payload : Int
  identifier_bits : Int
  node_capacity : Int
  features : Array[String]
  notes : String
}

///|
pub fn compatibility_target(
  name : String,
  protocol : CompatibilityProtocol,
  nominal_bitrate : Int,
  data_bitrate : Int,
  max_payload : Int,
  identifier_bits : Int,
  node_capacity : Int,
  features? : Array[String] = [],
  notes? : String = "",
) -> CompatibilityTarget {
  {
    name,
    protocol,
    nominal_bitrate: if nominal_bitrate < 0 {
      0
    } else {
      nominal_bitrate
    },
    data_bitrate: if data_bitrate < 0 {
      0
    } else {
      data_bitrate
    },
    max_payload: if max_payload < 0 {
      0
    } else {
      max_payload
    },
    identifier_bits: if identifier_bits < 0 {
      0
    } else {
      identifier_bits
    },
    node_capacity: if node_capacity < 0 {
      0
    } else {
      node_capacity
    },
    features: features.copy(),
    notes,
  }
}

///|
pub fn CompatibilityTarget::name(self : CompatibilityTarget) -> String {
  self.name
}

///|
pub fn CompatibilityTarget::protocol(
  self : CompatibilityTarget,
) -> CompatibilityProtocol {
  self.protocol
}

///|
pub fn CompatibilityTarget::nominal_bitrate(self : CompatibilityTarget) -> Int {
  self.nominal_bitrate
}

///|
pub fn CompatibilityTarget::data_bitrate(self : CompatibilityTarget) -> Int {
  self.data_bitrate
}

///|
pub fn CompatibilityTarget::max_payload(self : CompatibilityTarget) -> Int {
  self.max_payload
}

///|
pub fn CompatibilityTarget::identifier_bits(self : CompatibilityTarget) -> Int {
  self.identifier_bits
}

///|
pub fn CompatibilityTarget::node_capacity(self : CompatibilityTarget) -> Int {
  self.node_capacity
}

///|
pub fn CompatibilityTarget::features(
  self : CompatibilityTarget,
) -> Array[String] {
  self.features.copy()
}

///|
pub fn CompatibilityTarget::notes(self : CompatibilityTarget) -> String {
  self.notes
}

///|
pub fn CompatibilityTarget::has_feature(
  self : CompatibilityTarget,
  wanted : String,
) -> Bool {
  for feature in self.features {
    if feature == wanted {
      return true
    }
  }
  false
}

///|
pub fn CompatibilityTarget::feature_count(self : CompatibilityTarget) -> Int {
  self.features.length()
}

///|
pub fn CompatibilityTarget::feature_csv(self : CompatibilityTarget) -> String {
  let builder = StringBuilder()
  for index, feature in self.features {
    if index > 0 {
      builder.write_string(",")
    }
    builder.write_string(feature)
  }
  builder.to_string()
}

///|
pub fn CompatibilityTarget::summary(self : CompatibilityTarget) -> String {
  let builder = StringBuilder()
  builder.write_string(self.name)
  builder.write_string(" protocol=")
  builder.write_string(compatibility_protocol_text(self.protocol))
  builder.write_string(" nominal=")
  builder.write_string(self.nominal_bitrate.to_string())
  builder.write_string(" data=")
  builder.write_string(self.data_bitrate.to_string())
  builder.write_string(" payload=")
  builder.write_string(self.max_payload.to_string())
  builder.write_string(" idbits=")
  builder.write_string(self.identifier_bits.to_string())
  builder.write_string(" nodes=")
  builder.write_string(self.node_capacity.to_string())
  builder.to_string()
}

///|
/// A reusable requirement for a production target.
pub struct CompatibilityRequirement {
  code : String
  description : String
  kind : CompatibilityRequirementKind
  mut numeric_value : Int
  mut protocol_value : CompatibilityProtocol?
  mut feature_value : String?
  severity : CompatibilitySeverity
}

///|
fn compatibility_requirement_base(
  code : String,
  description : String,
  kind : CompatibilityRequirementKind,
  severity : CompatibilitySeverity,
) -> CompatibilityRequirement {
  {
    code,
    description,
    kind,
    numeric_value: 0,
    protocol_value: None,
    feature_value: None,
    severity,
  }
}

///|
pub fn compatibility_minimum_bitrate(
  code : String,
  minimum : Int,
  description? : String = "nominal bitrate requirement",
  severity? : CompatibilitySeverity = CompatibilityError,
) -> CompatibilityRequirement {
  let item = compatibility_requirement_base(
    code,
    description,
    CompatibilityMinimumBitrate,
    severity,
  )
  item.numeric_value = if minimum < 0 { 0 } else { minimum }
  item
}

///|
pub fn compatibility_minimum_data_bitrate(
  code : String,
  minimum : Int,
  description? : String = "data phase bitrate requirement",
  severity? : CompatibilitySeverity = CompatibilityError,
) -> CompatibilityRequirement {
  let item = compatibility_requirement_base(
    code,
    description,
    CompatibilityMinimumDataBitrate,
    severity,
  )
  item.numeric_value = if minimum < 0 { 0 } else { minimum }
  item
}

///|
pub fn compatibility_minimum_payload(
  code : String,
  minimum : Int,
  description? : String = "payload capacity requirement",
  severity? : CompatibilitySeverity = CompatibilityError,
) -> CompatibilityRequirement {
  let item = compatibility_requirement_base(
    code,
    description,
    CompatibilityMinimumPayload,
    severity,
  )
  item.numeric_value = if minimum < 0 { 0 } else { minimum }
  item
}

///|
pub fn compatibility_minimum_identifier_bits(
  code : String,
  minimum : Int,
  description? : String = "identifier width requirement",
  severity? : CompatibilitySeverity = CompatibilityError,
) -> CompatibilityRequirement {
  let item = compatibility_requirement_base(
    code,
    description,
    CompatibilityMinimumIdentifierBits,
    severity,
  )
  item.numeric_value = if minimum < 0 { 0 } else { minimum }
  item
}

///|
pub fn compatibility_minimum_node_capacity(
  code : String,
  minimum : Int,
  description? : String = "node capacity requirement",
  severity? : CompatibilitySeverity = CompatibilityError,
) -> CompatibilityRequirement {
  let item = compatibility_requirement_base(
    code,
    description,
    CompatibilityMinimumNodeCapacity,
    severity,
  )
  item.numeric_value = if minimum < 0 { 0 } else { minimum }
  item
}

///|
pub fn compatibility_protocol_is(
  code : String,
  protocol : CompatibilityProtocol,
  description? : String = "protocol family requirement",
  severity? : CompatibilitySeverity = CompatibilityError,
) -> CompatibilityRequirement {
  let item = compatibility_requirement_base(
    code,
    description,
    CompatibilityProtocolIs,
    severity,
  )
  item.protocol_value = Some(protocol)
  item
}

///|
pub fn compatibility_requires_feature(
  code : String,
  feature : String,
  description? : String = "feature is required",
  severity? : CompatibilitySeverity = CompatibilityError,
) -> CompatibilityRequirement {
  let item = compatibility_requirement_base(
    code,
    description,
    CompatibilityRequiresFeature,
    severity,
  )
  item.feature_value = Some(feature)
  item
}

///|
pub fn compatibility_forbids_feature(
  code : String,
  feature : String,
  description? : String = "feature must not be enabled",
  severity? : CompatibilitySeverity = CompatibilityWarning,
) -> CompatibilityRequirement {
  let item = compatibility_requirement_base(
    code,
    description,
    CompatibilityForbidsFeature,
    severity,
  )
  item.feature_value = Some(feature)
  item
}

///|
pub fn compatibility_requires_fd(
  code : String,
  description? : String = "CAN FD is required",
  severity? : CompatibilitySeverity = CompatibilityError,
) -> CompatibilityRequirement {
  compatibility_requirement_base(
    code,
    description,
    CompatibilityRequiresFd,
    severity,
  )
}

///|
pub fn compatibility_requires_classic(
  code : String,
  description? : String = "classic CAN is required",
  severity? : CompatibilitySeverity = CompatibilityError,
) -> CompatibilityRequirement {
  compatibility_requirement_base(
    code,
    description,
    CompatibilityRequiresClassic,
    severity,
  )
}

///|
pub fn compatibility_requires_isotp(
  code : String,
  description? : String = "ISO-TP transport is required",
  severity? : CompatibilitySeverity = CompatibilityError,
) -> CompatibilityRequirement {
  let item = compatibility_requirement_base(
    code,
    description,
    CompatibilityRequiresIsoTp,
    severity,
  )
  item
}

///|
pub fn compatibility_requires_diagnostics(
  code : String,
  description? : String = "diagnostic services are required",
  severity? : CompatibilitySeverity = CompatibilityError,
) -> CompatibilityRequirement {
  let item = compatibility_requirement_base(
    code,
    description,
    CompatibilityRequiresDiagnostics,
    severity,
  )
  item
}

///|
pub fn CompatibilityRequirement::code(
  self : CompatibilityRequirement,
) -> String {
  self.code
}

///|
pub fn CompatibilityRequirement::description(
  self : CompatibilityRequirement,
) -> String {
  self.description
}

///|
pub fn CompatibilityRequirement::kind(
  self : CompatibilityRequirement,
) -> CompatibilityRequirementKind {
  self.kind
}

///|
pub fn CompatibilityRequirement::numeric_value(
  self : CompatibilityRequirement,
) -> Int {
  self.numeric_value
}

///|
pub fn CompatibilityRequirement::protocol_value(
  self : CompatibilityRequirement,
) -> CompatibilityProtocol? {
  self.protocol_value
}

///|
pub fn CompatibilityRequirement::feature_value(
  self : CompatibilityRequirement,
) -> String? {
  self.feature_value
}

///|
pub fn CompatibilityRequirement::severity(
  self : CompatibilityRequirement,
) -> CompatibilitySeverity {
  self.severity
}

///|
/// A single finding produced while checking a target.
pub struct CompatibilityIssue {
  target : String
  code : String
  severity : CompatibilitySeverity
  passed : Bool
  message : String
  observed : String
  expected : String
}

///|
fn compatibility_issue(
  target : String,
  requirement : CompatibilityRequirement,
  passed : Bool,
  message : String,
  observed : String,
  expected : String,
) -> CompatibilityIssue {
  {
    target,
    code: requirement.code,
    severity: requirement.severity,
    passed,
    message,
    observed,
    expected,
  }
}

///|
pub fn CompatibilityIssue::target(self : CompatibilityIssue) -> String {
  self.target
}

///|
pub fn CompatibilityIssue::code(self : CompatibilityIssue) -> String {
  self.code
}

///|
pub fn CompatibilityIssue::severity(
  self : CompatibilityIssue,
) -> CompatibilitySeverity {
  self.severity
}

///|
pub fn CompatibilityIssue::passed(self : CompatibilityIssue) -> Bool {
  self.passed
}

///|
pub fn CompatibilityIssue::message(self : CompatibilityIssue) -> String {
  self.message
}

///|
pub fn CompatibilityIssue::observed(self : CompatibilityIssue) -> String {
  self.observed
}

///|
pub fn CompatibilityIssue::expected(self : CompatibilityIssue) -> String {
  self.expected
}

///|
pub fn CompatibilityIssue::text(self : CompatibilityIssue) -> String {
  let builder = StringBuilder()
  builder.write_string(if self.passed { "PASS" } else { "FAIL" })
  builder.write_string(" ")
  builder.write_string(compatibility_severity_text(self.severity))
  builder.write_string(" ")
  builder.write_string(self.code)
  builder.write_string(" ")
  builder.write_string(self.message)
  builder.write_string(" observed=")
  builder.write_string(self.observed)
  builder.write_string(" expected=")
  builder.write_string(self.expected)
  builder.to_string()
}

///|
/// Aggregated result for one target.
pub struct CompatibilityEvaluation {
  target : CompatibilityTarget
  issues : Array[CompatibilityIssue]
  passed : Int
  warnings : Int
  failures : Int
  score : Int
}

///|
pub fn CompatibilityEvaluation::target(
  self : CompatibilityEvaluation,
) -> CompatibilityTarget {
  self.target
}

///|
pub fn CompatibilityEvaluation::issues(
  self : CompatibilityEvaluation,
) -> Array[CompatibilityIssue] {
  self.issues.copy()
}

///|
pub fn CompatibilityEvaluation::passed(self : CompatibilityEvaluation) -> Int {
  self.passed
}

///|
pub fn CompatibilityEvaluation::warnings(self : CompatibilityEvaluation) -> Int {
  self.warnings
}

///|
pub fn CompatibilityEvaluation::failures(self : CompatibilityEvaluation) -> Int {
  self.failures
}

///|
pub fn CompatibilityEvaluation::score(self : CompatibilityEvaluation) -> Int {
  self.score
}

///|
pub fn CompatibilityEvaluation::is_compatible(
  self : CompatibilityEvaluation,
) -> Bool {
  self.failures == 0
}

///|
pub fn CompatibilityEvaluation::issue_count(
  self : CompatibilityEvaluation,
) -> Int {
  self.issues.length()
}

///|
pub fn CompatibilityEvaluation::summary(
  self : CompatibilityEvaluation,
) -> String {
  let builder = StringBuilder()
  builder.write_string(self.target.name)
  builder.write_string(" compatible=")
  builder.write_string(if self.is_compatible() { "true" } else { "false" })
  builder.write_string(" passed=")
  builder.write_string(self.passed.to_string())
  builder.write_string(" warnings=")
  builder.write_string(self.warnings.to_string())
  builder.write_string(" failures=")
  builder.write_string(self.failures.to_string())
  builder.write_string(" score=")
  builder.write_string(self.score.to_string())
  builder.to_string()
}

///|
pub fn CompatibilityEvaluation::report(
  self : CompatibilityEvaluation,
) -> String {
  let builder = StringBuilder()
  builder.write_string(self.summary())
  builder.write_string("\n")
  for issue in self.issues {
    builder.write_string("- ")
    builder.write_string(issue.text())
    builder.write_string("\n")
  }
  builder.to_string()
}

///|
/// A matrix of target profiles and production requirements.
pub struct CompatibilityMatrix {
  name : String
  strict : Bool
  targets : Array[CompatibilityTarget]
  requirements : Array[CompatibilityRequirement]
}

///|
pub fn compatibility_matrix(
  name? : String = "can deployment matrix",
  strict? : Bool = true,
) -> CompatibilityMatrix {
  { name, strict, targets: [], requirements: [] }
}

///|
pub fn CompatibilityMatrix::name(self : CompatibilityMatrix) -> String {
  self.name
}

///|
pub fn CompatibilityMatrix::strict(self : CompatibilityMatrix) -> Bool {
  self.strict
}

///|
pub fn CompatibilityMatrix::target_count(self : CompatibilityMatrix) -> Int {
  self.targets.length()
}

///|
pub fn CompatibilityMatrix::requirement_count(
  self : CompatibilityMatrix,
) -> Int {
  self.requirements.length()
}

///|
pub fn CompatibilityMatrix::targets(
  self : CompatibilityMatrix,
) -> Array[CompatibilityTarget] {
  self.targets.copy()
}

///|
pub fn CompatibilityMatrix::requirements(
  self : CompatibilityMatrix,
) -> Array[CompatibilityRequirement] {
  self.requirements.copy()
}

///|
pub fn CompatibilityMatrix::add_target(
  self : CompatibilityMatrix,
  target : CompatibilityTarget,
) -> Unit {
  self.targets.push(target)
}

///|
pub fn CompatibilityMatrix::add_requirement(
  self : CompatibilityMatrix,
  requirement : CompatibilityRequirement,
) -> Unit {
  self.requirements.push(requirement)
}

///|
pub fn CompatibilityMatrix::clear_targets(self : CompatibilityMatrix) -> Unit {
  while self.targets.length() > 0 {
    ignore(self.targets.pop())
  }
}

///|
pub fn CompatibilityMatrix::clear_requirements(
  self : CompatibilityMatrix,
) -> Unit {
  while self.requirements.length() > 0 {
    ignore(self.requirements.pop())
  }
}

///|
fn compatibility_same_protocol(
  left : CompatibilityProtocol,
  right : CompatibilityProtocol,
) -> Bool {
  match left {
    CompatibilityClassicCan => right is CompatibilityClassicCan
    CompatibilityCanFd => right is CompatibilityCanFd
    CompatibilityIsoTp => right is CompatibilityIsoTp
    CompatibilityUds => right is CompatibilityUds
    CompatibilityCanOpen => right is CompatibilityCanOpen
    CompatibilityJ1939 => right is CompatibilityJ1939
    CompatibilityGateway => right is CompatibilityGateway
    CompatibilityCustom => right is CompatibilityCustom
  }
}

///|
fn compatibility_protocol_requirement_passes(
  target : CompatibilityTarget,
  requirement : CompatibilityRequirement,
) -> Bool {
  match requirement.protocol_value {
    Some(protocol) => compatibility_same_protocol(target.protocol, protocol)
    None => false
  }
}

///|
fn compatibility_feature_requirement_passes(
  target : CompatibilityTarget,
  requirement : CompatibilityRequirement,
  wanted : Bool,
) -> Bool {
  match requirement.feature_value {
    Some(feature) => target.has_feature(feature) == wanted
    None => false
  }
}

///|
fn compatibility_protocol_has_fd(protocol : CompatibilityProtocol) -> Bool {
  match protocol {
    CompatibilityCanFd => true
    CompatibilityGateway => true
    CompatibilityUds => true
    CompatibilityIsoTp => true
    _ => false
  }
}

///|
fn compatibility_protocol_has_classic(protocol : CompatibilityProtocol) -> Bool {
  match protocol {
    CompatibilityClassicCan => true
    CompatibilityCanFd => true
    CompatibilityCanOpen => true
    CompatibilityJ1939 => true
    CompatibilityGateway => true
    CompatibilityUds => true
    CompatibilityIsoTp => true
    CompatibilityCustom => true
  }
}

///|
fn compatibility_protocol_has_isotp(protocol : CompatibilityProtocol) -> Bool {
  match protocol {
    CompatibilityIsoTp => true
    CompatibilityUds => true
    CompatibilityGateway => true
    _ => false
  }
}

///|
fn compatibility_protocol_has_diagnostics(
  protocol : CompatibilityProtocol,
) -> Bool {
  match protocol {
    CompatibilityUds => true
    CompatibilityIsoTp => true
    CompatibilityGateway => true
    _ => false
  }
}

///|
fn compatibility_requirement_passes(
  target : CompatibilityTarget,
  requirement : CompatibilityRequirement,
) -> Bool {
  match requirement.kind {
    CompatibilityMinimumBitrate =>
      target.nominal_bitrate >= requirement.numeric_value
    CompatibilityMinimumDataBitrate =>
      target.data_bitrate >= requirement.numeric_value
    CompatibilityMinimumPayload =>
      target.max_payload >= requirement.numeric_value
    CompatibilityMinimumIdentifierBits =>
      target.identifier_bits >= requirement.numeric_value
    CompatibilityMinimumNodeCapacity =>
      target.node_capacity >= requirement.numeric_value
    CompatibilityProtocolIs =>
      compatibility_protocol_requirement_passes(target, requirement)
    CompatibilityRequiresFeature =>
      compatibility_feature_requirement_passes(target, requirement, true)
    CompatibilityForbidsFeature =>
      compatibility_feature_requirement_passes(target, requirement, false)
    CompatibilityRequiresFd => compatibility_protocol_has_fd(target.protocol)
    CompatibilityRequiresClassic =>
      compatibility_protocol_has_classic(target.protocol)
    CompatibilityRequiresIsoTp =>
      compatibility_protocol_has_isotp(target.protocol)
    CompatibilityRequiresDiagnostics =>
      compatibility_protocol_has_diagnostics(target.protocol)
  }
}

///|
fn compatibility_observed(
  target : CompatibilityTarget,
  requirement : CompatibilityRequirement,
) -> String {
  match requirement.kind {
    CompatibilityMinimumBitrate => target.nominal_bitrate.to_string()
    CompatibilityMinimumDataBitrate => target.data_bitrate.to_string()
    CompatibilityMinimumPayload => target.max_payload.to_string()
    CompatibilityMinimumIdentifierBits => target.identifier_bits.to_string()
    CompatibilityMinimumNodeCapacity => target.node_capacity.to_string()
    CompatibilityProtocolIs => compatibility_protocol_text(target.protocol)
    CompatibilityRequiresFeature => target.feature_csv()
    CompatibilityForbidsFeature => target.feature_csv()
    CompatibilityRequiresFd => compatibility_protocol_text(target.protocol)
    CompatibilityRequiresClassic => compatibility_protocol_text(target.protocol)
    CompatibilityRequiresIsoTp => compatibility_protocol_text(target.protocol)
    CompatibilityRequiresDiagnostics =>
      compatibility_protocol_text(target.protocol)
  }
}

///|
fn compatibility_expected(requirement : CompatibilityRequirement) -> String {
  match requirement.kind {
    CompatibilityMinimumBitrate => ">= " + requirement.numeric_value.to_string()
    CompatibilityMinimumDataBitrate =>
      ">= " + requirement.numeric_value.to_string()
    CompatibilityMinimumPayload => ">= " + requirement.numeric_value.to_string()
    CompatibilityMinimumIdentifierBits =>
      ">= " + requirement.numeric_value.to_string()
    CompatibilityMinimumNodeCapacity =>
      ">= " + requirement.numeric_value.to_string()
    CompatibilityProtocolIs =>
      match requirement.protocol_value {
        Some(protocol) => compatibility_protocol_text(protocol)
        None => "protocol"
      }
    CompatibilityRequiresFeature =>
      match requirement.feature_value {
        Some(feature) => "contains " + feature
        None => "feature"
      }
    CompatibilityForbidsFeature =>
      match requirement.feature_value {
        Some(feature) => "without " + feature
        None => "feature"
      }
    CompatibilityRequiresFd => "CAN FD family"
    CompatibilityRequiresClassic => "classic CAN family"
    CompatibilityRequiresIsoTp => "ISO-TP family"
    CompatibilityRequiresDiagnostics => "diagnostic family"
  }
}

///|
fn compatibility_message(
  requirement : CompatibilityRequirement,
  passed : Bool,
) -> String {
  if passed {
    requirement.description + " satisfied"
  } else {
    requirement.description + " not satisfied"
  }
}

///|
pub fn CompatibilityMatrix::evaluate(
  self : CompatibilityMatrix,
  target : CompatibilityTarget,
) -> CompatibilityEvaluation {
  let issues : Array[CompatibilityIssue] = []
  let mut passed = 0
  let mut warnings = 0
  let mut failures = 0
  let mut score = 100
  for requirement in self.requirements {
    let requirement_passed = compatibility_requirement_passes(
      target, requirement,
    )
    let issue = compatibility_issue(
      target.name,
      requirement,
      requirement_passed,
      compatibility_message(requirement, requirement_passed),
      compatibility_observed(target, requirement),
      compatibility_expected(requirement),
    )
    issues.push(issue)
    if requirement_passed {
      passed += 1
    } else {
      match requirement.severity {
        CompatibilityInfo => score -= 1
        CompatibilityWarning => {
          warnings += 1
          score -= 5
        }
        CompatibilityError => {
          failures += 1
          score -= if self.strict { 20 } else { 10 }
        }
      }
    }
  }
  {
    target,
    issues,
    passed,
    warnings,
    failures,
    score: if score < 0 {
      0
    } else {
      score
    },
  }
}

///|
pub fn CompatibilityMatrix::evaluate_all(
  self : CompatibilityMatrix,
) -> Array[CompatibilityEvaluation] {
  let results : Array[CompatibilityEvaluation] = []
  for target in self.targets {
    results.push(self.evaluate(target))
  }
  results
}

///|
pub fn CompatibilityMatrix::compatible_targets(
  self : CompatibilityMatrix,
) -> Array[CompatibilityTarget] {
  let result : Array[CompatibilityTarget] = []
  for target in self.targets {
    let evaluation = self.evaluate(target)
    if evaluation.is_compatible() {
      result.push(target)
    }
  }
  result
}

///|
pub fn CompatibilityMatrix::best_target(
  self : CompatibilityMatrix,
) -> CompatibilityTarget? {
  let mut best : CompatibilityTarget? = None
  let mut best_score = -1
  for target in self.targets {
    let score = self.evaluate(target).score
    if score > best_score {
      best_score = score
      best = Some(target)
    }
  }
  best
}

///|
pub fn CompatibilityMatrix::report(self : CompatibilityMatrix) -> String {
  let builder = StringBuilder()
  builder.write_string("# ")
  builder.write_string(self.name)
  builder.write_string("\n")
  builder.write_string("strict=")
  builder.write_string(if self.strict { "true" } else { "false" })
  builder.write_string(" targets=")
  builder.write_string(self.target_count().to_string())
  builder.write_string(" requirements=")
  builder.write_string(self.requirement_count().to_string())
  builder.write_string("\n")
  for evaluation in self.evaluate_all() {
    builder.write_string(evaluation.report())
  }
  builder.to_string()
}

///|
pub fn CompatibilityMatrix::csv(self : CompatibilityMatrix) -> String {
  let builder = StringBuilder()
  builder.write_string("target,compatible,passed,warnings,failures,score\n")
  for evaluation in self.evaluate_all() {
    builder.write_string(evaluation.target.name)
    builder.write_string(",")
    builder.write_string(
      if evaluation.is_compatible() {
        "true"
      } else {
        "false"
      },
    )
    builder.write_string(",")
    builder.write_string(evaluation.passed.to_string())
    builder.write_string(",")
    builder.write_string(evaluation.warnings.to_string())
    builder.write_string(",")
    builder.write_string(evaluation.failures.to_string())
    builder.write_string(",")
    builder.write_string(evaluation.score.to_string())
    builder.write_string("\n")
  }
  builder.to_string()
}

///|
pub fn CompatibilityMatrix::requirement_report(
  self : CompatibilityMatrix,
) -> String {
  let builder = StringBuilder()
  for requirement in self.requirements {
    builder.write_string(requirement.code)
    builder.write_string(" ")
    builder.write_string(compatibility_requirement_kind_text(requirement.kind))
    builder.write_string(" ")
    builder.write_string(requirement.description)
    builder.write_string(" severity=")
    builder.write_string(compatibility_severity_text(requirement.severity))
    builder.write_string("\n")
  }
  builder.to_string()
}

///|
/// A fleet-level summary used by acceptance gates and dashboards.
pub struct CompatibilityFleetSummary {
  target_count : Int
  compatible_count : Int
  warning_count : Int
  failure_count : Int
  average_score : Int
  lowest_score : Int
  highest_score : Int
}

///|
pub fn CompatibilityFleetSummary::target_count(
  self : CompatibilityFleetSummary,
) -> Int {
  self.target_count
}

///|
pub fn CompatibilityFleetSummary::compatible_count(
  self : CompatibilityFleetSummary,
) -> Int {
  self.compatible_count
}

///|
pub fn CompatibilityFleetSummary::warning_count(
  self : CompatibilityFleetSummary,
) -> Int {
  self.warning_count
}

///|
pub fn CompatibilityFleetSummary::failure_count(
  self : CompatibilityFleetSummary,
) -> Int {
  self.failure_count
}

///|
pub fn CompatibilityFleetSummary::average_score(
  self : CompatibilityFleetSummary,
) -> Int {
  self.average_score
}

///|
pub fn CompatibilityFleetSummary::lowest_score(
  self : CompatibilityFleetSummary,
) -> Int {
  self.lowest_score
}

///|
pub fn CompatibilityFleetSummary::highest_score(
  self : CompatibilityFleetSummary,
) -> Int {
  self.highest_score
}

///|
pub fn CompatibilityFleetSummary::is_release_ready(
  self : CompatibilityFleetSummary,
) -> Bool {
  self.target_count > 0 && self.failure_count == 0
}

///|
pub fn CompatibilityFleetSummary::text(
  self : CompatibilityFleetSummary,
) -> String {
  let builder = StringBuilder()
  builder.write_string("targets=")
  builder.write_string(self.target_count.to_string())
  builder.write_string(" compatible=")
  builder.write_string(self.compatible_count.to_string())
  builder.write_string(" warnings=")
  builder.write_string(self.warning_count.to_string())
  builder.write_string(" failures=")
  builder.write_string(self.failure_count.to_string())
  builder.write_string(" average=")
  builder.write_string(self.average_score.to_string())
  builder.write_string(" lowest=")
  builder.write_string(self.lowest_score.to_string())
  builder.write_string(" highest=")
  builder.write_string(self.highest_score.to_string())
  builder.write_string(" ready=")
  builder.write_string(if self.is_release_ready() { "true" } else { "false" })
  builder.to_string()
}

///|
pub fn CompatibilityMatrix::fleet_summary(
  self : CompatibilityMatrix,
) -> CompatibilityFleetSummary {
  let evaluations = self.evaluate_all()
  if evaluations.length() == 0 {
    return {
      target_count: 0,
      compatible_count: 0,
      warning_count: 0,
      failure_count: 0,
      average_score: 0,
      lowest_score: 0,
      highest_score: 0,
    }
  }
  let mut compatible_count = 0
  let mut warning_count = 0
  let mut failure_count = 0
  let mut score_total = 0
  let mut lowest_score = 101
  let mut highest_score = 0
  for evaluation in evaluations {
    if evaluation.is_compatible() {
      compatible_count += 1
    }
    warning_count += evaluation.warnings
    failure_count += evaluation.failures
    score_total += evaluation.score
    if evaluation.score < lowest_score {
      lowest_score = evaluation.score
    }
    if evaluation.score > highest_score {
      highest_score = evaluation.score
    }
  }
  {
    target_count: evaluations.length(),
    compatible_count,
    warning_count,
    failure_count,
    average_score: score_total / evaluations.length(),
    lowest_score,
    highest_score,
  }
}

///|
pub fn compatibility_classic_target(
  name? : String = "classic-can",
  node_capacity? : Int = 32,
) -> CompatibilityTarget {
  compatibility_target(
    name,
    CompatibilityClassicCan,
    500,
    0,
    8,
    11,
    node_capacity,
    features=["classic", "remote-frame", "error-frame"],
    notes="Classical CAN, 11-bit identifiers, 8-byte data fields",
  )
}

///|
pub fn compatibility_fd_target(
  name? : String = "can-fd",
  node_capacity? : Int = 64,
) -> CompatibilityTarget {
  compatibility_target(
    name,
    CompatibilityCanFd,
    500,
    2_000,
    64,
    29,
    node_capacity,
    features=["fd", "bitrate-switch", "extended-id", "crc"],
    notes="CAN FD with separate data phase and extended identifiers",
  )
}

///|
pub fn compatibility_isotp_target(
  name? : String = "isotp",
  node_capacity? : Int = 16,
) -> CompatibilityTarget {
  compatibility_target(
    name,
    CompatibilityIsoTp,
    500,
    0,
    4095,
    11,
    node_capacity,
    features=["classic", "flow-control", "segmentation", "padding"],
    notes="ISO-TP transport over classical CAN",
  )
}

///|
pub fn compatibility_uds_target(
  name? : String = "uds",
  node_capacity? : Int = 16,
) -> CompatibilityTarget {
  compatibility_target(
    name,
    CompatibilityUds,
    500,
    2_000,
    4095,
    29,
    node_capacity,
    features=["fd", "diagnostics", "isotp", "security-access", "dtc"],
    notes="UDS diagnostic endpoint with segmented payload support",
  )
}

///|
pub fn compatibility_canopen_target(
  name? : String = "canopen",
  node_capacity? : Int = 127,
) -> CompatibilityTarget {
  compatibility_target(
    name,
    CompatibilityCanOpen,
    1000,
    0,
    8,
    11,
    node_capacity,
    features=["classic", "heartbeat", "sdo", "pdo", "nmt"],
    notes="CANopen network with heartbeat and object dictionary",
  )
}

///|
pub fn compatibility_j1939_target(
  name? : String = "j1939",
  node_capacity? : Int = 30,
) -> CompatibilityTarget {
  compatibility_target(
    name,
    CompatibilityJ1939,
    250,
    0,
    1785,
    29,
    node_capacity,
    features=["classic", "extended-id", "address-claim", "bam", "request"],
    notes="J1939 network with PGN addressing and BAM transport",
  )
}

///|
pub fn compatibility_gateway_target(
  name? : String = "gateway",
  node_capacity? : Int = 128,
) -> CompatibilityTarget {
  compatibility_target(
    name,
    CompatibilityGateway,
    1000,
    5_000,
    4095,
    29,
    node_capacity,
    features=["classic", "fd", "routing", "rate-limit", "diagnostics", "isotp"],
    notes="Multi-bus gateway with policy and diagnostic routing",
  )
}

///|
pub fn compatibility_default_matrix() -> CompatibilityMatrix {
  let matrix = compatibility_matrix(
    name="default production matrix",
    strict=true,
  )
  matrix.add_target(compatibility_classic_target())
  matrix.add_target(compatibility_fd_target())
  matrix.add_target(compatibility_isotp_target())
  matrix.add_target(compatibility_uds_target())
  matrix.add_target(compatibility_canopen_target())
  matrix.add_target(compatibility_j1939_target())
  matrix.add_target(compatibility_gateway_target())
  matrix.add_requirement(
    compatibility_minimum_bitrate(
      "NET-001",
      250,
      description="nominal bus speed supports the deployment profile",
    ),
  )
  matrix.add_requirement(
    compatibility_minimum_payload(
      "NET-002",
      8,
      description="single-frame payload is at least eight bytes",
    ),
  )
  matrix.add_requirement(
    compatibility_minimum_identifier_bits(
      "NET-003",
      11,
      description="identifier representation accepts standard CAN IDs",
    ),
  )
  matrix.add_requirement(
    compatibility_minimum_node_capacity(
      "NET-004",
      8,
      description="target can host the minimum node set",
    ),
  )
  matrix
}

///|
pub fn compatibility_diagnostics_matrix() -> CompatibilityMatrix {
  let matrix = compatibility_matrix(
    name="diagnostics deployment matrix",
    strict=true,
  )
  matrix.add_target(compatibility_isotp_target())
  matrix.add_target(compatibility_uds_target())
  matrix.add_target(compatibility_gateway_target())
  matrix.add_requirement(compatibility_requires_isotp("UDS-001"))
  matrix.add_requirement(compatibility_requires_diagnostics("UDS-002"))
  matrix.add_requirement(
    compatibility_requires_feature(
      "UDS-003",
      "dtc",
      description="diagnostic trouble code storage is available",
    ),
  )
  matrix.add_requirement(
    compatibility_minimum_payload(
      "UDS-004",
      4095,
      description="segmented diagnostic payload is available",
    ),
  )
  matrix
}

///|
pub fn compatibility_gateway_matrix() -> CompatibilityMatrix {
  let matrix = compatibility_matrix(
    name="gateway deployment matrix",
    strict=true,
  )
  matrix.add_target(compatibility_gateway_target())
  matrix.add_target(compatibility_fd_target())
  matrix.add_requirement(compatibility_requires_fd("GW-001"))
  matrix.add_requirement(
    compatibility_requires_feature(
      "GW-002",
      "routing",
      description="routing policy engine is available",
    ),
  )
  matrix.add_requirement(
    compatibility_requires_feature(
      "GW-003",
      "rate-limit",
      description="rate limiting is available",
      severity=CompatibilityWarning,
    ),
  )
  matrix.add_requirement(
    compatibility_minimum_data_bitrate(
      "GW-004",
      2000,
      description="data phase keeps gateway forwarding latency bounded",
    ),
  )
  matrix
}

///|
/// A named release gate composed of several matrices.
pub struct CompatibilityReleaseGate {
  name : String
  matrices : Array[CompatibilityMatrix]
  minimum_score : Int
  require_all_targets : Bool
}

///|
pub fn compatibility_release_gate(
  name? : String = "release compatibility gate",
  minimum_score? : Int = 80,
  require_all_targets? : Bool = false,
) -> CompatibilityReleaseGate {
  {
    name,
    matrices: [],
    minimum_score: if minimum_score < 0 {
      0
    } else if minimum_score > 100 {
      100
    } else {
      minimum_score
    },
    require_all_targets,
  }
}

///|
pub fn CompatibilityReleaseGate::add_matrix(
  self : CompatibilityReleaseGate,
  matrix : CompatibilityMatrix,
) -> Unit {
  self.matrices.push(matrix)
}

///|
pub fn CompatibilityReleaseGate::matrix_count(
  self : CompatibilityReleaseGate,
) -> Int {
  self.matrices.length()
}

///|
pub fn CompatibilityReleaseGate::minimum_score(
  self : CompatibilityReleaseGate,
) -> Int {
  self.minimum_score
}

///|
pub fn CompatibilityReleaseGate::require_all_targets(
  self : CompatibilityReleaseGate,
) -> Bool {
  self.require_all_targets
}

///|
pub fn CompatibilityReleaseGate::ready(self : CompatibilityReleaseGate) -> Bool {
  if self.matrices.length() == 0 {
    return false
  }
  for matrix in self.matrices {
    let summary = matrix.fleet_summary()
    if summary.failure_count > 0 {
      return false
    }
    if summary.lowest_score < self.minimum_score {
      return false
    }
    if self.require_all_targets &&
      summary.compatible_count != summary.target_count {
      return false
    }
  }
  true
}

///|
pub fn CompatibilityReleaseGate::report(
  self : CompatibilityReleaseGate,
) -> String {
  let builder = StringBuilder()
  builder.write_string("# ")
  builder.write_string(self.name)
  builder.write_string(" ready=")
  builder.write_string(if self.ready() { "true" } else { "false" })
  builder.write_string(" minimum_score=")
  builder.write_string(self.minimum_score.to_string())
  builder.write_string("\n")
  for matrix in self.matrices {
    builder.write_string(matrix.report())
  }
  builder.to_string()
}

///|
pub fn compatibility_default_release_gate() -> CompatibilityReleaseGate {
  let gate = compatibility_release_gate(
    name="CAN release compatibility gate",
    minimum_score=70,
    require_all_targets=false,
  )
  gate.add_matrix(compatibility_default_matrix())
  gate.add_matrix(compatibility_diagnostics_matrix())
  gate.add_matrix(compatibility_gateway_matrix())
  gate
}

///|
/// Compare two targets and describe the capabilities that are lost during a downgrade.
pub struct CompatibilityDelta {
  source : String
  destination : String
  bitrate_loss : Int
  data_bitrate_loss : Int
  payload_loss : Int
  identifier_loss : Int
  node_capacity_loss : Int
  lost_features : Array[String]
}

///|
fn compatibility_positive_loss(source : Int, destination : Int) -> Int {
  if source > destination {
    source - destination
  } else {
    0
  }
}

///|
pub fn compatibility_compare_targets(
  source : CompatibilityTarget,
  destination : CompatibilityTarget,
) -> CompatibilityDelta {
  let lost_features : Array[String] = []
  for feature in source.features {
    if !destination.has_feature(feature) {
      lost_features.push(feature)
    }
  }
  {
    source: source.name,
    destination: destination.name,
    bitrate_loss: compatibility_positive_loss(
      source.nominal_bitrate,
      destination.nominal_bitrate,
    ),
    data_bitrate_loss: compatibility_positive_loss(
      source.data_bitrate,
      destination.data_bitrate,
    ),
    payload_loss: compatibility_positive_loss(
      source.max_payload,
      destination.max_payload,
    ),
    identifier_loss: compatibility_positive_loss(
      source.identifier_bits,
      destination.identifier_bits,
    ),
    node_capacity_loss: compatibility_positive_loss(
      source.node_capacity,
      destination.node_capacity,
    ),
    lost_features,
  }
}

///|
pub fn CompatibilityDelta::source(self : CompatibilityDelta) -> String {
  self.source
}

///|
pub fn CompatibilityDelta::destination(self : CompatibilityDelta) -> String {
  self.destination
}

///|
pub fn CompatibilityDelta::bitrate_loss(self : CompatibilityDelta) -> Int {
  self.bitrate_loss
}

///|
pub fn CompatibilityDelta::data_bitrate_loss(self : CompatibilityDelta) -> Int {
  self.data_bitrate_loss
}

///|
pub fn CompatibilityDelta::payload_loss(self : CompatibilityDelta) -> Int {
  self.payload_loss
}

///|
pub fn CompatibilityDelta::identifier_loss(self : CompatibilityDelta) -> Int {
  self.identifier_loss
}

///|
pub fn CompatibilityDelta::node_capacity_loss(self : CompatibilityDelta) -> Int {
  self.node_capacity_loss
}

///|
pub fn CompatibilityDelta::lost_features(
  self : CompatibilityDelta,
) -> Array[String] {
  self.lost_features.copy()
}

///|
pub fn CompatibilityDelta::is_lossless(self : CompatibilityDelta) -> Bool {
  self.bitrate_loss == 0 &&
  self.data_bitrate_loss == 0 &&
  self.payload_loss == 0 &&
  self.identifier_loss == 0 &&
  self.node_capacity_loss == 0 &&
  self.lost_features.length() == 0
}

///|
pub fn CompatibilityDelta::report(self : CompatibilityDelta) -> String {
  let builder = StringBuilder()
  builder.write_string(self.source)
  builder.write_string(" -> ")
  builder.write_string(self.destination)
  builder.write_string(" lossless=")
  builder.write_string(if self.is_lossless() { "true" } else { "false" })
  builder.write_string(" bitrate_loss=")
  builder.write_string(self.bitrate_loss.to_string())
  builder.write_string(" data_bitrate_loss=")
  builder.write_string(self.data_bitrate_loss.to_string())
  builder.write_string(" payload_loss=")
  builder.write_string(self.payload_loss.to_string())
  builder.write_string(" identifier_loss=")
  builder.write_string(self.identifier_loss.to_string())
  builder.write_string(" node_capacity_loss=")
  builder.write_string(self.node_capacity_loss.to_string())
  builder.write_string(" lost_features=")
  builder.write_string(self.lost_features.length().to_string())
  builder.to_string()
}

///|
/// A ranked compatibility candidate.
pub struct CompatibilityCandidate {
  target : CompatibilityTarget
  evaluation : CompatibilityEvaluation
  rank : Int
}

///|
pub fn CompatibilityCandidate::target(
  self : CompatibilityCandidate,
) -> CompatibilityTarget {
  self.target
}

///|
pub fn CompatibilityCandidate::evaluation(
  self : CompatibilityCandidate,
) -> CompatibilityEvaluation {
  self.evaluation
}

///|
pub fn CompatibilityCandidate::rank(self : CompatibilityCandidate) -> Int {
  self.rank
}

///|
pub fn CompatibilityCandidate::summary(self : CompatibilityCandidate) -> String {
  self.rank.to_string() +
  ": " +
  self.target.name +
  " " +
  self.evaluation.summary()
}

///|
pub fn CompatibilityMatrix::ranked_candidates(
  self : CompatibilityMatrix,
) -> Array[CompatibilityCandidate] {
  let candidates : Array[CompatibilityCandidate] = []
  for target in self.targets {
    let evaluation = self.evaluate(target)
    let mut rank = 0
    for previous in candidates {
      if evaluation.score > previous.evaluation.score {
        rank += 1
      }
    }
    candidates.push({ target, evaluation, rank })
  }
  candidates
}

///|
/// Validate a route between two protocol endpoints.
pub struct CompatibilityRoute {
  source : CompatibilityTarget
  destination : CompatibilityTarget
  transport : CompatibilityProtocol
  max_payload : Int
  uses_segmentation : Bool
  valid : Bool
  reason : String
}

///|
fn compatibility_route_reason(
  valid : Bool,
  transport : CompatibilityProtocol,
) -> String {
  if valid {
    "route supports the selected transport"
  } else {
    "route cannot carry the selected transport: " +
    compatibility_protocol_text(transport)
  }
}

///|
pub fn compatibility_route(
  source : CompatibilityTarget,
  destination : CompatibilityTarget,
  transport : CompatibilityProtocol,
) -> CompatibilityRoute {
  let source_payload = source.max_payload
  let destination_payload = destination.max_payload
  let max_payload = if source_payload < destination_payload {
    source_payload
  } else {
    destination_payload
  }
  let source_fd = compatibility_protocol_has_fd(source.protocol)
  let destination_fd = compatibility_protocol_has_fd(destination.protocol)
  let protocol_valid = match transport {
    CompatibilityClassicCan =>
      compatibility_protocol_has_classic(source.protocol) &&
      compatibility_protocol_has_classic(destination.protocol)
    CompatibilityCanFd => source_fd && destination_fd
    CompatibilityIsoTp =>
      compatibility_protocol_has_isotp(source.protocol) &&
      compatibility_protocol_has_isotp(destination.protocol)
    CompatibilityUds =>
      compatibility_protocol_has_diagnostics(source.protocol) &&
      compatibility_protocol_has_diagnostics(destination.protocol)
    CompatibilityCanOpen =>
      source.protocol is CompatibilityCanOpen &&
      destination.protocol is CompatibilityCanOpen
    CompatibilityJ1939 =>
      source.protocol is CompatibilityJ1939 &&
      destination.protocol is CompatibilityJ1939
    CompatibilityGateway =>
      source.protocol is CompatibilityGateway ||
      destination.protocol is CompatibilityGateway
    CompatibilityCustom => true
  }
  let uses_segmentation = transport is CompatibilityIsoTp ||
    transport is CompatibilityUds ||
    max_payload > 64
  let valid = protocol_valid && max_payload > 0
  {
    source,
    destination,
    transport,
    max_payload,
    uses_segmentation,
    valid,
    reason: compatibility_route_reason(valid, transport),
  }
}

///|
pub fn CompatibilityRoute::source(
  self : CompatibilityRoute,
) -> CompatibilityTarget {
  self.source
}

///|
pub fn CompatibilityRoute::destination(
  self : CompatibilityRoute,
) -> CompatibilityTarget {
  self.destination
}

///|
pub fn CompatibilityRoute::transport(
  self : CompatibilityRoute,
) -> CompatibilityProtocol {
  self.transport
}

///|
pub fn CompatibilityRoute::max_payload(self : CompatibilityRoute) -> Int {
  self.max_payload
}

///|
pub fn CompatibilityRoute::uses_segmentation(self : CompatibilityRoute) -> Bool {
  self.uses_segmentation
}

///|
pub fn CompatibilityRoute::valid(self : CompatibilityRoute) -> Bool {
  self.valid
}

///|
pub fn CompatibilityRoute::reason(self : CompatibilityRoute) -> String {
  self.reason
}

///|
pub fn CompatibilityRoute::summary(self : CompatibilityRoute) -> String {
  self.source.name +
  " -> " +
  self.destination.name +
  " " +
  compatibility_protocol_text(self.transport) +
  " valid=" +
  (if self.valid { "true" } else { "false" })
}

///|
/// A route table that prevents unsupported forwarding paths from reaching runtime.
pub struct CompatibilityRouteTable {
  routes : Array[CompatibilityRoute]
}

///|
pub fn compatibility_route_table() -> CompatibilityRouteTable {
  { routes: [] }
}

///|
pub fn CompatibilityRouteTable::add(
  self : CompatibilityRouteTable,
  route : CompatibilityRoute,
) -> Unit {
  self.routes.push(route)
}

///|
pub fn CompatibilityRouteTable::routes(
  self : CompatibilityRouteTable,
) -> Array[CompatibilityRoute] {
  self.routes.copy()
}

///|
pub fn CompatibilityRouteTable::valid_routes(
  self : CompatibilityRouteTable,
) -> Array[CompatibilityRoute] {
  let result : Array[CompatibilityRoute] = []
  for route in self.routes {
    if route.valid {
      result.push(route)
    }
  }
  result
}

///|
pub fn CompatibilityRouteTable::invalid_routes(
  self : CompatibilityRouteTable,
) -> Array[CompatibilityRoute] {
  let result : Array[CompatibilityRoute] = []
  for route in self.routes {
    if !route.valid {
      result.push(route)
    }
  }
  result
}

///|
pub fn CompatibilityRouteTable::report(
  self : CompatibilityRouteTable,
) -> String {
  let builder = StringBuilder()
  for route in self.routes {
    builder.write_string(route.summary())
    builder.write_string(" ")
    builder.write_string(route.reason)
    builder.write_string("\n")
  }
  builder.to_string()
}

///|
pub fn compatibility_build_default_routes() -> CompatibilityRouteTable {
  let table = compatibility_route_table()
  let classic = compatibility_classic_target()
  let fd = compatibility_fd_target()
  let uds = compatibility_uds_target()
  let gateway = compatibility_gateway_target()
  table.add(compatibility_route(classic, fd, CompatibilityClassicCan))
  table.add(compatibility_route(fd, gateway, CompatibilityCanFd))
  table.add(compatibility_route(uds, gateway, CompatibilityUds))
  table.add(compatibility_route(gateway, classic, CompatibilityGateway))
  table
}

///|
/// A compact machine-readable snapshot for logging and support bundles.
pub fn compatibility_snapshot(matrix : CompatibilityMatrix) -> String {
  let summary = matrix.fleet_summary()
  let builder = StringBuilder()
  builder.write_string("{\"name\":\"")
  builder.write_string(matrix.name)
  builder.write_string("\",\"targets\":")
  builder.write_string(summary.target_count.to_string())
  builder.write_string(",\"compatible\":")
  builder.write_string(summary.compatible_count.to_string())
  builder.write_string(",\"warnings\":")
  builder.write_string(summary.warning_count.to_string())
  builder.write_string(",\"failures\":")
  builder.write_string(summary.failure_count.to_string())
  builder.write_string(",\"average_score\":")
  builder.write_string(summary.average_score.to_string())
  builder.write_string("}")
  builder.to_string()
}

///|
/// Stable schema version for compatibility snapshots.
pub fn compatibility_schema_version() -> String {
  "compatibility-matrix-v1"
}

///|
/// Return a deterministic checksum-like fingerprint for a target.
pub fn compatibility_target_fingerprint(target : CompatibilityTarget) -> UInt64 {
  let mut value : UInt64 = 1469598103934665603
  value = (value ^ target.name.length().to_uint64()) * 1099511628211
  value = (value ^ target.nominal_bitrate.to_uint64()) * 1099511628211
  value = (value ^ target.data_bitrate.to_uint64()) * 1099511628211
  value = (value ^ target.max_payload.to_uint64()) * 1099511628211
  value = (value ^ target.identifier_bits.to_uint64()) * 1099511628211
  value = (value ^ target.node_capacity.to_uint64()) * 1099511628211
  for feature in target.features {
    value = (value ^ feature.length().to_uint64()) * 1099511628211
  }
  value
}

///|
/// Fingerprint all targets in insertion order for reproducible deployment metadata.
pub fn CompatibilityMatrix::fingerprint(self : CompatibilityMatrix) -> UInt64 {
  let mut value : UInt64 = 2166136261
  for target in self.targets {
    value = (value ^ compatibility_target_fingerprint(target)) * 16777619
  }
  for requirement in self.requirements {
    value = (value ^ requirement.code.length().to_uint64()) * 16777619
  }
  value
}

///|
/// Return a short status suitable for a health endpoint.
pub fn CompatibilityMatrix::status(self : CompatibilityMatrix) -> String {
  let summary = self.fleet_summary()
  if summary.target_count == 0 {
    "empty"
  } else if summary.failure_count > 0 {
    "failed"
  } else if summary.warning_count > 0 {
    "degraded"
  } else {
    "ready"
  }
}

///|
/// Filter requirements by severity for an operator-facing view.
pub fn CompatibilityMatrix::requirements_by_severity(
  self : CompatibilityMatrix,
  severity : CompatibilitySeverity,
) -> Array[CompatibilityRequirement] {
  let result : Array[CompatibilityRequirement] = []
  for requirement in self.requirements {
    let same = match severity {
      CompatibilityInfo => requirement.severity is CompatibilityInfo
      CompatibilityWarning => requirement.severity is CompatibilityWarning
      CompatibilityError => requirement.severity is CompatibilityError
    }
    if same {
      result.push(requirement)
    }
  }
  result
}

///|
/// Add the common minimums for a classical vehicle network.
pub fn compatibility_add_vehicle_requirements(
  matrix : CompatibilityMatrix,
) -> Unit {
  matrix.add_requirement(compatibility_minimum_bitrate("VEH-001", 250))
  matrix.add_requirement(compatibility_minimum_node_capacity("VEH-002", 16))
  matrix.add_requirement(
    compatibility_requires_feature(
      "VEH-003",
      "extended-id",
      description="vehicle network supports extended arbitration IDs",
      severity=CompatibilityWarning,
    ),
  )
}

///|
/// Add the common minimums for a diagnostic service.
pub fn compatibility_add_diagnostic_requirements(
  matrix : CompatibilityMatrix,
) -> Unit {
  matrix.add_requirement(compatibility_requires_isotp("DGN-001"))
  matrix.add_requirement(compatibility_requires_diagnostics("DGN-002"))
  matrix.add_requirement(compatibility_minimum_payload("DGN-003", 256))
  matrix.add_requirement(
    compatibility_requires_feature(
      "DGN-004",
      "security-access",
      description="security access hooks are available",
      severity=CompatibilityWarning,
    ),
  )
}

///|
/// Add the common minimums for a gateway deployment.
pub fn compatibility_add_gateway_requirements(
  matrix : CompatibilityMatrix,
) -> Unit {
  matrix.add_requirement(compatibility_requires_fd("GAT-001"))
  matrix.add_requirement(
    compatibility_requires_feature(
      "GAT-002",
      "routing",
      description="route policy evaluation is available",
    ),
  )
  matrix.add_requirement(
    compatibility_requires_feature(
      "GAT-003",
      "rate-limit",
      description="traffic shaping is available",
      severity=CompatibilityWarning,
    ),
  )
}

///|
/// Build a target set from a requested protocol family.
pub fn compatibility_targets_for_protocol(
  protocol : CompatibilityProtocol,
) -> Array[CompatibilityTarget] {
  match protocol {
    CompatibilityClassicCan => [compatibility_classic_target()]
    CompatibilityCanFd => [compatibility_fd_target()]
    CompatibilityIsoTp => [compatibility_isotp_target()]
    CompatibilityUds => [compatibility_uds_target()]
    CompatibilityCanOpen => [compatibility_canopen_target()]
    CompatibilityJ1939 => [compatibility_j1939_target()]
    CompatibilityGateway => [compatibility_gateway_target()]
    CompatibilityCustom => []
  }
}

///|
/// Check whether a target can be used as a bridge endpoint for a protocol.
pub fn compatibility_can_bridge(
  target : CompatibilityTarget,
  protocol : CompatibilityProtocol,
) -> Bool {
  let route = compatibility_route(target, target, protocol)
  route.valid
}

///|
/// Produce a bounded payload size for a route, reserving a byte for framing when needed.
pub fn compatibility_route_payload_budget(route : CompatibilityRoute) -> Int {
  if route.max_payload <= 0 {
    0
  } else if route.uses_segmentation {
    if route.max_payload > 1 {
      route.max_payload - 1
    } else {
      0
    }
  } else {
    route.max_payload
  }
}

///|
/// Build a plain-text incident hint from a failed evaluation.
pub fn compatibility_remediation(
  evaluation : CompatibilityEvaluation,
) -> String {
  if evaluation.is_compatible() {
    "no remediation required"
  } else {
    let builder = StringBuilder()
    builder.write_string("target ")
    builder.write_string(evaluation.target.name)
    builder.write_string(" has ")
    builder.write_string(evaluation.failures.to_string())
    builder.write_string(" blocking compatibility findings")
    if evaluation.warnings > 0 {
      builder.write_string(" and ")
      builder.write_string(evaluation.warnings.to_string())
      builder.write_string(" warnings")
    }
    builder.to_string()
  }
}

///|
/// Use the matrix as an acceptance predicate for one target.
pub fn compatibility_accepts(
  matrix : CompatibilityMatrix,
  target : CompatibilityTarget,
) -> Bool {
  matrix.evaluate(target).is_compatible()
}

///|
/// Return all failed requirements for a target.
pub fn compatibility_failures(
  evaluation : CompatibilityEvaluation,
) -> Array[CompatibilityIssue] {
  let result : Array[CompatibilityIssue] = []
  for issue in evaluation.issues {
    if !issue.passed {
      result.push(issue)
    }
  }
  result
}

///|
/// Return all warnings for a target.
pub fn compatibility_warnings(
  evaluation : CompatibilityEvaluation,
) -> Array[CompatibilityIssue] {
  let result : Array[CompatibilityIssue] = []
  for issue in evaluation.issues {
    if !issue.passed && issue.severity is CompatibilityWarning {
      result.push(issue)
    }
  }
  result
}

///|
/// Stable line-oriented output for CI annotations.
pub fn compatibility_ci_annotations(matrix : CompatibilityMatrix) -> String {
  let builder = StringBuilder()
  for evaluation in matrix.evaluate_all() {
    for issue in evaluation.issues {
      if !issue.passed {
        builder.write_string("::")
        builder.write_string(
          if issue.severity is CompatibilityError {
            "error"
          } else {
            "warning"
          },
        )
        builder.write_string(" title=")
        builder.write_string(issue.code)
        builder.write_string("::")
        builder.write_string(issue.message)
        builder.write_string("\n")
      }
    }
  }
  builder.to_string()
}

///|
/// Create a matrix from a single target and a reusable requirement set.
pub fn compatibility_matrix_for_target(
  target : CompatibilityTarget,
  requirements : Array[CompatibilityRequirement],
  strict? : Bool = true,
) -> CompatibilityMatrix {
  let matrix = compatibility_matrix(name=target.name + " matrix", strict~)
  matrix.add_target(target)
  for requirement in requirements {
    matrix.add_requirement(requirement)
  }
  matrix
}

///|
/// Construct a standard acceptance matrix for one target.
pub fn compatibility_standard_target_matrix(
  target : CompatibilityTarget,
) -> CompatibilityMatrix {
  let matrix = compatibility_matrix_for_target(target, [])
  matrix.add_requirement(compatibility_minimum_bitrate("STD-001", 125))
  matrix.add_requirement(compatibility_minimum_payload("STD-002", 8))
  matrix.add_requirement(compatibility_minimum_identifier_bits("STD-003", 11))
  matrix
}

///|
/// Describe the exact resources available to a target.
pub fn compatibility_inventory(target : CompatibilityTarget) -> String {
  let builder = StringBuilder()
  builder.write_string("name=")
  builder.write_string(target.name)
  builder.write_string("\nprotocol=")
  builder.write_string(compatibility_protocol_text(target.protocol))
  builder.write_string("\nnominal_bitrate=")
  builder.write_string(target.nominal_bitrate.to_string())
  builder.write_string("\ndata_bitrate=")
  builder.write_string(target.data_bitrate.to_string())
  builder.write_string("\nmax_payload=")
  builder.write_string(target.max_payload.to_string())
  builder.write_string("\nidentifier_bits=")
  builder.write_string(target.identifier_bits.to_string())
  builder.write_string("\nnode_capacity=")
  builder.write_string(target.node_capacity.to_string())
  builder.write_string("\nfeatures=")
  builder.write_string(target.feature_csv())
  builder.write_string("\nfingerprint=")
  builder.write_string(compatibility_target_fingerprint(target).to_string())
  builder.to_string()
}
