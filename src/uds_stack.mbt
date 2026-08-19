///|
/// Additional errors for building and validating UDS exchanges.
pub suberror UdsError {
  InvalidIdentifier
  InvalidAddressFormat
  EmptyPayload
  InvalidBlockCounter
  InvalidLength
} derive(Debug)

///|
/// A parsed positive or negative response with its service identifier.
pub struct UdsResponseInfo {
  positive : Bool
  response_service : Byte
  payload : Array[Byte]
  negative_code : Byte?
}

///|
/// Return the numeric service identifier.
pub fn uds_service_id(service : UdsService) -> Byte {
  match service {
    DiagnosticSessionControl => 0x10
    EcuReset => 0x11
    ReadDataByIdentifier => 0x22
    WriteDataByIdentifier => 0x2E
    ReadMemoryByAddress => 0x23
    WriteMemoryByAddress => 0x3D
    RoutineControl => 0x31
    SecurityAccess => 0x27
    CommunicationControl => 0x28
    ClearDiagnosticInformation => 0x14
    ReadDtcInformation => 0x19
    RequestDownload => 0x34
    TransferData => 0x36
    RequestTransferExit => 0x37
    TesterPresent => 0x3E
  }
}

///|
/// Return the service's stable diagnostic name.
pub fn uds_service_name(service : UdsService) -> String {
  match service {
    DiagnosticSessionControl => "DiagnosticSessionControl"
    EcuReset => "EcuReset"
    ReadDataByIdentifier => "ReadDataByIdentifier"
    WriteDataByIdentifier => "WriteDataByIdentifier"
    ReadMemoryByAddress => "ReadMemoryByAddress"
    WriteMemoryByAddress => "WriteMemoryByAddress"
    RoutineControl => "RoutineControl"
    SecurityAccess => "SecurityAccess"
    CommunicationControl => "CommunicationControl"
    ClearDiagnosticInformation => "ClearDiagnosticInformation"
    ReadDtcInformation => "ReadDtcInformation"
    RequestDownload => "RequestDownload"
    TransferData => "TransferData"
    RequestTransferExit => "RequestTransferExit"
    TesterPresent => "TesterPresent"
  }
}

///|
/// Return the request's numeric service identifier.
pub fn DiagnosticRequest::service_id(self : DiagnosticRequest) -> Byte {
  uds_service_id(self.service)
}

///|
/// Return the service's name.
pub fn DiagnosticRequest::service_name(self : DiagnosticRequest) -> String {
  uds_service_name(self.service)
}

///|
/// Return whether a request contains a suppress-positive-response bit.
pub fn DiagnosticRequest::suppress_response(self : DiagnosticRequest) -> Bool {
  match self.payload.last() {
    Some(value) =>
      (value.to_int() & 0x80) != 0 &&
      (
        self.service is TesterPresent ||
        self.service is DiagnosticSessionControl
      )
    None => false
  }
}

///|
/// Build a write-data-by-identifier request.
pub fn write_data(
  identifier : UInt,
  data : Array[Byte],
) -> DiagnosticRequest raise UdsError {
  if identifier > 0xFFFF {
    raise InvalidIdentifier
  }
  {
    service: WriteDataByIdentifier,
    payload: [0x2E, (identifier >> 8).to_byte(), identifier.to_byte()] + data,
  }
}

///|
/// Build a routine-control request with an optional input record.
pub fn routine_control(
  routine_type : Byte,
  identifier : UInt,
  data? : Array[Byte] = [],
) -> DiagnosticRequest raise UdsError {
  if identifier > 0xFFFF {
    raise InvalidIdentifier
  }
  {
    service: RoutineControl,
    payload: [
      0x31,
      routine_type,
      (identifier >> 8).to_byte(),
      identifier.to_byte(),
    ] +
    data,
  }
}

///|
/// Build a security-access seed/key request.
pub fn security_access(subfunction : Byte) -> DiagnosticRequest {
  { service: SecurityAccess, payload: [0x27, subfunction] }
}

///|
/// Build a communication-control request.
pub fn communication_control(
  control_type : Byte,
  communication_type : Byte,
) -> DiagnosticRequest {
  {
    service: CommunicationControl,
    payload: [0x28, control_type, communication_type],
  }
}

///|
/// Build a request to clear one DTC group or all groups.
pub fn clear_diagnostic_information(
  group : UInt,
) -> DiagnosticRequest raise UdsError {
  if group > 0xFFFFFF {
    raise InvalidIdentifier
  }
  {
    service: ClearDiagnosticInformation,
    payload: [
      0x14,
      (group >> 16).to_byte(),
      (group >> 8).to_byte(),
      group.to_byte(),
    ],
  }
}

///|
/// Build a DTC information request.
pub fn read_dtc_information(
  subfunction : Byte,
  mask : Byte,
) -> DiagnosticRequest {
  { service: ReadDtcInformation, payload: [0x19, subfunction, mask] }
}

