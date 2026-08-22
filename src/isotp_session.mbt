///|
/// ISO-TP addressing format for a diagnostic transport channel.
pub enum IsoTpSessionAddressing {
  IsoTpNormalAddressing
  IsoTpExtendedAddressing(Byte)
  IsoTpMixedAddressing(Byte)
}

///|
/// Construct all portable ISO-TP addressing formats.
pub fn isotp_session_addressing_variants() -> Array[IsoTpSessionAddressing] {
  [IsoTpNormalAddressing, IsoTpExtendedAddressing(0), IsoTpMixedAddressing(0)]
}

///|
/// Flow-control parameters advertised by a receiver.
pub struct IsoTpFlowControlConfig {
  block_size : Int
  separation_time_us : UInt64
  wait_frame_limit : Int
  max_payload : Int
}

///|
/// Create flow-control parameters with safe bounds.
pub fn isotp_flow_control_config(
  block_size : Int,
  separation_time_us : UInt64,
  wait_frame_limit : Int,
  max_payload : Int,
) -> IsoTpFlowControlConfig {
  {
    block_size: if block_size < 0 {
      0
    } else {
      block_size
    },
    separation_time_us,
    wait_frame_limit: if wait_frame_limit < 0 {
      0
    } else {
      wait_frame_limit
    },
    max_payload: if max_payload < 0 {
      0
    } else {
      max_payload
    },
  }
}

///|
pub fn IsoTpFlowControlConfig::block_size(self : IsoTpFlowControlConfig) -> Int {
  self.block_size
}

///|
pub fn IsoTpFlowControlConfig::separation_time_us(
  self : IsoTpFlowControlConfig,
) -> UInt64 {
  self.separation_time_us
}

///|
pub fn IsoTpFlowControlConfig::wait_frame_limit(
  self : IsoTpFlowControlConfig,
) -> Int {
  self.wait_frame_limit
}

///|
pub fn IsoTpFlowControlConfig::max_payload(
  self : IsoTpFlowControlConfig,
) -> Int {
  self.max_payload
}

///|
/// Return the wire representation of a flow-control frame.
pub fn IsoTpFlowControlConfig::to_payload(
  self : IsoTpFlowControlConfig,
) -> Array[Byte] {
  [0x30, self.block_size.to_byte(), (self.separation_time_us / 1000).to_byte()]
}

///|
/// State of a long-payload ISO-TP transmitter.
pub enum IsoTpTransmitterState {
  IsoTpTxIdle
  IsoTpTxWaitingFlowControl
  IsoTpTxSending
  IsoTpTxComplete
  IsoTpTxAborted(String)
}

///|
/// Construct every transmitter state for state-machine tools.
pub fn isotp_transmitter_state_variants() -> Array[IsoTpTransmitterState] {
  [
    IsoTpTxIdle,
    IsoTpTxWaitingFlowControl,
    IsoTpTxSending,
    IsoTpTxComplete,
    IsoTpTxAborted("example"),
  ]
}

///|
/// A stateful ISO-TP transmitter.
pub struct IsoTpTransmitter {
  payload : Array[Byte]
  mut offset : Int
  mut sequence : Byte
  mut block_sent : Int
  mut wait_frames : Int
  mut state : IsoTpTransmitterState
  flow_control : IsoTpFlowControlConfig
  mut next_due_us : UInt64
  started_us : UInt64
}

///|
/// Create a transmitter for a bounded payload.
pub fn new_isotp_transmitter(
  payload : Array[Byte],
  flow_control : IsoTpFlowControlConfig,
  started_us : UInt64,
) -> IsoTpTransmitter {
  let state = if payload.length() <= 7 {
    IsoTpTxSending
  } else {
    IsoTpTxWaitingFlowControl
  }
  {
    payload: payload.copy(),
    offset: 0,
    sequence: 1,
    block_sent: 0,
    wait_frames: 0,
    state,
    flow_control,
    next_due_us: started_us,
    started_us,
  }
}

///|
pub fn IsoTpTransmitter::payload(self : IsoTpTransmitter) -> Array[Byte] {
  self.payload.copy()
}

///|
pub fn IsoTpTransmitter::offset(self : IsoTpTransmitter) -> Int {
  self.offset
}

///|
pub fn IsoTpTransmitter::remaining(self : IsoTpTransmitter) -> Int {
  self.payload.length() - self.offset
}

///|
pub fn IsoTpTransmitter::sequence(self : IsoTpTransmitter) -> Byte {
  self.sequence
}

