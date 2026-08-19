///|
test "UDS builders expose service identifiers" {
  let request = write_data(0xF190, [1, 2]) catch { _ => panic() }
  inspect(request.service_id().to_int(), content="46")
  inspect(request.service_name(), content="WriteDataByIdentifier")
  debug_inspect(request.payload(), content="[0x2e, 0xf1, 0x90, 0x01, 0x02]")
  let clear = clear_diagnostic_information(0xFFFFFF) catch { _ => panic() }
  debug_inspect(clear.payload(), content="[0x14, 0xff, 0xff, 0xff]")
}

///|
test "UDS response validation and negative codes" {
  let request = read_data(0x1234)
  let response = parse_uds_response(request, [0x62, 0x12, 0x34, 0xAA]) catch {
    _ => panic()
  }
  assert_true(response.is_positive())
  inspect(response.response_service().to_int(), content="98")
  let negative = parse_uds_response(request, [0x7F, 0x22, 0x31]) catch {
    _ => panic()
  }
  assert_true(!negative.is_positive())
  inspect(uds_negative_code_name(0x31), content="request-out-of-range")
}

///|
test "UDS address and transfer boundaries" {
  let read = read_memory(0x123456, 0x40, address_bytes=3, length_bytes=2) catch {
    _ => panic()
  }
  debug_inspect(
    read.payload(),
    content="[0x23, 0x32, 0x12, 0x34, 0x56, 0x00, 0x40]",
  )
  try transfer_data(0, []) catch {
    UdsError::InvalidBlockCounter => inspect(true, content="true")
    _ => fail("wrong error")
  } noraise {
    _ => fail("expected invalid block counter")
  }
}
