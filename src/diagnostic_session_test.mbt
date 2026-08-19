///|
test "UDS session transitions and timeout" {
  let session = new_uds_session(p2_timeout_us=100)
  let request = session_control(3)
  ignore(session.begin(request, 10) catch { _ => panic() })
  let response = session.accept(request, [0x50, 3], 50) catch { _ => panic() }
  assert_true(response.is_positive())
  inspect(uds_session_name(session.state()), content="extended")
  assert_true(!session.timed_out(100))
  assert_true(session.timed_out(151))
}

///|
test "UDS locked session rejects protected services" {
  let session = locked_uds_session()
  let request = write_memory(0x100, [1]) catch { _ => panic() }
  try session.begin(request, 1) catch {
    UdsSessionError::SecurityRequired => inspect(true, content="true")
    _ => fail("wrong error")
  } noraise {
    _ => fail("expected security requirement")
  }
}
