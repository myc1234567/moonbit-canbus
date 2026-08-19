///|
/// A coarse frame class useful for metrics and routing policies.
pub enum FrameClass {
  ClassicData
  ClassicRemote
  CanFdData
  SimulationError
}

///|
/// A concrete validation finding.
pub enum FrameViolation {
  IdentifierRange
  ClassicPayloadRange
  FdPayloadRange
  RemoteCarriesData
  FdControlOnClassic
  InvalidErrorShape
  NonCanonicalDlc
} derive(Debug)

///|
/// The result of validating a normalized frame.
pub struct FrameReport {
  valid : Bool
  violations : Array[FrameViolation]
  wire_bits : Int
  stuffed_bits : Int
}

///|
/// Validate protocol and simulation invariants.
pub fn validate_frame(frame : Frame) -> FrameReport {
  let violations : Array[FrameViolation] = []
  let data_length = frame.data().length()
  let identifier_limit : UInt = if frame.is_extended() {
    0x1FFFFFFF
  } else {
    0x7FF
  }
  if frame.id() > identifier_limit {
    violations.push(IdentifierRange)
  }
  match frame.protocol() {
    Can20 => {
      if data_length > 8 {
        violations.push(ClassicPayloadRange)
      }
      if frame.bitrate_switch() || frame.error_state_indicator() {
        violations.push(FdControlOnClassic)
      }
    }
    CanFd => {
      if data_length > 64 {
        violations.push(FdPayloadRange)
      }
      if frame.kind() is Remote || frame.kind() is Error {
        violations.push(FdControlOnClassic)
      }
    }
  }
  if frame.kind() is Remote && data_length != 0 {
    violations.push(RemoteCarriesData)
  }
  if frame.kind() is Error &&
    (frame.id() != 0 || data_length != 1 || frame.is_extended()) {
    violations.push(InvalidErrorShape)
  }
  if frame.protocol() is CanFd && fd_length_from_dlc(frame.dlc()) < data_length {
    violations.push(NonCanonicalDlc)
  }
  let raw_bits = encode_bits(frame)
  let stuffed = stuff(raw_bits)
  {
    valid: violations.is_empty(),
    violations,
    wire_bits: frame_wire_bits(frame),
    stuffed_bits: stuffed.length(),
  }
}

///|
pub fn FrameReport::is_valid(self : FrameReport) -> Bool {
  self.valid
}

///|
pub fn FrameReport::violations(self : FrameReport) -> Array[FrameViolation] {
  self.violations.copy()
}

///|
pub fn FrameReport::wire_bits(self : FrameReport) -> Int {
  self.wire_bits
}

///|
pub fn FrameReport::stuffed_bits(self : FrameReport) -> Int {
  self.stuffed_bits
}

///|
/// Return whether a frame passes all normalized invariants.
pub fn frame_is_valid(frame : Frame) -> Bool {
  validate_frame(frame).is_valid()
}

///|
/// Classify a frame for counters and dashboards.
pub fn classify_frame(frame : Frame) -> FrameClass {
  if frame.is_error() {
    SimulationError
  } else if frame.protocol() is CanFd {
    CanFdData
  } else if frame.is_remote() {
    ClassicRemote
  } else {
    ClassicData
  }
}

///|
/// Return the maximum payload allowed by the protocol.
pub fn max_payload(protocol : Protocol) -> Int {
  match protocol {
    Can20 => 8
    CanFd => 64
  }
}

///|
/// Estimate transmission time in microseconds.
pub fn estimate_transmission_us(
  frame : Frame,
  arbitration_kbps : UInt,
  data_kbps : UInt,
) -> UInt64 {
  if arbitration_kbps == 0 || data_kbps == 0 {
    return 0
  }
  let bits = frame_wire_bits(frame).to_uint64()
  let rate = if frame.protocol() is CanFd && frame.bitrate_switch() {
    data_kbps.to_uint64()
  } else {
    arbitration_kbps.to_uint64()
  }
  (bits * 1000 + rate - 1) / rate
}

///|
/// Count stuffed bits in a sequence without allocating the stuffed result.
pub fn count_stuffed_bits(bits : Array[Bool]) -> Int {
  if bits.is_empty() {
    return 0
  }
  let mut previous = bits[0]
  let mut run = 1
  let mut inserted = 0
  for bit in bits[1:] {
    if bit == previous {
      run += 1
    } else {
      run = 1
      previous = bit
      continue
    }
    if run == 5 {
      inserted += 1
      run = 1
      previous = !previous
    }
  }
  inserted
}

///|
/// Return a stable arbitration-sorted copy.
pub fn sort_by_arbitration(frames : Array[Frame]) -> Array[Frame] {
  let result = frames.copy()
  result.sort_by((left, right) => compare_frames(left, right))
  result
}

///|
/// Return the frame class as a stable text label.
pub fn frame_class_name(class : FrameClass) -> String {
  match class {
    ClassicData => "classic-data"
    ClassicRemote => "classic-remote"
    CanFdData => "can-fd-data"
    SimulationError => "simulation-error"
  }
}

///|
/// Return a diagnostic description for a validation finding.
pub fn frame_violation_message(violation : FrameViolation) -> String {
  match violation {
    IdentifierRange => "identifier exceeds the selected CAN identifier width"
    ClassicPayloadRange => "classic CAN payload exceeds eight bytes"
    FdPayloadRange => "CAN-FD payload exceeds 64 bytes"
    RemoteCarriesData => "remote frames cannot carry payload bytes"
    FdControlOnClassic => "CAN-FD control flags or frame kind used with CAN 2.0"
    InvalidErrorShape => "simulation error frames must use id 0 and one byte"
    NonCanonicalDlc => "DLC does not cover the payload length"
  }
}
