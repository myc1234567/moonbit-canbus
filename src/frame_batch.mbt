///|
/// Errors raised by batch processing and binary archive helpers.
pub suberror BatchError {
  EmptyBatch
  BatchTooLarge
  InvalidRecord
  ChecksumMismatch
} derive(Debug)

///|
/// A validated batch of frames with a caller-provided sequence number.
pub struct FrameBatch {
  sequence : UInt
  frames : Array[Frame]
}

///|
pub fn frame_batch(
  sequence : UInt,
  frames : Array[Frame],
) -> FrameBatch raise BatchError {
  if frames.is_empty() {
    raise EmptyBatch
  }
  if frames.length() > 255 {
    raise BatchTooLarge
  }
  for frame in frames {
    if !frame_is_valid(frame) {
      raise InvalidRecord
    }
  }
  { sequence, frames: frames.copy() }
}

///|
pub fn FrameBatch::sequence(self : FrameBatch) -> UInt {
  self.sequence
}

///|
pub fn FrameBatch::frames(self : FrameBatch) -> Array[Frame] {
  self.frames.copy()
}

///|
pub fn FrameBatch::length(self : FrameBatch) -> Int {
  self.frames.length()
}

///|
/// Return the sum of payload bytes in the batch.
pub fn FrameBatch::payload_bytes(self : FrameBatch) -> Int {
  self.frames.fold(init=0, (total, frame) => total + frame.data().length())
}

///|
/// Return a non-cryptographic checksum suitable for corruption detection.
pub fn FrameBatch::checksum(self : FrameBatch) -> Byte {
  let mut checksum : Byte = 0
  checksum = checksum ^ self.sequence.to_byte()
  for frame in self.frames {
    for byte in encode_frame(frame) {
      checksum = checksum ^ byte
      checksum = (checksum << 1) | (checksum >> 7)
    }
  }
  checksum
}

///|
/// Encode a batch as a length-prefixed binary archive.
pub fn FrameBatch::encode(self : FrameBatch) -> Array[Byte] {
  let result : Array[Byte] = [
    1,
    self.sequence.to_byte(),
    self.frames.length().to_byte(),
  ]
  for frame in self.frames {
    let encoded = encode_frame(frame)
    result.push(encoded.length().to_byte())
    result.append(encoded[:])
  }
  result.push(self.checksum())
  result
}

///|
/// Decode a batch archive and check its checksum.
pub fn decode_frame_batch(bytes : Array[Byte]) -> FrameBatch raise BatchError {
  if bytes.length() < 4 || bytes[0] != 1 {
    raise InvalidRecord
  }
  let sequence = bytes[1].to_uint()
  let count = bytes[2].to_int()
  let mut offset = 3
  let frames : Array[Frame] = []
  for _ in 0..<count {
    if offset >= bytes.length() {
      raise InvalidRecord
    }
    let length = bytes[offset].to_int()
    offset += 1
    if offset + length > bytes.length() - 1 {
      raise InvalidRecord
    }
    let frame = decode_frame(bytes[offset:offset + length].to_owned()) catch {
      _ => raise InvalidRecord
    }
    frames.push(frame)
    offset += length
  }
  if offset != bytes.length() - 1 {
    raise InvalidRecord
  }
  let batch = frame_batch(sequence, frames)
  if batch.checksum() != bytes[offset] {
    raise ChecksumMismatch
  }
  batch
}

///|
/// Partition frames into batches with at most `size` members.
pub fn batch_frames(
  frames : Array[Frame],
  size : Int,
) -> Array[FrameBatch] raise BatchError {
  if size <= 0 || size > 255 {
    raise BatchTooLarge
  }
  let result : Array[FrameBatch] = []
  let mut offset = 0
  let mut sequence : UInt = 0
  while offset < frames.length() {
    let end = if offset + size < frames.length() {
      offset + size
    } else {
      frames.length()
    }
    result.push(frame_batch(sequence, frames[offset:end].to_owned()))
    sequence += 1
    offset = end
  }
  result
}
