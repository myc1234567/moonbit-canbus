///|

///|
/// A decoded ISO-TP packet.
pub enum IsoTpPacket {
  Single(payload~ : Array[Byte])
  First(total_length~ : Int, payload~ : Array[Byte])
  Consecutive(sequence~ : Byte, payload~ : Array[Byte])
  FlowControl(status~ : Byte, block_size~ : Byte, separation_time~ : Byte)
}

///|
/// Encode a payload into ISO-TP packets carried by classic CAN frames.
pub fn isotp_segment(payload : Array[Byte]) -> Array[Array[Byte]] {
  if payload.length() <= 7 {
    return [[payload.length().to_byte()] + payload]
  }
  let packets : Array[Array[Byte]] = []
  let first_length = payload.length()
  packets.push(
    [
      (0x10 | ((first_length >> 8) & 0x0F)).to_byte(),
      (first_length & 0xFF).to_byte(),
    ] +
    payload[0:7].to_owned(),
  )
  let mut offset = 7
  let mut sequence : Byte = 1
  while offset < payload.length() {
    let count = if payload.length() - offset > 7 {
      7
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
/// Decode one ISO-TP packet.
pub fn isotp_decode(packet : Array[Byte]) -> IsoTpPacket? {
  if packet.is_empty() {
    return None
  }
  let pci = packet[0].to_int()
  let kind = pci >> 4
  if kind == 0 {
    Some(Single(payload=packet[1:1 + (pci & 0x0F)].to_owned()))
  } else if kind == 1 && packet.length() >= 2 {
    let length = ((pci & 0x0F) << 8) | packet[1].to_int()
    Some(First(total_length=length, payload=packet[2:].to_owned()))
  } else if kind == 2 {
    Some(
      Consecutive(
        sequence=(pci & 0x0F).to_byte(),
        payload=packet[1:].to_owned(),
      ),
    )
  } else if kind == 3 && packet.length() >= 3 {
    Some(
      FlowControl(
        status=(pci & 0x0F).to_byte(),
        block_size=packet[1],
        separation_time=packet[2],
      ),
    )
  } else {
    None
  }
}

///|
/// Reassemble consecutive ISO-TP packets after a first frame.
pub fn isotp_reassemble(
  first : IsoTpPacket,
  rest : Array[IsoTpPacket],
) -> Array[Byte]? {
  match first {
    First(total_length~, payload~) => {
      let result = payload.copy()
      for packet in rest {
        match packet {
          Consecutive(sequence~, payload~) => {
            ignore(sequence)
            for byte in payload {
              result.push(byte)
            }
          }
          _ => ()
        }
      }
      if result.length() >= total_length {
        Some(result[0:total_length].to_owned())
      } else {
        None
      }
    }
    _ => None
  }
}
