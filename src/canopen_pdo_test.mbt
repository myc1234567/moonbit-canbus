///|
test "CANopen PDO mapping packs and unpacks" {
  let mapping = new_pdo_mapping() catch { _ => panic() }
  mapping.add(0x2000, 1, 8) catch {
    _ => panic()
  }
  mapping.add(0x2001, 1, 16) catch {
    _ => panic()
  }
  let payload = mapping.pack([0x12, 0x3456]) catch { _ => panic() }
  debug_inspect(
    payload,
    content="[0x12, 0x34, 0x56, 0x00, 0x00, 0x00, 0x00, 0x00]",
  )
  let values = mapping.unpack(payload) catch { _ => panic() }
  inspect(values[1].value(), content="13398")
  let frame = pdo_frame(5, 1, payload) catch { _ => panic() }
  inspect(frame.id(), content="389")
}

///|
test "CANopen PDO mapping rejects overflow" {
  let mapping = new_pdo_mapping(payload_bytes=1) catch { _ => panic() }
  mapping.add(1, 1, 8) catch {
    _ => panic()
  }
  try mapping.pack([0x100]) catch {
    PdoError::ValueTooLarge => inspect(true, content="true")
    _ => fail("wrong error")
  } noraise {
    _ => fail("expected value overflow")
  }
}