///|
pub fn IsoTpTransmitter::state(
  self : IsoTpTransmitter,
) -> IsoTpTransmitterState {
  self.state
}

///|
pub fn IsoTpTransmitter::next_due_us(self : IsoTpTransmitter) -> UInt64 {
  self.next_due_us
}

///|
pub fn IsoTpTransmitter::started_us(self : IsoTpTransmitter) -> UInt64 {
  self.started_us
}

///|
pub fn IsoTpTransmitter::is_complete(self : IsoTpTransmitter) -> Bool {
  self.state is IsoTpTxComplete
}

///|
pub fn IsoTpTransmitter::is_aborted(self : IsoTpTransmitter) -> Bool {
  self.state is IsoTpTxAborted(_)
}

///|
/// Accept a receiver flow-control payload.
pub fn IsoTpTransmitter::accept_flow_control(
  self : IsoTpTransmitter,
  payload : Array[Byte],
  timestamp_us : UInt64,
) -> Bool {
  if payload.length() < 3 || (payload[0].to_int() & 0xF0) != 0x30 {
    self.abort("invalid flow control")
    false
  } else {
    let status = payload[0].to_int() & 0x0F
    if status == 0x1 {
      self.wait_frames += 1
      if self.wait_frames > self.flow_control.wait_frame_limit() {
        self.abort("flow-control wait limit exceeded")
        false
      } else {
        self.state = IsoTpTxWaitingFlowControl
        true
      }
    } else if status == 0x2 {
      self.abort("flow-control overflow")
      false
    } else {
      self.block_sent = 0
      self.wait_frames = 0
      self.state = IsoTpTxSending
      self.next_due_us = timestamp_us
      true
    }
  }
}

///|
/// Produce the next ISO-TP payload when the transmitter is due.
pub fn IsoTpTransmitter::next_payload(
  self : IsoTpTransmitter,
  timestamp_us : UInt64,
) -> Array[Byte]? {
  if self.is_complete() || self.is_aborted() || timestamp_us < self.next_due_us {
    None
  } else if self.payload.length() <= 7 && self.offset == 0 {
    let result : Array[Byte] = [self.payload.length().to_byte()]
    result.append(self.payload.copy())
    self.offset = self.payload.length()
    self.state = IsoTpTxComplete
    Some(result)
  } else if self.offset == 0 {
    let length = self.payload.length()
    let result : Array[Byte] = [
      0x10 | (length >> 8).to_byte(),
      length.to_byte(),
    ]
    let take = if length > 6 { 6 } else { length }
    result.append(self.payload[:take].to_owned())
    self.offset = take
    self.sequence = 1
    self.block_sent = 0
    self.state = IsoTpTxWaitingFlowControl
    Some(result)
  } else if self.state is IsoTpTxSending {
    let remaining = self.payload.length() - self.offset
    let take = if remaining > 7 { 7 } else { remaining }
    let result : Array[Byte] = [0x20 | self.sequence.to_int().to_byte()]
    result.append(self.payload[self.offset:self.offset + take].to_owned())
    self.offset += take
    self.sequence = ((self.sequence.to_int() + 1) & 0x0F).to_byte()
    self.block_sent += 1
    self.next_due_us = timestamp_us + self.flow_control.separation_time_us()
    if self.offset >= self.payload.length() {
      self.state = IsoTpTxComplete
    } else if self.flow_control.block_size() > 0 &&
      self.block_sent >= self.flow_control.block_size() {
      self.state = IsoTpTxWaitingFlowControl
      self.block_sent = 0
    }
    Some(result)
  } else {
    None
  }
}

///|
/// Abort a transmitter with a stable reason.
pub fn IsoTpTransmitter::abort(
  self : IsoTpTransmitter,
  reason : String,
) -> Unit {
  self.state = IsoTpTxAborted(reason)
}

///|
/// Return an upper bound for the remaining transfer duration.
pub fn IsoTpTransmitter::estimated_finish_us(self : IsoTpTransmitter) -> UInt64 {
  if self.is_complete() || self.is_aborted() {
    self.next_due_us
  } else {
    let frames = (self.remaining() + 6) / 7
    self.next_due_us +
    frames.to_uint64() * self.flow_control.separation_time_us()
  }
}

///|
/// A receiver result for an incoming ISO-TP payload.
pub enum IsoTpReceiverResult {
  IsoTpRxIgnored
  IsoTpRxFlowControl(Array[Byte])
  IsoTpRxProgress(Int)
  IsoTpRxComplete(Array[Byte])
  IsoTpRxError(String)
}

