///|
/// CANopen communication object types.
pub(all) enum CanOpenCobType {
  Nmt
  Sync
  Emergency
  Pdo1Transmit
  Pdo1Receive
  Pdo2Transmit
  Pdo2Receive
  Pdo3Transmit
  Pdo3Receive
  Pdo4Transmit
  Pdo4Receive
  SdoTransmit
  SdoReceive
  Heartbeat
} derive(Debug)

///|
/// Errors raised by CANopen identifier and SDO helpers.
pub suberror CanOpenError {
  InvalidNodeId
  InvalidCobId
  InvalidIndex
  InvalidSdoPayload
  InvalidDataLength
} derive(Debug)

///|
/// A decoded CANopen communication object identifier.
pub struct CanOpenCobId {
  object_type : CanOpenCobType
  node_id : Byte
  identifier : UInt
}

///|
/// Create a standard CANopen COB-ID for a node.
pub fn canopen_cob_id(
  object_type : CanOpenCobType,
  node_id : Byte,
) -> UInt raise CanOpenError {
  if node_id == 0 || node_id > 127 {
    raise InvalidNodeId
  }
  let base : UInt = match object_type {
    Nmt => 0
    Sync => 0x80
    Emergency => 0x80
    Pdo1Transmit => 0x180
    Pdo1Receive => 0x200
    Pdo2Transmit => 0x280
    Pdo2Receive => 0x300
    Pdo3Transmit => 0x380
    Pdo3Receive => 0x400
    Pdo4Transmit => 0x480
    Pdo4Receive => 0x500
    SdoTransmit => 0x580
    SdoReceive => 0x600
    Heartbeat => 0x700
  }
  if object_type is Nmt {
    0
  } else if object_type is Sync {
    base
  } else {
    base + node_id.to_uint()
  }
}

///|
/// Decode a standard CANopen COB-ID using the conventional ranges.
pub fn decode_canopen_cob_id(
  identifier : UInt,
) -> CanOpenCobId raise CanOpenError {
  if identifier > 0x7FF {
    raise InvalidCobId
  }
  let object_type = if identifier == 0 {
    Nmt
  } else if identifier == 0x80 {
    Sync
  } else if identifier >= 0x81 && identifier <= 0xFF {
    Emergency
  } else if identifier >= 0x181 && identifier <= 0x1FF {
    Pdo1Transmit
  } else if identifier >= 0x201 && identifier <= 0x27F {
    Pdo1Receive
  } else if identifier >= 0x281 && identifier <= 0x2FF {
    Pdo2Transmit
  } else if identifier >= 0x301 && identifier <= 0x37F {
    Pdo2Receive
  } else if identifier >= 0x381 && identifier <= 0x3FF {
    Pdo3Transmit
  } else if identifier >= 0x401 && identifier <= 0x47F {
    Pdo3Receive
  } else if identifier >= 0x481 && identifier <= 0x4FF {
    Pdo4Transmit
  } else if identifier >= 0x501 && identifier <= 0x57F {
    Pdo4Receive
  } else if identifier >= 0x581 && identifier <= 0x5FF {
    SdoTransmit
  } else if identifier >= 0x601 && identifier <= 0x67F {
    SdoReceive
  } else if identifier >= 0x701 && identifier <= 0x77F {
    Heartbeat
  } else {
    raise InvalidCobId
  }
  let node_id : Byte = if object_type is Nmt || object_type is Sync {
    0
  } else {
    (identifier & 0x7F).to_byte()
  }
  { object_type, node_id, identifier }
}

///|
pub fn CanOpenCobId::object_type(self : CanOpenCobId) -> CanOpenCobType {
  self.object_type
}

///|
pub fn CanOpenCobId::node_id(self : CanOpenCobId) -> Byte {
  self.node_id
}

///|
pub fn CanOpenCobId::identifier(self : CanOpenCobId) -> UInt {
  self.identifier
}

///|
/// CANopen NMT state commands.
pub(all) enum CanOpenNmtCommand {
  Start
  Stop
  EnterPreOperational
  ResetNode
  ResetCommunication
}

///|
/// Build an NMT command frame.
pub fn canopen_nmt(
  command : CanOpenNmtCommand,
  node_id : Byte,
) -> Array[Byte] raise CanOpenError {
  if node_id > 127 {
    raise InvalidNodeId
  }
  let code = match command {
    Start => 1
    Stop => 2
    EnterPreOperational => 128
    ResetNode => 129
    ResetCommunication => 130
  }
  [code.to_byte(), node_id]
}

///|
/// Build a heartbeat payload.
pub fn canopen_heartbeat(state : Byte) -> Array[Byte] {
  [state]
}