///|
/// Build a memory read request using a compact address/length format.
pub fn read_memory(
  address : UInt,
  length : UInt,
  address_bytes? : Int = 2,
  length_bytes? : Int = 2,
) -> DiagnosticRequest raise UdsError {
  let format = check_address_format(address_bytes, length_bytes)
  {
    service: ReadMemoryByAddress,
    payload: [0x23, format] +
    encode_uint(address, address_bytes) +
    encode_uint(length, length_bytes),
  }
}

///|
/// Build a memory write request.
pub fn write_memory(
  address : UInt,
  data : Array[Byte],
  address_bytes? : Int = 2,
) -> DiagnosticRequest raise UdsError {
  let format = check_address_format(address_bytes, 1)
  {
    service: WriteMemoryByAddress,
    payload: [0x3D, format] +
    encode_uint(address, address_bytes) +
    encode_uint(data.length().reinterpret_as_uint(), 1) +
    data,
  }
}

///|
/// Build a request-download command.
pub fn request_download(
  data_format : Byte,
  address : UInt,
  length : UInt,
  address_bytes? : Int = 2,
  length_bytes? : Int = 2,
) -> DiagnosticRequest raise UdsError {
  let format = check_address_format(address_bytes, length_bytes)
  {
    service: RequestDownload,
    payload: [0x34, data_format, format] +
    encode_uint(address, address_bytes) +
    encode_uint(length, length_bytes),
  }
}

///|
/// Build a transfer-data block.
pub fn transfer_data(
  block_counter : Byte,
  data : Array[Byte],
) -> DiagnosticRequest raise UdsError {
  if block_counter == 0 {
    raise InvalidBlockCounter
  }
  { service: TransferData, payload: [0x36, block_counter] + data }
}

///|
pub fn request_transfer_exit(data? : Array[Byte] = []) -> DiagnosticRequest {
  { service: RequestTransferExit, payload: [0x37] + data }
}

///|
/// Parse a response and preserve the original payload for callers.
pub fn parse_uds_response(
  request : DiagnosticRequest,
  payload : Array[Byte],
) -> UdsResponseInfo raise UdsError {
  if payload.is_empty() {
    raise EmptyPayload
  }
  if payload[0] == 0x7F {
    if payload.length() < 3 {
      raise InvalidLength
    }
    {
      positive: false,
      response_service: payload[1],
      payload: payload.copy(),
      negative_code: Some(payload[2]),
    }
  } else {
    let expected = uds_service_id(request.service) + 0x40
    if payload[0] != expected {
      raise InvalidLength
    }
    {
      positive: true,
      response_service: payload[0],
      payload: payload.copy(),
      negative_code: None,
    }
  }
}

///|
pub fn UdsResponseInfo::is_positive(self : UdsResponseInfo) -> Bool {
  self.positive
}

///|
pub fn UdsResponseInfo::response_service(self : UdsResponseInfo) -> Byte {
  self.response_service
}

///|
pub fn UdsResponseInfo::payload(self : UdsResponseInfo) -> Array[Byte] {
  self.payload.copy()
}

///|
pub fn UdsResponseInfo::negative_code(self : UdsResponseInfo) -> Byte? {
  self.negative_code
}

///|
/// Return a stable description for common UDS negative response codes.
pub fn uds_negative_code_name(code : Byte) -> String {
  match code {
    0x10 => "general-reject"
    0x11 => "service-not-supported"
    0x12 => "subfunction-not-supported"
    0x13 => "incorrect-message-length-or-format"
    0x22 => "conditions-not-correct"
    0x24 => "request-sequence-error"
    0x31 => "request-out-of-range"
    0x33 => "security-access-denied"
    0x35 => "invalid-key"
    0x36 => "exceed-number-of-attempts"
    0x37 => "required-time-delay-not-expired"
    0x78 => "response-pending"
    _ => "unknown-negative-response"
  }
}

///|
/// Return a service request encoded as a CAN data frame.
pub fn diagnostic_frame(
  request : DiagnosticRequest,
  id : UInt,
  extended? : Bool = false,
) -> Frame raise FrameError {
  data_frame(id, request.payload, extended~)
}

///|
fn check_address_format(
  address_bytes : Int,
  length_bytes : Int,
) -> Byte raise UdsError {
  if address_bytes < 1 ||
    address_bytes > 4 ||
    length_bytes < 1 ||
    length_bytes > 4 {
    raise InvalidAddressFormat
  }
  ((address_bytes << 4) | length_bytes).to_byte()
}

///|
fn encode_uint(value : UInt, width : Int) -> Array[Byte] {
  let result : Array[Byte] = []
  for index in 0..<width {
    result.push((value >> (8 * (width - index - 1))).to_byte())
  }
  result
}
