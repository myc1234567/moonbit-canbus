///|
/// Errors raised by checked ISO-TP operations.
pub suberror IsoTpError {
  InvalidFrameSize
  PayloadTooLarge
  TruncatedPacket
  InvalidFirstFrame
  UnexpectedConsecutive
  SequenceMismatch
  LengthMismatch
  UnsupportedFlowStatus
} derive(Debug)

///|
/// ISO-TP transfer parameters for classic CAN and CAN-FD.
pub struct IsoTpConfig {
  frame_bytes : Int
  block_size : Byte
  separation_time : Byte
}

///|
/// Create an ISO-TP configuration. Data capacity is normally 8 or 64 bytes.
pub fn isotp_config(
  frame_bytes? : Int = 8,
  block_size? : Byte = 0,
  separation_time? : Byte = 0,
) -> IsoTpConfig raise IsoTpError {
  if frame_bytes < 2 || frame_bytes > 64 {
    raise InvalidFrameSize
  }
  { frame_bytes, block_size, separation_time }
}

///|
pub fn IsoTpConfig::frame_bytes(self : IsoTpConfig) -> Int {
  self.frame_bytes
}

///|
pub fn IsoTpConfig::block_size(self : IsoTpConfig) -> Byte {
  self.block_size
}

///|
pub fn IsoTpConfig::separation_time(self : IsoTpConfig) -> Byte {
  self.separation_time
}

///|
/// Segment a payload while respecting frame size and the 12-bit classic length.
pub fn isotp_segment_checked(
  payload : Array[Byte],
  config : IsoTpConfig,
) -> Array[Array[Byte]] raise IsoTpError {
  if payload.length() > 4095 {
    raise PayloadTooLarge
  }
  let single_capacity = config.frame_bytes - 1
  if payload.length() <= single_capacity && payload.length() <= 15 {
    return [[payload.length().to_byte()] + payload]
  }
  let first_capacity = config.frame_bytes - 2
  if first_capacity <= 0 {
    raise InvalidFrameSize
  }
  let packets : Array[Array[Byte]] = []
  packets.push(
    [
      (0x10 | ((payload.length() >> 8) & 0x0F)).to_byte(),
      (payload.length() & 0xFF).to_byte(),
    ] +
    payload[0:first_capacity].to_owned(),
  )
  let mut offset = first_capacity
  let mut sequence : Byte = 1
  let consecutive_capacity = config.frame_bytes - 1
  while offset < payload.length() {
    let count = if payload.length() - offset > consecutive_capacity {
      consecutive_capacity
    } else {
      payload.length() - offset
    }
    packets.push(
      [(0x20 | sequence.to_int()).to_byte()] +
      payload[offset:offset + count].to_owned(),
    )
    offset += count
    sequence = ((sequence.to_int() + 1) & 0x0F).to_byte()
  }
  packets
}

///|
/// Decode a packet while enforcing its declared payload length.
pub fn isotp_decode_checked(
  packet : Array[Byte],
  config : IsoTpConfig,
) -> IsoTpPacket raise IsoTpError {
  if packet.is_empty() || packet.length() > config.frame_bytes {
    raise TruncatedPacket
  }
  let pci = packet[0].to_int()
  let kind = pci >> 4
  if kind == 0 {
    let length = pci & 0x0F
    if length > packet.length() - 1 {
      raise TruncatedPacket
    }
    Single(payload=packet[1:1 + length].to_owned())
  } else if kind == 1 {
    if packet.length() < 2 {
      raise TruncatedPacket
    }
    let length = ((pci & 0x0F) << 8) | packet[1].to_int()
    if length <= config.frame_bytes - 2 {
      raise InvalidFirstFrame
    }
    First(total_length=length, payload=packet[2:].to_owned())
  } else if kind == 2 {
    if packet.length() < 2 {
      raise TruncatedPacket
    }
    Consecutive(sequence=(pci & 0x0F).to_byte(), payload=packet[1:].to_owned())
  } else if kind == 3 {
    if packet.length() < 3 {
      raise TruncatedPacket
    }
    let status = (pci & 0x0F).to_byte()
    if status > 2 {
      raise UnsupportedFlowStatus
    }
    FlowControl(status~, block_size=packet[1], separation_time=packet[2])
  } else {
    raise TruncatedPacket
  }
}

