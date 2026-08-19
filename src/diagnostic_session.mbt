///|
/// UDS application session states.
pub enum UdsSessionState {
  DefaultSession
  ProgrammingSession
  ExtendedDiagnosticSession
  SafetySystemDiagnosticSession
  LockedSession
} derive(Debug)

///|
/// Errors raised by the session state machine.
pub suberror UdsSessionError {
  InvalidTransition
  SecurityRequired
  ResponseTimeout
  UnexpectedResponse
} derive(Debug)

///|
/// A small deterministic UDS session tracker.
pub struct UdsSession {
  mut state : UdsSessionState
  mut unlocked : Bool
  mut last_activity_us : UInt64
  p2_timeout_us : UInt64
  mut pending_service : UdsService?
}

///|
pub fn new_uds_session(p2_timeout_us? : UInt64 = 50_000) -> UdsSession {
  {
    state: DefaultSession,
    unlocked: false,
    last_activity_us: 0,
    p2_timeout_us,
    pending_service: None,
  }
}

///|
/// Create a session that requires security access for protected services.
pub fn locked_uds_session(p2_timeout_us? : UInt64 = 50_000) -> UdsSession {
  let session = new_uds_session(p2_timeout_us~)
  session.state = LockedSession
  session
}

///|
pub fn UdsSession::state(self : UdsSession) -> UdsSessionState {
  self.state
}

///|
pub fn UdsSession::is_unlocked(self : UdsSession) -> Bool {
  self.unlocked
}

///|
pub fn UdsSession::last_activity(self : UdsSession) -> UInt64 {
  self.last_activity_us
}

///|
pub fn UdsSession::pending_service(self : UdsSession) -> UdsService? {
  self.pending_service
}

///|
/// Mark the current activity time.
pub fn UdsSession::touch(self : UdsSession, timestamp_us : UInt64) -> Unit {
  self.last_activity_us = timestamp_us
}

///|
/// Check whether the response timer has expired.
pub fn UdsSession::timed_out(self : UdsSession, timestamp_us : UInt64) -> Bool {
  timestamp_us >= self.last_activity_us + self.p2_timeout_us
}

///|
/// Begin a request and remember the expected service.
pub fn UdsSession::begin(
  self : UdsSession,
  request : DiagnosticRequest,
  timestamp_us : UInt64,
) -> DiagnosticRequest raise UdsSessionError {
  if request.service() is SecurityAccess && self.state is LockedSession {
    self.pending_service = Some(request.service())
    self.touch(timestamp_us)
    request
  } else if request.service() is WriteMemoryByAddress ||
    request.service() is RequestDownload {
    if !self.unlocked {
      raise SecurityRequired
    }
    self.pending_service = Some(request.service())
    self.touch(timestamp_us)
    request
  } else {
    self.pending_service = Some(request.service())
    self.touch(timestamp_us)
    request
  }
}

///|
/// Apply a diagnostic response and advance session state.
pub fn UdsSession::accept(
  self : UdsSession,
  request : DiagnosticRequest,
  payload : Array[Byte],
  timestamp_us : UInt64,
) -> UdsResponseInfo raise UdsSessionError {
  if self.timed_out(timestamp_us) && timestamp_us != 0 {
    raise ResponseTimeout
  }
  let response = parse_uds_response(request, payload) catch {
    _ => raise UnexpectedResponse
  }
  self.touch(timestamp_us)
  if response.is_positive() {
    match request.service() {
      DiagnosticSessionControl => self.apply_session(payload)
      SecurityAccess =>
        if payload.length() >= 2 && (payload[1].to_int() & 1) == 0 {
          self.unlocked = true
        }
      _ => ()
    }
  }
  self.pending_service = None
  response
}

///|
/// Force a session change after an externally validated response.
pub fn UdsSession::change_state(
  self : UdsSession,
  target : UdsSessionState,
) -> Unit raise UdsSessionError {
  if self.state is LockedSession && !(target is DefaultSession) {
    raise InvalidTransition
  }
  self.state = target
}

///|
/// Return whether a service is safe in the current state.
pub fn UdsSession::allows(self : UdsSession, service : UdsService) -> Bool {
  if service is TesterPresent ||
    service is DiagnosticSessionControl ||
    service is ReadDataByIdentifier ||
    service is SecurityAccess {
    true
  } else {
    !(self.state is LockedSession) && self.unlocked
  }
}

///|
fn UdsSession::apply_session(self : UdsSession, payload : Array[Byte]) -> Unit {
  if payload.length() < 2 {
    return
  }
  self.state = match payload[1] {
    1 => DefaultSession
    2 => ProgrammingSession
    3 => ExtendedDiagnosticSession
    4 => SafetySystemDiagnosticSession
    _ => self.state
  }
}

///|
/// Return a stable state label.
pub fn uds_session_name(state : UdsSessionState) -> String {
  match state {
    DefaultSession => "default"
    ProgrammingSession => "programming"
    ExtendedDiagnosticSession => "extended"
    SafetySystemDiagnosticSession => "safety"
    LockedSession => "locked"
  }
}
