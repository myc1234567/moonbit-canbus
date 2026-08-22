///|
/// Application payload profile used by a safety or control message.
pub(all) enum PayloadCodecProfile {
  PayloadCodecPlain
  PayloadCodecCounterCrc
  PayloadCodecCounterChecksum
  PayloadCodecAliveAndCrc
}

///|
pub fn payload_codec_profile_variants() -> Array[PayloadCodecProfile] {
  [
    PayloadCodecPlain,
    PayloadCodecCounterCrc,
    PayloadCodecCounterChecksum,
    PayloadCodecAliveAndCrc,
  ]
}

///|
/// Result classification from a payload codec operation.
pub(all) enum PayloadCodecStatus {
  PayloadCodecAccepted
  PayloadCodecBadLength
  PayloadCodecBadCounter
  PayloadCodecBadCrc
  PayloadCodecBadChecksum
}

///|
pub fn payload_codec_status_variants() -> Array[PayloadCodecStatus] {
  [
    PayloadCodecAccepted,
    PayloadCodecBadLength,
    PayloadCodecBadCounter,
    PayloadCodecBadCrc,
    PayloadCodecBadChecksum,
  ]
}

///|
pub fn payload_codec_status_text(status : PayloadCodecStatus) -> String {
  match status {
    PayloadCodecAccepted => "accepted"
    PayloadCodecBadLength => "bad-length"
    PayloadCodecBadCounter => "bad-counter"
    PayloadCodecBadCrc => "bad-crc"
    PayloadCodecBadChecksum => "bad-checksum"
  }
}

///|
/// Codec layout options for a cyclic payload.
pub struct PayloadCodecOptions {
  profile : PayloadCodecProfile
  counter_offset : Int
  counter_high_nibble : Bool
  crc_offset : Int
  checksum_offset : Int
  expected_length : Int
  counter_modulus : Int
}

///|
pub fn payload_codec_options(
  profile? : PayloadCodecProfile = PayloadCodecPlain,
  counter_offset? : Int = 0,
  counter_high_nibble? : Bool = true,
  crc_offset? : Int = -1,
  checksum_offset? : Int = -1,
  expected_length? : Int = 0,
  counter_modulus? : Int = 16,
) -> PayloadCodecOptions {
  {
    profile,
    counter_offset,
    counter_high_nibble,
    crc_offset,
    checksum_offset,
    expected_length,
    counter_modulus,
  }
}

///|
pub fn PayloadCodecOptions::profile(
  self : PayloadCodecOptions,
) -> PayloadCodecProfile {
  self.profile
}

///|
pub fn PayloadCodecOptions::counter_offset(self : PayloadCodecOptions) -> Int {
  self.counter_offset
}

///|
pub fn PayloadCodecOptions::counter_high_nibble(
  self : PayloadCodecOptions,
) -> Bool {
  self.counter_high_nibble
}

///|
pub fn PayloadCodecOptions::crc_offset(self : PayloadCodecOptions) -> Int {
  self.crc_offset
}

///|
pub fn PayloadCodecOptions::checksum_offset(self : PayloadCodecOptions) -> Int {
  self.checksum_offset
}

///|
pub fn PayloadCodecOptions::expected_length(self : PayloadCodecOptions) -> Int {
  self.expected_length
}

///|
pub fn PayloadCodecOptions::counter_modulus(self : PayloadCodecOptions) -> Int {
  self.counter_modulus
}

///|
/// A codec result includes transformed data and validation state.
pub struct PayloadCodecResult {
  status : PayloadCodecStatus
  data : Array[Byte]
  counter : Byte?
  expected_counter : Byte?
  checksum : Byte?
}

///|
pub fn PayloadCodecResult::status(
  self : PayloadCodecResult,
) -> PayloadCodecStatus {
  self.status
}

///|
pub fn PayloadCodecResult::data(self : PayloadCodecResult) -> Array[Byte] {
  self.data.copy()
}

///|
pub fn PayloadCodecResult::counter(self : PayloadCodecResult) -> Byte? {
  self.counter
}

///|
pub fn PayloadCodecResult::expected_counter(self : PayloadCodecResult) -> Byte? {
  self.expected_counter
}

///|
pub fn PayloadCodecResult::checksum(self : PayloadCodecResult) -> Byte? {
  self.checksum
}

///|
pub fn PayloadCodecResult::accepted(self : PayloadCodecResult) -> Bool {
  self.status is PayloadCodecAccepted
}

///|
pub fn PayloadCodecResult::to_text(self : PayloadCodecResult) -> String {
  "status=" +
  payload_codec_status_text(self.status) +
  " len=" +
  self.data.length().to_string()
}