///|
/// Build an emergency payload with standard CANopen fields.
pub fn canopen_emergency(
  error_code : UInt,
  error_register : Byte,
  manufacturer_data : Array[Byte],
) -> Array[Byte] raise CanOpenError {
  if error_code > 0xFFFF || manufacturer_data.length() > 5 {
    raise InvalidDataLength
  }
  [error_code.to_byte(), (error_code >> 8).to_byte(), error_register] +
  manufacturer_data +
  Array::make(5 - manufacturer_data.length(), 0)
}

///|
/// A compact SDO command representation.
pub enum CanOpenSdoCommand {
  DownloadInitiate(index~ : UInt, sub_index~ : Byte, data~ : Array[Byte])
  UploadInitiate(index~ : UInt, sub_index~ : Byte)
  DownloadSegment(toggle~ : Bool, data~ : Array[Byte], last~ : Bool)
  UploadSegment(toggle~ : Bool)
  Abort(index~ : UInt, sub_index~ : Byte, code~ : UInt)
}

///|
/// Build a typed expedited download command.
pub fn canopen_sdo_download_command(
  index : UInt,
  sub_index : Byte,
  data : Array[Byte],
) -> CanOpenSdoCommand raise CanOpenError {
  if index > 0xFFFF || data.is_empty() || data.length() > 4 {
    raise InvalidDataLength
  }
  DownloadInitiate(index~, sub_index~, data~)
}

///|
/// Build a typed segmented download command.
pub fn canopen_sdo_download_segment(
  toggle : Bool,
  data : Array[Byte],
  last : Bool,
) -> CanOpenSdoCommand raise CanOpenError {
  if data.is_empty() || data.length() > 7 {
    raise InvalidDataLength
  }
  DownloadSegment(toggle~, data~, last~)
}

///|
/// Build a typed segmented upload command.
pub fn canopen_sdo_upload_segment(toggle : Bool) -> CanOpenSdoCommand {
  UploadSegment(toggle~)
}

///|
/// Build an expedited SDO download request.
pub fn canopen_sdo_download(
  index : UInt,
  sub_index : Byte,
  data : Array[Byte],
) -> Array[Byte] raise CanOpenError {
  let typed = canopen_sdo_download_command(index, sub_index, data)
  match typed {
    DownloadInitiate(index~, sub_index~, data~) => {
      let unused = 4 - data.length()
      let command = 0x23 | (unused << 2)
      [command.to_byte(), index.to_byte(), (index >> 8).to_byte(), sub_index] +
      data +
      Array::make(unused, 0)
    }
    _ => raise InvalidDataLength
  }
}

///|
/// Build an SDO upload request.
pub fn canopen_sdo_upload(
  index : UInt,
  sub_index : Byte,
) -> Array[Byte] raise CanOpenError {
  if index > 0xFFFF {
    raise InvalidIndex
  }
  [0x40, index.to_byte(), (index >> 8).to_byte(), sub_index, 0, 0, 0, 0]
}

///|
/// Decode one SDO response command.
pub fn canopen_sdo_decode(
  payload : Array[Byte],
) -> CanOpenSdoCommand raise CanOpenError {
  if payload.length() < 4 {
    raise InvalidSdoPayload
  }
  let command = payload[0].to_int()
  let index = payload[1].to_uint() | (payload[2].to_uint() << 8)
  let sub_index = payload[3]
  if command == 0x60 {
    UploadInitiate(index~, sub_index~)
  } else if command == 0x80 && payload.length() >= 8 {
    Abort(
      index~,
      sub_index~,
      code=payload[4].to_uint() |
        (payload[5].to_uint() << 8) |
        (payload[6].to_uint() << 16) |
        (payload[7].to_uint() << 24),
    )
  } else if (command & 0xE0) == 0x40 {
    UploadInitiate(index~, sub_index~)
  } else {
    raise InvalidSdoPayload
  }
}

///|
/// Build a CAN frame for an SDO payload.
pub fn canopen_sdo_frame(
  node_id : Byte,
  transmit : Bool,
  payload : Array[Byte],
) -> Frame raise CanOpenError {
  let object_type = if transmit { SdoTransmit } else { SdoReceive }
  let identifier = canopen_cob_id(object_type, node_id)
  data_frame(identifier, payload) catch {
    _ => raise InvalidDataLength
  }
}

///|
/// Return the textual name of a CANopen object type.
pub fn canopen_cob_name(object_type : CanOpenCobType) -> String {
  match object_type {
    Nmt => "nmt"
    Sync => "sync"
    Emergency => "emergency"
    Pdo1Transmit => "tpdo1"
    Pdo1Receive => "rpdo1"
    Pdo2Transmit => "tpdo2"
    Pdo2Receive => "rpdo2"
    Pdo3Transmit => "tpdo3"
    Pdo3Receive => "rpdo3"
    Pdo4Transmit => "tpdo4"
    Pdo4Receive => "rpdo4"
    SdoTransmit => "tsdo"
    SdoReceive => "rsdo"
    Heartbeat => "heartbeat"
  }
}
