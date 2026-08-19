///|
/// Encode a frame's arbitration and control fields before CRC.
pub fn encode_bits(frame : Frame) -> Array[Bool] {
  let bits : Array[Bool] = []
  append_bits(bits, frame.id(), if frame.is_extended() { 29 } else { 11 })
  bits.push(frame.is_extended())
  match frame.kind() {
    Data => bits.push(false)
    Remote => bits.push(true)
    Error => bits.push(false)
  }
  append_bits(bits, frame.dlc().to_uint(), 4)
  for byte in frame.data() {
    append_bits(bits, byte.to_uint(), 8)
  }
  bits
}

///|
/// Apply CAN bit stuffing to a bit sequence.
pub fn stuff(bits : Array[Bool]) -> Array[Bool] {
  let result : Array[Bool] = []
  if bits.is_empty() {
    return result
  }
  let mut previous = bits[0]
  result.push(previous)
  let mut run = 1
  for i in 1..<bits.length() {
    let bit = bits[i]
    if bit == previous {
      run += 1
    } else {
      run = 1
    }
    if run == 5 {
      result.push(bit)
      result.push(!bit)
      previous = !bit
      run = 1
    } else {
      result.push(bit)
      previous = bit
    }
  }
  result
}

///|

///|
/// Errors produced when removing CAN bit stuffing.
pub suberror WireError {
  InvalidStuffedBit
}

///|
/// Remove CAN bit stuffing from a received bit sequence.
pub fn destuff(bits : Array[Bool]) -> Array[Bool] raise WireError {
  let result : Array[Bool] = []
  if bits.is_empty() {
    return result
  }
  let mut previous = bits[0]
  let mut run = 1
  let mut expect_stuffed = false
  result.push(previous)
  let mut i = 1
  while i < bits.length() {
    let bit = bits[i]
    if expect_stuffed {
      if bit == previous {
        raise WireError::InvalidStuffedBit
      }
      expect_stuffed = false
    } else {
      result.push(bit)
      if bit == previous {
        run += 1
      } else {
        previous = bit
        run = 1
      }
      if run > 0 && run % 5 == 0 {
        expect_stuffed = true
      }
    }
    i += 1
  }
  result
}

///|
/// Calculate the arbitration winner: the numerically lowest identifier wins.
pub fn arbitration_winner(frames : Array[Frame]) -> Frame? {
  if frames.is_empty() {
    return None
  }
  let mut winner = frames[0]
  for frame in frames[1:] {
    if frame.id() < winner.id() {
      winner = frame
    }
  }
  Some(winner)
}
