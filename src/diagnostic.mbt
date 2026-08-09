///|
/// Common UDS service identifiers used by a diagnostic client.
pub enum UdsService {
  DiagnosticSessionControl
  EcuReset
  ReadDataByIdentifier
  TesterPresent
}

///|
/// A diagnostic request represented as a CAN payload.
pub struct DiagnosticRequest {
  service : UdsService
  payload : Array[Byte]
}

///|
/// Build a session-control request.
pub fn session_control(session : Byte) -> DiagnosticRequest {
  { service: DiagnosticSessionControl, payload: [(16).to_byte(), session] }
}

///|
/// Build an ECU reset request.
pub fn ecu_reset(reset_type : Byte) -> DiagnosticRequest {
  { service: EcuReset, payload: [(17).to_byte(), reset_type] }
}

///|
/// Build a tester-present request.
pub fn tester_present(suppress_response? : Bool = false) -> DiagnosticRequest {
  {
    service: TesterPresent,
    payload: [
      (62).to_byte(),
      if suppress_response {
        (128).to_byte()
      } else {
        0
      },
    ],
  }
}

///|
/// Build a read-data-by-identifier request.
pub fn read_data(identifier : UInt) -> DiagnosticRequest {
  {
    service: ReadDataByIdentifier,
    payload: [(34).to_byte(), (identifier >> 8).to_byte(), identifier.to_byte()],
  }
}

///|
/// Return the service kind.
pub fn DiagnosticRequest::service(self : DiagnosticRequest) -> UdsService {
  self.service
}

///|
/// Return a defensive copy of the UDS payload.
pub fn DiagnosticRequest::payload(self : DiagnosticRequest) -> Array[Byte] {
  self.payload.copy()
}

///|
/// A response classification for a diagnostic exchange.
pub enum DiagnosticResponse {
  Positive(Array[Byte])
  Negative(code~ : Byte)
  Malformed
}

///|
/// Decode a UDS response payload.
pub fn decode_response(
  request : DiagnosticRequest,
  payload : Array[Byte],
) -> DiagnosticResponse {
  if payload.is_empty() {
    return Malformed
  }
  let expected = match request.service {
    DiagnosticSessionControl => 0x50
    EcuReset => 0x51
    ReadDataByIdentifier => 0x62
    TesterPresent => 0x7E
  }
  if payload[0].to_int() == expected {
    Positive(payload.copy())
  } else if payload[0].to_int() == 127 && payload.length() >= 3 {
    Negative(code=payload[2])
  } else {
    Malformed
  }
}
