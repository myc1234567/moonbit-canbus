///|
test "frame validation and transmission estimate" {
  let frame = data_frame(0x100, [1, 2, 3]) catch { _ => panic() }
  let report = validate_frame(frame)
  assert_true(report.is_valid())
  assert_true(report.wire_bits() > 0)
  assert_true(report.stuffed_bits() >= encode_bits(frame).length())
  assert_true(estimate_transmission_us(frame, 500, 2000) > 0)
  inspect(frame_class_name(classify_frame(frame)), content="classic-data")
}

///|
test "frame validation boundaries" {
  let classic = data_frame(0x7FF, [0, 1, 2, 3, 4, 5, 6, 7]) catch {
    _ => panic()
  }
  let extended = data_frame(0x1FFFFFFF, [], extended=true) catch {
    _ => panic()
  }
  assert_true(frame_is_valid(classic))
  assert_true(frame_is_valid(extended))
  inspect(max_payload(classic.protocol()), content="8")
  let fd = fd_frame(0x10, [], bitrate_switch=true) catch { _ => panic() }
  inspect(max_payload(fd.protocol()), content="64")
  inspect(
    count_stuffed_bits([true, true, true, true, true, false]),
    content="1",
  )
}
