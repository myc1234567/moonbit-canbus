///|
test "admission policy accepts matching traffic and enforces rate" {
  let policy = new_admission_policy()
  let rule = admission_rule(
    "drive",
    mask_filter(0x100, 0x700),
    max_payload=8,
    allow_fd=false,
    min_interval_us=100,
  ) catch {
    _ => panic()
  }
  policy.add_rule(rule)
  let frame = data_frame(0x123, [1, 2]) catch { _ => panic() }
  let decision = policy.evaluate(frame, 1000) catch { _ => panic() }
  assert_true(decision.accepted())
  inspect(decision.rule_name(), content="drive")
  assert_true(!policy.admit(frame, 1050))
  inspect(policy.accepted(), content="1")
  inspect(policy.rejected(), content="1")
}

///|
test "admission policy rejects protocol, payload and missing matches" {
  let policy = new_admission_policy()
  policy.add_rule(
    admission_rule("classic", exact_filter(1), max_payload=8, allow_fd=false) catch {
      _ => panic()
    },
  )
  let fd = fd_frame(1, Array::make(12, 0)) catch { _ => panic() }
  try policy.evaluate(fd, 1) catch {
    AdmissionError::ProtocolNotAllowed => inspect(true, content="true")
    _ => fail("wrong protocol error")
  } noraise {
    _ => fail("expected protocol rejection")
  }
  let other = data_frame(2, []) catch { _ => panic() }
  assert_true(!policy.admit(other, 2))
  inspect(policy.rejected(), content="2")
}

///|
test "admission policy validates rule and timestamp boundaries" {
  try admission_rule("", exact_filter(1)) catch {
    AdmissionError::InvalidRule => inspect(true, content="true")
    _ => fail("wrong rule error")
  } noraise {
    _ => fail("expected invalid rule")
  }
  let policy = new_admission_policy()
  policy.add_rule(admission_rule("one", exact_filter(1)) catch { _ => panic() })
  let frame = data_frame(1, []) catch { _ => panic() }
  ignore(policy.evaluate(frame, 10) catch { _ => panic() })
  try policy.evaluate(frame, 9) catch {
    AdmissionError::TimestampReversed => inspect(true, content="true")
    _ => fail("wrong timestamp error")
  } noraise {
    _ => fail("expected timestamp error")
  }
  policy.reset()
  inspect(policy.accepted(), content="0")
}