///|
/// Construct representative receiver results.
pub fn isotp_receiver_result_variants() -> Array[IsoTpReceiverResult] {
  [
    IsoTpRxIgnored,
    IsoTpRxFlowControl([0x30, 0, 0]),
    IsoTpRxProgress(0),
    IsoTpRxComplete([]),
    IsoTpRxError("example"),
  ]
}

///|
/// A stateful ISO-TP receiver.
pub struct IsoTpStreamReceiver {
  mut expected_length : Int
  mut received : Array[Byte]
  mut next_sequence : Byte
  mut block_received : Int
  mut wait_frames : Int
  mut last_timestamp_us : UInt64
  mut active : Bool
  mut complete : Bool
  flow_control : IsoTpFlowControlConfig
  timeout_us : UInt64
}

///|
pub fn new_isotp_stream_receiver(
  flow_control : IsoTpFlowControlConfig,
  timeout_us : UInt64,
) -> IsoTpStreamReceiver {
  {
    expected_length: 0,
    received: [],
    next_sequence: 1,
    block_received: 0,
    wait_frames: 0,
    last_timestamp_us: 0,
    active: false,
    complete: false,
    flow_control,
    timeout_us,
  }
}

///|
pub fn IsoTpStreamReceiver::expected_length(self : IsoTpStreamReceiver) -> Int {
  self.expected_length
}

///|
pub fn IsoTpStreamReceiver::received_length(self : IsoTpStreamReceiver) -> Int {
  self.received.length()
}

///|
pub fn IsoTpStreamReceiver::remaining(self : IsoTpStreamReceiver) -> Int {
  self.expected_length - self.received.length()
}

///|
pub fn IsoTpStreamReceiver::active(self : IsoTpStreamReceiver) -> Bool {
  self.active
}

///|
pub fn IsoTpStreamReceiver::complete(self : IsoTpStreamReceiver) -> Bool {
  self.complete
}

///|
pub fn IsoTpStreamReceiver::next_sequence(self : IsoTpStreamReceiver) -> Byte {
  self.next_sequence
}

///|
pub fn IsoTpStreamReceiver::last_timestamp_us(
  self : IsoTpStreamReceiver,
) -> UInt64 {
  self.last_timestamp_us
}

///|
pub fn IsoTpStreamReceiver::payload(self : IsoTpStreamReceiver) -> Array[Byte] {
  self.received.copy()
}

///|
/// Feed a complete ISO-TP payload received from the bus.
pub fn IsoTpStreamReceiver::feed(
  self : IsoTpStreamReceiver,
  payload : Array[Byte],
  timestamp_us : UInt64,
) -> IsoTpReceiverResult {
  if payload.is_empty() {
    IsoTpRxError("empty ISO-TP payload")
  } else {
    let pci = payload[0].to_int()
    let kind = pci & 0xF0
    self.last_timestamp_us = timestamp_us
    if kind == 0x00 {
      let length = pci & 0x0F
      if length > payload.length() - 1 {
        IsoTpRxError("single-frame length exceeds payload")
      } else {
        self.reset()
        self.expected_length = length
        self.received = payload[1:1 + length].to_owned()
        self.complete = true
        IsoTpRxComplete(self.received.copy())
      }
    } else if kind == 0x10 {
      if payload.length() < 2 {
        IsoTpRxError("first frame has no length byte")
      } else {
        let length = ((pci & 0x0F) << 8) | payload[1].to_int()
        if length <= 7 || length > self.flow_control.max_payload() {
          IsoTpRxError("first-frame length is outside receiver bounds")
        } else {
          self.reset()
          self.expected_length = length
          let take = if payload.length() - 2 > length {
            length
          } else {
            payload.length() - 2
          }
          self.received.append(payload[2:2 + take].to_owned())
          self.active = true
          self.complete = false
          self.next_sequence = 1
          self.block_received = 0
          IsoTpRxFlowControl(self.flow_control.to_payload())
        }
      }
    } else if kind == 0x20 {
      self.feed_consecutive(pci & 0x0F, payload, timestamp_us)
    } else if kind == 0x30 {
      IsoTpRxIgnored
    } else {
      IsoTpRxError("unknown ISO-TP PCI type")
    }
  }
}