///|
/// Reassemble a complete ISO-TP transfer and verify sequence numbers.
pub fn isotp_reassemble_checked(
  packets : Array[IsoTpPacket],
) -> Array[Byte] raise IsoTpError {
  if packets.is_empty() {
    raise LengthMismatch
  }
  match packets[0] {
    Single(payload~) => {
      if packets.length() != 1 {
        raise LengthMismatch
      }
      payload
    }
    First(total_length~, payload~) => {
      let result = payload.copy()
      let mut expected : Byte = 1
      for packet in packets[1:] {
        match packet {
          Consecutive(sequence~, payload~) => {
            if sequence != expected {
              raise SequenceMismatch
            }
            for byte in payload {
              result.push(byte)
            }
            expected = ((expected.to_int() + 1) & 0x0F).to_byte()
          }
          _ => raise UnexpectedConsecutive
        }
      }
      if result.length() != total_length {
        raise LengthMismatch
      }
      result
    }
    _ => raise UnexpectedConsecutive
  }
}

///|
/// The state of an incremental receiver.
pub enum IsoTpStatus {
  Waiting(received~ : Int, total~ : Int)
  Complete(payload~ : Array[Byte])
}

///|
/// An incremental ISO-TP receiver for a single outstanding transfer.
pub struct IsoTpReceiver {
  config : IsoTpConfig
  mut total_length : Int
  payload : Array[Byte]
  mut next_sequence : Byte
  mut block_count : Int
}

///|
pub fn new_isotp_receiver(config : IsoTpConfig) -> IsoTpReceiver {
  { config, total_length: 0, payload: [], next_sequence: 1, block_count: 0 }
}

///|
/// Clear the current transfer.
pub fn IsoTpReceiver::reset(self : IsoTpReceiver) -> Unit {
  self.total_length = 0
  self.payload.clear()
  self.next_sequence = 1
  self.block_count = 0
}

///|
/// Feed one decoded packet into the receiver.
pub fn IsoTpReceiver::push(
  self : IsoTpReceiver,
  packet : IsoTpPacket,
) -> IsoTpStatus raise IsoTpError {
  match packet {
    Single(payload~) => {
      self.reset()
      Complete(payload~)
    }
    First(total_length~, payload~) => {
      if total_length <= 0 || total_length <= payload.length() {
        raise InvalidFirstFrame
      }
      self.reset()
      self.total_length = total_length
      self.payload.append(payload[:])
      Waiting(received=self.payload.length(), total=total_length)
    }
    Consecutive(sequence~, payload~) => {
      if self.total_length == 0 {
        raise UnexpectedConsecutive
      }
      if sequence != self.next_sequence {
        raise SequenceMismatch
      }
      self.next_sequence = ((sequence.to_int() + 1) & 0x0F).to_byte()
      self.block_count += 1
      for byte in payload {
        self.payload.push(byte)
      }
      if self.payload.length() > self.total_length {
        raise LengthMismatch
      }
      if self.payload.length() == self.total_length {
        let completed = self.payload.copy()
        self.reset()
        Complete(payload=completed)
      } else {
        Waiting(received=self.payload.length(), total=self.total_length)
      }
    }
    FlowControl(status~, ..) => {
      ignore(status)
      raise UnexpectedConsecutive
    }
  }
}

///|
/// Return a flow-control packet for this receiver's configured limits.
pub fn IsoTpReceiver::flow_control(self : IsoTpReceiver) -> Array[Byte] {
  [0x30, self.config.block_size, self.config.separation_time]
}

///|
/// Wrap ISO-TP packets in CAN or CAN-FD data frames.
pub fn isotp_frames(
  tx_id : UInt,
  payload : Array[Byte],
  config : IsoTpConfig,
  extended? : Bool = false,
) -> Array[Frame] raise IsoTpError {
  let result : Array[Frame] = []
  for packet in isotp_segment_checked(payload, config) {
    let frame = if config.frame_bytes > 8 {
      fd_frame(tx_id, packet, extended~) catch {
        _ => raise InvalidFrameSize
      }
    } else {
      data_frame(tx_id, packet, extended~) catch {
        _ => raise InvalidFrameSize
      }
    }
    result.push(frame)
  }
  result
}

///|
/// Decode and reassemble a sequence of CAN data frames.
pub fn isotp_reassemble_frames(
  frames : Array[Frame],
  config : IsoTpConfig,
) -> Array[Byte] raise IsoTpError {
  let packets : Array[IsoTpPacket] = []
  for frame in frames {
    packets.push(isotp_decode_checked(frame.data(), config))
  }
  isotp_reassemble_checked(packets)
}