///|
/// A reusable cyclic payload codec.
pub struct PayloadCodec {
  options : PayloadCodecOptions
  mut encoded : Int
  mut decoded : Int
  mut failures : Int
  mut next_counter : Byte
}

///|
pub fn new_payload_codec(
  options? : PayloadCodecOptions = payload_codec_options(),
) -> PayloadCodec {
  { options, encoded: 0, decoded: 0, failures: 0, next_counter: 0 }
}

///|
pub fn PayloadCodec::options(self : PayloadCodec) -> PayloadCodecOptions {
  self.options
}

///|
pub fn PayloadCodec::encoded(self : PayloadCodec) -> Int {
  self.encoded
}

///|
pub fn PayloadCodec::decoded(self : PayloadCodec) -> Int {
  self.decoded
}

///|
pub fn PayloadCodec::failures(self : PayloadCodec) -> Int {
  self.failures
}

///|
pub fn PayloadCodec::next_counter(self : PayloadCodec) -> Byte {
  self.next_counter
}

///|
pub fn PayloadCodec::reset(self : PayloadCodec) -> Unit {
  self.encoded = 0
  self.decoded = 0
  self.failures = 0
  self.next_counter = 0
}

///|
/// Encode a payload, setting the configured counter and integrity byte.
pub fn PayloadCodec::encode(
  self : PayloadCodec,
  data : Array[Byte],
) -> PayloadCodecResult {
  if self.options.expected_length() > 0 &&
    data.length() != self.options.expected_length() {
    self.failures += 1
    {
      status: PayloadCodecBadLength,
      data: data.copy(),
      counter: None,
      expected_counter: None,
      checksum: None,
    }
  } else {
    let result = data.copy()
    let counter = self.next_counter
    let profile = self.options.profile()
    if profile is PayloadCodecCounterCrc ||
      profile is PayloadCodecCounterChecksum ||
      profile is PayloadCodecAliveAndCrc {
      if self.options.counter_offset() >= 0 &&
        self.options.counter_offset() < result.length() {
        let position = self.options.counter_offset()
        let previous = result[position].to_int()
        let value = if self.options.counter_high_nibble() {
          (previous & 0x0F) | ((counter.to_int() & 0x0F) << 4)
        } else {
          (previous & 0xF0) | (counter.to_int() & 0x0F)
        }
        result[position] = value.to_byte()
      }
    }
    if profile is PayloadCodecCounterCrc || profile is PayloadCodecAliveAndCrc {
      self.write_crc(result)
    }
    if profile is PayloadCodecCounterChecksum {
      self.write_checksum(result)
    }
    self.next_counter = ((counter.to_int() + 1) % self.options.counter_modulus()).to_byte()
    self.encoded += 1
    {
      status: PayloadCodecAccepted,
      data: result,
      counter: Some(counter),
      expected_counter: Some(counter),
      checksum: self.read_integrity(result),
    }
  }
}

///|
/// Decode and validate a received payload against the rolling counter.
pub fn PayloadCodec::decode(
  self : PayloadCodec,
  data : Array[Byte],
  expected_counter : Byte?,
) -> PayloadCodecResult {
  if self.options.expected_length() > 0 &&
    data.length() != self.options.expected_length() {
    self.failures += 1
    {
      status: PayloadCodecBadLength,
      data: data.copy(),
      counter: None,
      expected_counter,
      checksum: None,
    }
  } else {
    let actual_counter = self.read_counter(data)
    let counter_ok = match expected_counter {
      Some(expected) =>
        match actual_counter {
          Some(actual) => counter_is_next(expected, actual)
          None => false
        }
      None =>
        match actual_counter {
          Some(_) => true
          None => false
        }
    }
    let profile = self.options.profile()
    let integrity_ok = if profile is PayloadCodecCounterCrc ||
      profile is PayloadCodecAliveAndCrc {
      self.check_crc(data)
    } else if profile is PayloadCodecCounterChecksum {
      self.check_checksum(data)
    } else {
      true
    }
    let status = if !counter_ok && actual_counter is Some(_) {
      PayloadCodecBadCounter
    } else if !integrity_ok && profile is PayloadCodecCounterChecksum {
      PayloadCodecBadChecksum
    } else if !integrity_ok {
      PayloadCodecBadCrc
    } else {
      PayloadCodecAccepted
    }
    if status is PayloadCodecAccepted {
      self.decoded += 1
    } else {
      self.failures += 1
    }
    {
      status,
      data: data.copy(),
      counter: actual_counter,
      expected_counter,
      checksum: self.read_integrity(data),
    }
  }
}