///|
fn IsoTpStreamReceiver::feed_consecutive(
  self : IsoTpStreamReceiver,
  sequence : Int,
  payload : Array[Byte],
  timestamp_us : UInt64,
) -> IsoTpReceiverResult {
  if !self.active {
    IsoTpRxError("consecutive frame without first frame")
  } else if sequence != self.next_sequence.to_int() {
    self.reset()
    IsoTpRxError("unexpected consecutive-frame sequence")
  } else {
    let take = if payload.length() - 1 > self.remaining() {
      self.remaining()
    } else {
      payload.length() - 1
    }
    self.received.append(payload[1:1 + take].to_owned())
    self.last_timestamp_us = timestamp_us
    self.next_sequence = ((self.next_sequence.to_int() + 1) & 0x0F).to_byte()
    self.block_received += 1
    if self.received.length() >= self.expected_length {
      self.active = false
      self.complete = true
      IsoTpRxComplete(self.received[:self.expected_length].to_owned())
    } else if self.flow_control.block_size() > 0 &&
      self.block_received >= self.flow_control.block_size() {
      self.block_received = 0
      IsoTpRxFlowControl(self.flow_control.to_payload())
    } else {
      IsoTpRxProgress(self.received.length())
    }
  }
}

///|
/// Return whether a receiver transfer has timed out.
pub fn IsoTpStreamReceiver::timed_out(
  self : IsoTpStreamReceiver,
  timestamp_us : UInt64,
) -> Bool {
  self.active && timestamp_us > self.last_timestamp_us + self.timeout_us
}

///|
/// Reset a receiver to accept a new transfer.
pub fn IsoTpStreamReceiver::reset(self : IsoTpStreamReceiver) -> Unit {
  self.expected_length = 0
  self.received.clear()
  self.next_sequence = 1
  self.block_received = 0
  self.wait_frames = 0
  self.active = false
  self.complete = false
}

///|
/// Take the completed payload and reset the receiver.
pub fn IsoTpStreamReceiver::take_payload(
  self : IsoTpStreamReceiver,
) -> Array[Byte]? {
  if self.complete {
    let result = self.received[:self.expected_length].to_owned()
    self.reset()
    Some(result)
  } else {
    None
  }
}

///|
/// A transport exchange combining a transmitter and receiver.
pub struct IsoTpSession {
  mut transmitter : IsoTpTransmitter?
  receiver : IsoTpStreamReceiver
  mut sent_frames : Int
  mut received_frames : Int
  mut dropped_frames : Int
}

///|
pub fn new_isotp_session(
  flow_control : IsoTpFlowControlConfig,
  timeout_us : UInt64,
) -> IsoTpSession {
  {
    transmitter: None,
    receiver: new_isotp_stream_receiver(flow_control, timeout_us),
    sent_frames: 0,
    received_frames: 0,
    dropped_frames: 0,
  }
}

///|
pub fn IsoTpSession::start_transmit(
  self : IsoTpSession,
  payload : Array[Byte],
  timestamp_us : UInt64,
) -> Unit {
  self.transmitter = Some(
    new_isotp_transmitter(payload, self.receiver.flow_control, timestamp_us),
  )
}

///|
pub fn IsoTpSession::next_transmit(
  self : IsoTpSession,
  timestamp_us : UInt64,
) -> Array[Byte]? {
  match self.transmitter {
    Some(transmitter) => {
      let result = transmitter.next_payload(timestamp_us)
      match result {
        Some(_) => self.sent_frames += 1
        None => ()
      }
      result
    }
    None => None
  }
}

///|
pub fn IsoTpSession::accept_flow_control(
  self : IsoTpSession,
  payload : Array[Byte],
  timestamp_us : UInt64,
) -> Bool {
  match self.transmitter {
    Some(transmitter) => transmitter.accept_flow_control(payload, timestamp_us)
    None => false
  }
}

///|
pub fn IsoTpSession::receive(
  self : IsoTpSession,
  payload : Array[Byte],
  timestamp_us : UInt64,
) -> IsoTpReceiverResult {
  let result = self.receiver.feed(payload, timestamp_us)
  self.received_frames += 1
  match result {
    IsoTpRxError(_) => self.dropped_frames += 1
    _ => ()
  }
  result
}

///|
pub fn IsoTpSession::transmitter(self : IsoTpSession) -> IsoTpTransmitter? {
  self.transmitter
}

///|
pub fn IsoTpSession::receiver(self : IsoTpSession) -> IsoTpStreamReceiver {
  self.receiver
}

///|
pub fn IsoTpSession::sent_frames(self : IsoTpSession) -> Int {
  self.sent_frames
}

///|
pub fn IsoTpSession::received_frames(self : IsoTpSession) -> Int {
  self.received_frames
}

///|
pub fn IsoTpSession::dropped_frames(self : IsoTpSession) -> Int {
  self.dropped_frames
}

