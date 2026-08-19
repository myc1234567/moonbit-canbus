///|
test "DTC report round trips and preserves status fields" {
  let first = dtc_record(0x123456, 0x09, occurrence=2, snapshot=[0xAA]) catch {
    _ => panic()
  }
  let second = dtc_record(0xABCDEF, 0x01) catch { _ => panic() }
  let report = new_dtc_report(2, 0xFF, [first, second])
  let encoded = encode_dtc_report(report)
  let decoded = parse_dtc_report(encoded) catch { _ => panic() }
  inspect(decoded.records().length(), content="2")
  match decoded.records()[0] {
    record => {
      inspect(record.code(), content="1193046")
      inspect(record.status().to_int(), content="9")
    }
  }
}

///|
test "DTC store updates, filters and clears by mask" {
  let store = new_dtc_store(2) catch { _ => panic() }
  let first = dtc_record(0x120001, 0x09, occurrence=2) catch { _ => panic() }
  let update = dtc_record(0x120001, 0x01, occurrence=1) catch { _ => panic() }
  let second = dtc_record(0x120002, 0x09) catch { _ => panic() }
  ignore(store.upsert(first) catch { _ => panic() })
  ignore(store.upsert(update) catch { _ => panic() })
  ignore(store.upsert(second) catch { _ => panic() })
  match store.find(0x120001) {
    Some(record) => inspect(record.occurrence(), content="3")
    None => fail("DTC missing")
  }
  inspect(store.query_status(0x01).length(), content="2")
  inspect(store.clear_mask(0x120000, 0xFFFF00), content="2")
  inspect(store.length(), content="0")
}

///|
test "DTC codec rejects malformed and over-capacity records" {
  try parse_dtc_report([0x59, 1, 0xFF, 0x01]) catch {
    DtcCodecError::InvalidRecordLength => inspect(true, content="true")
    _ => fail("wrong report error")
  } noraise {
    _ => fail("expected malformed report")
  }
  try dtc_record(0x1000000, 0) catch {
    DtcCodecError::InvalidCode => inspect(true, content="true")
    _ => fail("wrong code error")
  } noraise {
    _ => fail("expected invalid code")
  }
  let store = new_dtc_store(1) catch { _ => panic() }
  let first = dtc_record(1, 0) catch { _ => panic() }
  let second = dtc_record(2, 0) catch { _ => panic() }
  ignore(store.upsert(first) catch { _ => panic() })
  try store.upsert(second) catch {
    DtcCodecError::CapacityExceeded => inspect(true, content="true")
    _ => fail("wrong capacity error")
  } noraise {
    _ => fail("expected capacity error")
  }
}
