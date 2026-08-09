///|
/// A CAN frame kind.
pub enum FrameKind {
  Data
  Remote
  Error
}

///|
/// A CAN bus protocol version.
pub enum Protocol {
  Can20
  CanFd
}

///|
/// A normalized CAN frame.
pub struct Frame {
  id : UInt
  extended : Bool
  kind : FrameKind
  protocol : Protocol
  bitrate_switch : Bool
  error_state_indicator : Bool
  data : Array[Byte]
}

///|
/// A frame validation error.
pub suberror FrameError {
  InvalidIdentifier
  InvalidLength
} derive(Debug)

///|
/// Create a classic CAN data frame.
pub fn data_frame(
  id : UInt,
  data : Array[Byte],
  extended? : Bool = false,
) -> Frame raise FrameError {
  validate_id(id, extended)
  if data.length() > 8 {
    raise InvalidLength
  }
  {
    id,
    extended,
    kind: Data,
    protocol: Can20,
    bitrate_switch: false,
    error_state_indicator: false,
    data: data.copy(),
  }
}

///|
/// Create a CAN-FD data frame.
pub fn fd_frame(
  id : UInt,
  data : Array[Byte],
  extended? : Bool = false,
  bitrate_switch? : Bool = false,
  error_state_indicator? : Bool = false,
) -> Frame raise FrameError {
  validate_id(id, extended)
  if data.length() > 64 {
    raise InvalidLength
  }
  {
    id,
    extended,
    kind: Data,
    protocol: CanFd,
    bitrate_switch,
    error_state_indicator,
    data: data.copy(),
  }
}

///|
/// Create a remote request frame.
pub fn remote_frame(
  id : UInt,
  extended? : Bool = false,
) -> Frame raise FrameError {
  validate_id(id, extended)
  {
    id,
    extended,
    kind: Remote,
    protocol: Can20,
    bitrate_switch: false,
    error_state_indicator: false,
    data: [],
  }
}

///|
/// Create a local error frame for simulation and diagnostics.
pub fn error_frame(code : Byte) -> Frame {
  {
    id: 0,
    extended: false,
    kind: Error,
    protocol: Can20,
    bitrate_switch: false,
    error_state_indicator: false,
    data: [code],
  }
}

///|
fn validate_id(id : UInt, extended : Bool) -> Unit raise FrameError {
  if extended {
    if id > 0x1FFFFFFF {
      raise InvalidIdentifier
    }
  } else if id > 0x7FF {
    raise InvalidIdentifier
  }
}

///|
/// The arbitration identifier.
pub fn Frame::id(self : Frame) -> UInt {
  self.id
}

///|
/// Whether the frame uses the 29-bit identifier format.
pub fn Frame::is_extended(self : Frame) -> Bool {
  self.extended
}

///|
/// Return the frame kind.
pub fn Frame::kind(self : Frame) -> FrameKind {
  self.kind
}

///|
/// Return the protocol version.
pub fn Frame::protocol(self : Frame) -> Protocol {
  self.protocol
}

///|
/// Return a defensive copy of the payload.
pub fn Frame::data(self : Frame) -> Array[Byte] {
  self.data.copy()
}

///|
/// Return whether the CAN-FD bit-rate switch is set.
pub fn Frame::bitrate_switch(self : Frame) -> Bool {
  self.bitrate_switch
}

///|
/// Return the data length code for this frame.
pub fn Frame::dlc(self : Frame) -> Byte {
  match self.protocol {
    Can20 => self.data.length().to_byte()
    CanFd => fd_dlc(self.data.length())
  }
}

///|
fn fd_dlc(length : Int) -> Byte {
  if length <= 8 {
    length.to_byte()
  } else if length <= 12 {
    9
  } else if length <= 16 {
    10
  } else if length <= 20 {
    11
  } else if length <= 24 {
    12
  } else if length <= 32 {
    13
  } else if length <= 48 {
    14
  } else {
    15
  }
}

///|
/// Decode a CAN-FD DLC into its payload capacity.
pub fn fd_length_from_dlc(dlc : Byte) -> Int {
  if dlc <= 8 {
    dlc.to_int()
  } else if dlc == 9 {
    12
  } else if dlc == 10 {
    16
  } else if dlc == 11 {
    20
  } else if dlc == 12 {
    24
  } else if dlc == 13 {
    32
  } else if dlc == 14 {
    48
  } else {
    64
  }
}
