///|
/// Direction of a J1939 transport-protocol session.
pub enum J1939TransportDirection {
  J1939TransportTransmit
  J1939TransportReceive
}

///|
pub fn j1939_transport_direction_variants() -> Array[J1939TransportDirection] {
  [J1939TransportTransmit, J1939TransportReceive]
}

///|
/// State of a J1939 BAM or TP.DT transfer.
pub enum J1939TransportState {
  J1939TransportIdle
  J1939TransportAnnounced
  J1939TransportTransferring
  J1939TransportComplete
  J1939TransportTimedOut
  J1939TransportAborted
}

///|
pub fn j1939_transport_state_variants() -> Array[J1939TransportState] {
  [
    J1939TransportIdle,
    J1939TransportAnnounced,
    J1939TransportTransferring,
    J1939TransportComplete,
    J1939TransportTimedOut,
    J1939TransportAborted,
  ]
}

///|
/// A stateful J1939 transport-protocol transfer.
pub struct J1939TransportSession {
  pgn : UInt
  direction : J1939TransportDirection
  mut total_length : Int
  mut packet_count : Int
  mut payload : Array[Byte]
  mut next_sequence : Int
  mut state : J1939TransportState
  mut last_timestamp_us : UInt64
  timeout_us : UInt64
  mut retries : Int
}

///|
pub fn new_j1939_transport_session(
  pgn : UInt,
  direction : J1939TransportDirection,
  timeout_us? : UInt64 = 750_000,
) -> J1939TransportSession {
  {
    pgn,
    direction,
    total_length: 0,
    packet_count: 0,
    payload: [],
    next_sequence: 1,
    state: J1939TransportIdle,
    last_timestamp_us: 0,
    timeout_us,
    retries: 0,
  }
}

///|
pub fn J1939TransportSession::pgn(self : J1939TransportSession) -> UInt {
  self.pgn
}

///|
pub fn J1939TransportSession::direction(
  self : J1939TransportSession,
) -> J1939TransportDirection {
  self.direction
}

///|
pub fn J1939TransportSession::total_length(self : J1939TransportSession) -> Int {
  self.total_length
}

///|
pub fn J1939TransportSession::packet_count(self : J1939TransportSession) -> Int {
  self.packet_count
}

///|
pub fn J1939TransportSession::received_length(
  self : J1939TransportSession,
) -> Int {
  self.payload.length()
}

///|
pub fn J1939TransportSession::next_sequence(
  self : J1939TransportSession,
) -> Int {
  self.next_sequence
}

///|
pub fn J1939TransportSession::state(
  self : J1939TransportSession,
) -> J1939TransportState {
  self.state
}

///|
pub fn J1939TransportSession::last_timestamp_us(
  self : J1939TransportSession,
) -> UInt64 {
  self.last_timestamp_us
}

///|
pub fn J1939TransportSession::retries(self : J1939TransportSession) -> Int {
  self.retries
}

///|
pub fn J1939TransportSession::payload(
  self : J1939TransportSession,
) -> Array[Byte] {
  self.payload.copy()
}

///|
pub fn J1939TransportSession::complete(self : J1939TransportSession) -> Bool {
  self.state is J1939TransportComplete
}

///|
/// Start a BAM transfer and generate the announcement and data packets.
pub fn J1939TransportSession::start_transmit(
  self : J1939TransportSession,
  payload : Array[Byte],
  timestamp_us : UInt64,
) -> Array[Array[Byte]] raise J1939Error {
  if self.direction is J1939TransportReceive ||
    payload.is_empty() ||
    payload.length() > 1785 {
    raise TransferTooLarge
  }
  if self.pgn > 0x3FFFF {
    raise InvalidPgn
  }
  self.total_length = payload.length()
  self.packet_count = (payload.length() + 6) / 7
  self.payload = payload.copy()
  self.next_sequence = 1
  self.state = J1939TransportAnnounced
  self.last_timestamp_us = timestamp_us
  self.next_packets()
}

///|
/// Accept a BAM announcement for a receive session.
pub fn J1939TransportSession::accept_announcement(
  self : J1939TransportSession,
  announcement : Array[Byte],
  timestamp_us : UInt64,
) -> Bool {
  match j1939_parse_bam(announcement) {
    Some((length, count, pgn)) =>
      if self.direction is J1939TransportReceive &&
        pgn == self.pgn &&
        length <= 1785 {
        self.total_length = length
        self.packet_count = count
        self.payload.clear()
        self.next_sequence = 1
        self.state = J1939TransportTransferring
        self.last_timestamp_us = timestamp_us
        true
      } else {
        false
      }
    None => false
  }
}

///|
/// Accept one TP.DT packet and return whether it advanced the transfer.
pub fn J1939TransportSession::accept_packet(
  self : J1939TransportSession,
  packet : Array[Byte],
  timestamp_us : UInt64,
) -> Bool {
  if self.state is J1939TransportComplete ||
    self.state is J1939TransportTimedOut ||
    packet.is_empty() {
    false
  } else if packet[0].to_int() != self.next_sequence {
    self.state = J1939TransportAborted
    self.retries += 1
    false
  } else {
    self.state = J1939TransportTransferring
    for byte in packet[1:] {
      if self.payload.length() < self.total_length {
        self.payload.push(byte)
      }
    }
    self.next_sequence += 1
    self.last_timestamp_us = timestamp_us
    if self.payload.length() >= self.total_length {
      self.payload = self.payload[:self.total_length].to_owned()
      self.state = J1939TransportComplete
    }
    true
  }
}