///|
fn PayloadCodec::read_counter(self : PayloadCodec, data : Array[Byte]) -> Byte? {
  if self.options.counter_offset() < 0 ||
    self.options.counter_offset() >= data.length() {
    None
  } else {
    let value = data[self.options.counter_offset()]
    Some(
      if self.options.counter_high_nibble() {
        (value.to_int() >> 4).to_byte()
      } else {
        (value.to_int() & 0x0F).to_byte()
      },
    )
  }
}

///|
fn PayloadCodec::write_crc(self : PayloadCodec, data : Array[Byte]) -> Unit {
  if self.options.crc_offset() >= 0 && self.options.crc_offset() < data.length() {
    let offset = self.options.crc_offset()
    let prefix = data[:offset].to_owned()
    data[offset] = crc8_sae_j1850(prefix)
  }
}

///|
fn PayloadCodec::write_checksum(
  self : PayloadCodec,
  data : Array[Byte],
) -> Unit {
  if self.options.checksum_offset() >= 0 &&
    self.options.checksum_offset() < data.length() {
    let offset = self.options.checksum_offset()
    let mut sum = 0
    for index, byte in data {
      if index != offset {
        sum += byte.to_int()
      }
    }
    data[offset] = (sum & 0xFF).to_byte()
  }
}

///|
fn PayloadCodec::check_crc(self : PayloadCodec, data : Array[Byte]) -> Bool {
  if self.options.crc_offset() < 0 || self.options.crc_offset() >= data.length() {
    false
  } else {
    let offset = self.options.crc_offset()
    crc8_sae_j1850(data[:offset].to_owned()) == data[offset]
  }
}

///|
fn PayloadCodec::check_checksum(
  self : PayloadCodec,
  data : Array[Byte],
) -> Bool {
  if self.options.checksum_offset() < 0 ||
    self.options.checksum_offset() >= data.length() {
    false
  } else {
    let offset = self.options.checksum_offset()
    let mut sum = 0
    for index, byte in data {
      if index != offset {
        sum += byte.to_int()
      }
    }
    (sum & 0xFF).to_byte() == data[offset]
  }
}

///|
fn PayloadCodec::read_integrity(
  self : PayloadCodec,
  data : Array[Byte],
) -> Byte? {
  if self.options.crc_offset() >= 0 && self.options.crc_offset() < data.length() {
    Some(data[self.options.crc_offset()])
  } else if self.options.checksum_offset() >= 0 &&
    self.options.checksum_offset() < data.length() {
    Some(data[self.options.checksum_offset()])
  } else {
    None
  }
}

///|
/// Pack a sequence counter and payload into a fixed-length frame payload.
pub fn payload_codec_pack_counter(
  payload : Array[Byte],
  counter : Byte,
  offset : Int,
  high_nibble : Bool,
) -> Array[Byte] raise PayloadError {
  set_counter_nibble(payload, offset, counter, high_nibble)
}

///|
/// Validate a counter sequence against a modulus.
pub fn payload_codec_counter_valid(
  previous : Byte,
  current : Byte,
  modulus : Int,
) -> Bool {
  if modulus <= 1 {
    false
  } else {
    (previous.to_int() + 1) % modulus == current.to_int()
  }
}

///|
/// Compute an additive checksum excluding one byte position.
pub fn payload_codec_checksum(data : Array[Byte], excluded : Int) -> Byte {
  let mut sum = 0
  for index, byte in data {
    if index != excluded {
      sum += byte.to_int()
    }
  }
  (sum & 0xFF).to_byte()
}

///|
/// Compute a CRC over a payload prefix.
pub fn payload_codec_crc(data : Array[Byte]) -> Byte {
  crc8_sae_j1850(data)
}

///|
/// Return whether a payload layout is internally consistent.
pub fn payload_codec_layout_valid(options : PayloadCodecOptions) -> Bool {
  options.counter_modulus() > 1 &&
  options.expected_length() >= 0 &&
  options.counter_offset() >= 0 &&
  (options.crc_offset() < 0 || options.crc_offset() < options.expected_length()) &&
  (
    options.checksum_offset() < 0 ||
    options.checksum_offset() < options.expected_length()
  )
}

///|
/// Produce a stable codec health report.
pub fn payload_codec_report(codec : PayloadCodec) -> String {
  "profile=" +
  payload_codec_profile_text(codec.options().profile()) +
  " encoded=" +
  codec.encoded().to_string() +
  " decoded=" +
  codec.decoded().to_string() +
  " failures=" +
  codec.failures().to_string()
}

///|
pub fn payload_codec_profile_text(profile : PayloadCodecProfile) -> String {
  match profile {
    PayloadCodecPlain => "plain"
    PayloadCodecCounterCrc => "counter-crc"
    PayloadCodecCounterChecksum => "counter-checksum"
    PayloadCodecAliveAndCrc => "alive-crc"
  }
}