///|
/// An ISO-TP channel identity used by a transport router.
pub struct IsoTpChannel {
  source_id : UInt
  target_id : UInt
  extended : Bool
  addressing : IsoTpSessionAddressing
  flow_control : IsoTpFlowControlConfig
}

///|
pub fn isotp_channel(
  source_id : UInt,
  target_id : UInt,
  extended? : Bool = false,
  addressing? : IsoTpSessionAddressing = IsoTpNormalAddressing,
  flow_control? : IsoTpFlowControlConfig = isotp_flow_control_config(
    8, 0, 3, 4095,
  ),
) -> IsoTpChannel {
  { source_id, target_id, extended, addressing, flow_control }
}

///|
pub fn IsoTpChannel::source_id(self : IsoTpChannel) -> UInt {
  self.source_id
}

///|
pub fn IsoTpChannel::target_id(self : IsoTpChannel) -> UInt {
  self.target_id
}

///|
pub fn IsoTpChannel::extended(self : IsoTpChannel) -> Bool {
  self.extended
}

///|
pub fn IsoTpChannel::addressing(self : IsoTpChannel) -> IsoTpSessionAddressing {
  self.addressing
}

///|
pub fn IsoTpChannel::flow_control(
  self : IsoTpChannel,
) -> IsoTpFlowControlConfig {
  self.flow_control
}

///|
/// Return whether a frame identifier belongs to a channel.
pub fn IsoTpChannel::accepts(self : IsoTpChannel, frame : Frame) -> Bool {
  frame.id() == self.target_id || frame.id() == self.source_id
}

///|
/// Build a CAN frame carrying an ISO-TP payload.
pub fn IsoTpChannel::frame(
  self : IsoTpChannel,
  payload : Array[Byte],
  transmit : Bool,
) -> Frame raise FrameError {
  let id = if transmit { self.source_id } else { self.target_id }
  data_frame(id, payload, extended=self.extended)
}

///|
/// A bounded transport router for multiple diagnostic channels.
pub struct IsoTpRouter {
  channels : Array[IsoTpChannel]
  mut accepted : Int
  mut rejected : Int
}

///|
pub fn new_isotp_router() -> IsoTpRouter {
  { channels: [], accepted: 0, rejected: 0 }
}

///|
pub fn IsoTpRouter::add_channel(
  self : IsoTpRouter,
  channel : IsoTpChannel,
) -> Bool {
  if self.find_channel(channel.source_id(), channel.target_id()) is Some(_) {
    false
  } else {
    self.channels.push(channel)
    true
  }
}

///|
pub fn IsoTpRouter::remove_channel(
  self : IsoTpRouter,
  source_id : UInt,
  target_id : UInt,
) -> Bool {
  match self.find_channel_index(source_id, target_id) {
    Some(index) => {
      ignore(self.channels.remove(index))
      true
    }
    None => false
  }
}

///|
pub fn IsoTpRouter::find_channel(
  self : IsoTpRouter,
  source_id : UInt,
  target_id : UInt,
) -> IsoTpChannel? {
  match self.find_channel_index(source_id, target_id) {
    Some(index) => Some(self.channels[index])
    None => None
  }
}

///|
pub fn IsoTpRouter::channels(self : IsoTpRouter) -> Array[IsoTpChannel] {
  self.channels.copy()
}

///|
pub fn IsoTpRouter::accepted(self : IsoTpRouter) -> Int {
  self.accepted
}

///|
pub fn IsoTpRouter::rejected(self : IsoTpRouter) -> Int {
  self.rejected
}

///|
pub fn IsoTpRouter::route(self : IsoTpRouter, frame : Frame) -> IsoTpChannel? {
  for channel in self.channels {
    if channel.accepts(frame) {
      self.accepted += 1
      return Some(channel)
    }
  }
  self.rejected += 1
  None
}

///|
fn IsoTpRouter::find_channel_index(
  self : IsoTpRouter,
  source_id : UInt,
  target_id : UInt,
) -> Int? {
  for index, channel in self.channels {
    if channel.source_id() == source_id && channel.target_id() == target_id {
      return Some(index)
    }
  }
  None
}

///|
/// Return a stable transfer summary for diagnostics.
pub fn isotp_transfer_summary(
  transmitter : IsoTpTransmitter,
  receiver : IsoTpStreamReceiver,
) -> String {
  "tx_offset=\{transmitter.offset()} rx_received=\{receiver.received_length()} rx_expected=\{receiver.expected_length()} tx_complete=\{transmitter.is_complete()} rx_complete=\{receiver.complete()}"
}
