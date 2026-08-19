///|
/// Errors raised while encoding or decoding diagnostic trouble codes.
pub suberror DtcCodecError {
  InvalidCode
  InvalidPayload
  InvalidRecordLength
  CapacityExceeded
} derive(Debug)

///|
/// A normalized three-byte diagnostic trouble code.
pub struct DtcRecord {
  code : UInt
  status : Byte
  occurrence : UInt
  snapshot : Array[Byte]
}

///|
/// A parsed ReadDTCInformation response.
pub struct DtcReport {
  subfunction : Byte
  status_availability_mask : Byte
  records : Array[DtcRecord]
}

///|
/// Construct a report for a positive ReadDTCInformation response.
pub fn new_dtc_report(
  subfunction : Byte,
  status_availability_mask : Byte,
  records : Array[DtcRecord],
) -> DtcReport {
  { subfunction, status_availability_mask, records: records.copy() }
}

///|
/// Create a DTC record with an optional occurrence counter and snapshot.
pub fn dtc_record(
  code : UInt,
  status : Byte,
  occurrence? : UInt = 1,
  snapshot? : Array[Byte] = [],
) -> DtcRecord raise DtcCodecError {
  if code > 0xFFFFFF {
    raise InvalidCode
  }
  { code, status, occurrence, snapshot: snapshot.copy() }
}

///|
/// Encode the four-byte DTC record used in a UDS response.
pub fn encode_dtc_record(record : DtcRecord) -> Array[Byte] {
  [
    (record.code >> 16).to_byte(),
    (record.code >> 8).to_byte(),
    record.code.to_byte(),
    record.status,
  ]
}

///|
/// Parse a positive ReadDTCInformation response.
pub fn parse_dtc_report(payload : Array[Byte]) -> DtcReport raise DtcCodecError {
  if payload.length() < 3 || payload[0] != 0x59 {
    raise InvalidPayload
  }
  if (payload.length() - 3) % 4 != 0 {
    raise InvalidRecordLength
  }
  let records : Array[DtcRecord] = []
  let mut index = 3
  while index < payload.length() {
    let code : UInt = (payload[index].to_uint() << 16) |
      (payload[index + 1].to_uint() << 8) |
      payload[index + 2].to_uint()
    records.push(
      dtc_record(code, payload[index + 3]) catch {
        _ => raise InvalidCode
      },
    )
    index += 4
  }
  { subfunction: payload[1], status_availability_mask: payload[2], records }
}

///|
/// Encode a report while preserving record order.
pub fn encode_dtc_report(report : DtcReport) -> Array[Byte] {
  let result : Array[Byte] = [
    0x59,
    report.subfunction,
    report.status_availability_mask,
  ]
  for record in report.records {
    for byte in encode_dtc_record(record) {
      result.push(byte)
    }
  }
  result
}

///|
/// A bounded DTC store suitable for an ECU simulator or gateway cache.
pub struct DtcStore {
  capacity : Int
  records : Array[DtcRecord]
  mut updates : UInt
}

///|
pub fn new_dtc_store(capacity : Int) -> DtcStore raise DtcCodecError {
  if capacity < 0 {
    raise CapacityExceeded
  }
  { capacity, records: [], updates: 0 }
}

///|
/// Add a code or update the status and occurrence count of an existing code.
pub fn DtcStore::upsert(
  self : DtcStore,
  record : DtcRecord,
) -> Unit raise DtcCodecError {
  match self.find_index(record.code) {
    Some(index) => {
      let previous = self.records[index]
      self.records[index] = {
        code: record.code,
        status: record.status,
        occurrence: previous.occurrence + record.occurrence,
        snapshot: record.snapshot.copy(),
      }
    }
    None => {
      if self.capacity > 0 && self.records.length() >= self.capacity {
        raise CapacityExceeded
      }
      self.records.push(record)
    }
  }
  self.updates += 1
}

///|
/// Remove one DTC, returning whether it existed.
pub fn DtcStore::remove(self : DtcStore, code : UInt) -> Bool {
  match self.find_index(code) {
    Some(index) => {
      ignore(self.records.remove(index))
      self.updates += 1
      true
    }
    None => false
  }
}

///|
/// Clear all records whose code matches a 24-bit mask.
pub fn DtcStore::clear_mask(self : DtcStore, code : UInt, mask : UInt) -> Int {
  let mut removed = 0
  let mut index = 0
  while index < self.records.length() {
    if (self.records[index].code & mask) == (code & mask) {
      ignore(self.records.remove(index))
      removed += 1
    } else {
      index += 1
    }
  }
  if removed > 0 {
    self.updates += 1
  }
  removed
}

///|
/// Query records whose status contains every bit in `status_mask`.
pub fn DtcStore::query_status(
  self : DtcStore,
  status_mask : Byte,
) -> Array[DtcRecord] {
  let result : Array[DtcRecord] = []
  for record in self.records {
    if (record.status & status_mask) == status_mask {
      result.push(record)
    }
  }
  result
}

///|
pub fn DtcStore::find(self : DtcStore, code : UInt) -> DtcRecord? {
  match self.find_index(code) {
    Some(index) => Some(self.records[index])
    None => None
  }
}

///|
pub fn DtcStore::snapshot(self : DtcStore) -> Array[DtcRecord] {
  self.records.copy()
}

///|
pub fn DtcStore::length(self : DtcStore) -> Int {
  self.records.length()
}

///|
pub fn DtcStore::updates(self : DtcStore) -> UInt {
  self.updates
}

///|
pub fn DtcRecord::code(self : DtcRecord) -> UInt {
  self.code
}

///|
pub fn DtcRecord::status(self : DtcRecord) -> Byte {
  self.status
}

///|
pub fn DtcRecord::occurrence(self : DtcRecord) -> UInt {
  self.occurrence
}

///|
pub fn DtcRecord::snapshot(self : DtcRecord) -> Array[Byte] {
  self.snapshot.copy()
}

///|
pub fn DtcReport::subfunction(self : DtcReport) -> Byte {
  self.subfunction
}

///|
pub fn DtcReport::status_availability_mask(self : DtcReport) -> Byte {
  self.status_availability_mask
}

///|
pub fn DtcReport::records(self : DtcReport) -> Array[DtcRecord] {
  self.records.copy()
}

///|
fn DtcStore::find_index(self : DtcStore, code : UInt) -> Int? {
  for index in 0..<self.records.length() {
    if self.records[index].code == code {
      return Some(index)
    }
  }
  None
}