///|
pub fn J1939TransportSession::timed_out(
  self : J1939TransportSession,
  timestamp_us : UInt64,
) -> Bool {
  if self.state is J1939TransportTransferring ||
    self.state is J1939TransportAnnounced {
    if timestamp_us > self.last_timestamp_us + self.timeout_us {
      self.state = J1939TransportTimedOut
      true
    } else {
      false
    }
  } else {
    false
  }
}

///|
pub fn J1939TransportSession::take_payload(
  self : J1939TransportSession,
) -> Array[Byte]? {
  if self.complete() {
    Some(self.payload.copy())
  } else {
    None
  }
}

///|
fn J1939TransportSession::next_packets(
  self : J1939TransportSession,
) -> Array[Array[Byte]] {
  let result : Array[Array[Byte]] = []
  let announcement : Array[Byte] = [
    0x20,
    self.total_length.to_byte(),
    (self.total_length >> 8).to_byte(),
    self.packet_count.to_byte(),
    0xFF,
    self.pgn.to_byte(),
    (self.pgn >> 8).to_byte(),
    (self.pgn >> 16).to_byte(),
  ]
  result.push(announcement)
  let mut offset = 0
  for sequence in 1..<=self.packet_count {
    let count = if self.total_length - offset > 7 {
      7
    } else {
      self.total_length - offset
    }
    let packet = [sequence.to_byte()] +
      self.payload[offset:offset + count].to_owned()
    result.push(packet + Array::make(8 - packet.length(), 0xFF))
    offset += count
  }
  self.state = J1939TransportComplete
  result
}

///|
/// A J1939 address-claim record.
pub struct J1939AddressClaim {
  source_address : Byte
  name : UInt64
  manufacturer : UInt
  function : Byte
  instance : Byte
  mut last_seen_us : UInt64
  mut preferred : Bool
}

///|
pub fn j1939_address_claim(
  source_address : Byte,
  name : UInt64,
  manufacturer : UInt,
  function : Byte,
  instance : Byte,
  timestamp_us? : UInt64 = 0,
) -> J1939AddressClaim {
  {
    source_address,
    name,
    manufacturer,
    function,
    instance,
    last_seen_us: timestamp_us,
    preferred: false,
  }
}

///|
pub fn J1939AddressClaim::source_address(self : J1939AddressClaim) -> Byte {
  self.source_address
}

///|
pub fn J1939AddressClaim::name(self : J1939AddressClaim) -> UInt64 {
  self.name
}

///|
pub fn J1939AddressClaim::manufacturer(self : J1939AddressClaim) -> UInt {
  self.manufacturer
}

///|
pub fn J1939AddressClaim::function(self : J1939AddressClaim) -> Byte {
  self.function
}

///|
pub fn J1939AddressClaim::instance(self : J1939AddressClaim) -> Byte {
  self.instance
}

///|
pub fn J1939AddressClaim::last_seen_us(self : J1939AddressClaim) -> UInt64 {
  self.last_seen_us
}

///|
pub fn J1939AddressClaim::preferred(self : J1939AddressClaim) -> Bool {
  self.preferred
}

///|
pub fn J1939AddressClaim::refresh(
  self : J1939AddressClaim,
  timestamp_us : UInt64,
) -> Unit {
  self.last_seen_us = timestamp_us
}

///|
pub fn J1939AddressClaim::set_preferred(
  self : J1939AddressClaim,
  preferred : Bool,
) -> Unit {
  self.preferred = preferred
}

///|
pub fn J1939AddressClaim::wire_name(self : J1939AddressClaim) -> Array[Byte] {
  [
    self.name.to_byte(),
    (self.name >> 8).to_byte(),
    (self.name >> 16).to_byte(),
    (self.name >> 24).to_byte(),
    (self.name >> 32).to_byte(),
    (self.name >> 40).to_byte(),
    (self.name >> 48).to_byte(),
    (self.name >> 56).to_byte(),
  ]
}

///|
/// Address-claim table with deterministic conflict resolution.
pub struct J1939AddressManager {
  claims : Array[J1939AddressClaim]
  mut conflicts : Int
  mut changes : Int
  timeout_us : UInt64
}

///|
pub fn new_j1939_address_manager(
  timeout_us? : UInt64 = 2_500_000,
) -> J1939AddressManager {
  { claims: [], conflicts: 0, changes: 0, timeout_us }
}

///|
pub fn J1939AddressManager::claim(
  self : J1939AddressManager,
  claim : J1939AddressClaim,
) -> Bool {
  match self.find_index(claim.source_address()) {
    Some(index) =>
      if claim.name() < self.claims[index].name() {
        self.claims[index] = claim
        self.changes += 1
        true
      } else {
        self.conflicts += 1
        false
      }
    None => {
      self.claims.push(claim)
      self.changes += 1
      true
    }
  }
}

