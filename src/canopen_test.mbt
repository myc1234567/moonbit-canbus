///|
test "CANopen COB-ID and SDO helpers" {
  let id = canopen_cob_id(CanOpenCobType::SdoReceive, 5) catch { _ => panic() }
  inspect(id, content="1541")
  let decoded = decode_canopen_cob_id(id) catch { _ => panic() }
  inspect(decoded.node_id().to_int(), content="5")
  inspect(canopen_cob_name(decoded.object_type()), content="rsdo")
  debug_inspect(
    canopen_sdo_download(0x2000, 1, [0x12, 0x34]) catch {
      _ => panic()
    },
    content="[0x2b, 0x00, 0x20, 0x01, 0x12, 0x34, 0x00, 0x00]",
  )
}

///|
test "CANopen node and data boundaries" {
  debug_inspect(
    canopen_nmt(CanOpenNmtCommand::Start, 0) catch {
      _ => panic()
    },
    content="[0x01, 0x00]",
  )
  debug_inspect(
    canopen_emergency(0x1234, 0x81, [1, 2]) catch {
      _ => panic()
    },
    content="[0x34, 0x12, 0x81, 0x01, 0x02, 0x00, 0x00, 0x00]",
  )
  try canopen_cob_id(CanOpenCobType::Heartbeat, 0) catch {
    CanOpenError::InvalidNodeId => inspect(true, content="true")
    _ => fail("wrong error")
  } noraise {
    _ => fail("expected invalid node")
  }
}