///|
pub fn J1939AddressManager::refresh(
  self : J1939AddressManager,
  source_address : Byte,
  timestamp_us : UInt64,
) -> Bool {
  match self.find_index(source_address) {
    Some(index) => {
      self.claims[index].refresh(timestamp_us)
      true
    }
    None => false
  }
}

///|
pub fn J1939AddressManager::expire(
  self : J1939AddressManager,
  timestamp_us : UInt64,
) -> Int {
  let mut removed = 0
  let mut index = self.claims.length() - 1
  while index >= 0 && !self.claims.is_empty() {
    if timestamp_us > self.claims[index].last_seen_us() + self.timeout_us {
      ignore(self.claims.remove(index))
      removed += 1
    }
    index -= 1
  }
  removed
}

///|
pub fn J1939AddressManager::find(
  self : J1939AddressManager,
  source_address : Byte,
) -> J1939AddressClaim? {
  match self.find_index(source_address) {
    Some(index) => Some(self.claims[index])
    None => None
  }
}

///|
pub fn J1939AddressManager::claims(
  self : J1939AddressManager,
) -> Array[J1939AddressClaim] {
  self.claims.copy()
}

///|
pub fn J1939AddressManager::conflicts(self : J1939AddressManager) -> Int {
  self.conflicts
}

///|
pub fn J1939AddressManager::changes(self : J1939AddressManager) -> Int {
  self.changes
}

///|
fn J1939AddressManager::find_index(
  self : J1939AddressManager,
  source_address : Byte,
) -> Int? {
  for index, claim in self.claims {
    if claim.source_address() == source_address {
      return Some(index)
    }
  }
  None
}

///|
/// A scale and offset definition for a J1939 SPN.
pub struct J1939SpnDefinition {
  spn : UInt
  name : String
  start_bit : Int
  length : Int
  factor : Double
  offset : Double
  minimum : Double
  maximum : Double
  unit : String
}

///|
pub fn j1939_spn(
  spn : UInt,
  name : String,
  start_bit : Int,
  length : Int,
  factor? : Double = 1.0,
  offset? : Double = 0.0,
  minimum? : Double = 0.0,
  maximum? : Double = 0.0,
  unit? : String = "",
) -> J1939SpnDefinition {
  { spn, name, start_bit, length, factor, offset, minimum, maximum, unit }
}

///|
pub fn J1939SpnDefinition::spn(self : J1939SpnDefinition) -> UInt {
  self.spn
}

///|
pub fn J1939SpnDefinition::name(self : J1939SpnDefinition) -> String {
  self.name
}

///|
pub fn J1939SpnDefinition::start_bit(self : J1939SpnDefinition) -> Int {
  self.start_bit
}

///|
pub fn J1939SpnDefinition::length(self : J1939SpnDefinition) -> Int {
  self.length
}

///|
pub fn J1939SpnDefinition::factor(self : J1939SpnDefinition) -> Double {
  self.factor
}

///|
pub fn J1939SpnDefinition::offset(self : J1939SpnDefinition) -> Double {
  self.offset
}

///|
pub fn J1939SpnDefinition::unit(self : J1939SpnDefinition) -> String {
  self.unit
}

///|
pub fn J1939SpnDefinition::decode(
  self : J1939SpnDefinition,
  data : Array[Byte],
) -> Double {
  let mut raw : UInt = 0
  for bit in 0..<self.length {
    let absolute = self.start_bit + bit
    let byte_index = absolute / 8
    let bit_index = absolute % 8
    if byte_index < data.length() &&
      ((data[byte_index].to_uint() >> bit_index) & 1) == 1 {
      raw = raw | (1 << bit)
    }
  }
  raw.to_double() * self.factor + self.offset
}

///|
pub fn J1939SpnDefinition::encode(
  self : J1939SpnDefinition,
  data : Array[Byte],
  value : Double,
) -> Array[Byte] {
  let raw = ((value - self.offset) / self.factor).to_int().reinterpret_as_uint()
  let result = data.copy()
  while result.length() < (self.start_bit + self.length + 7) / 8 {
    result.push(0)
  }
  for bit in 0..<self.length {
    let absolute = self.start_bit + bit
    let byte_index = absolute / 8
    let bit_index = absolute % 8
    let mask = (1 << bit_index).to_byte()
    if ((raw >> bit) & 1) == 1 {
      result[byte_index] = result[byte_index] | mask
    } else {
      result[byte_index] = result[byte_index] & (0xFF ^ mask.to_int()).to_byte()
    }
  }
  result
}

///|
/// Decode multiple configured SPNs from a PGN payload.
pub fn j1939_decode_spns(
  definitions : Array[J1939SpnDefinition],
  data : Array[Byte],
) -> Array[(UInt, Double)] {
  let result : Array[(UInt, Double)] = []
  for item in definitions {
    result.push((item.spn(), item.decode(data)))
  }
  result
}
