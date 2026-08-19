///|
test "frame codec round trip" {
  let frame = fd_frame(
    0x123,
    [1, 2, 3, 4, 5, 6, 7, 8, 9],
    bitrate_switch=true,
    error_state_indicator=true,
  ) catch {
    _ => panic()
  }
  let encoded = encode_frame(frame)
  inspect(encoded.length(), content="16")
  let decoded = decode_frame(encoded) catch { _ => panic() }
  assert_true(frame_equal(frame, decoded))
  let hex = frame_to_hex(frame)
  assert_true(frame_equal(frame, frame_from_hex(hex) catch { _ => panic() }))
}

///|
test "frame codec rejects malformed input" {
  try decode_frame([1, 0]) catch {
    FrameCodecError::Truncated => inspect(true, content="true")
    _ => fail("wrong error")
  } noraise {
    _ => fail("expected truncation")
  }
  try frame_from_hex("0") catch {
    FrameCodecError::InvalidHex => inspect(true, content="true")
    _ => fail("wrong error")
  } noraise {
    _ => fail("expected invalid hex")
  }
}

///|
test "frame codec preserves frame kinds" {
  let remote = remote_frame(7) catch { _ => panic() }
  let error = error_frame(0x55)
  assert_true(
    (decode_frame(encode_frame(remote)) catch { _ => panic() }).is_remote(),
  )
  assert_true(
    (decode_frame(encode_frame(error)) catch { _ => panic() }).is_error(),
  )
  inspect(fd_length_from_dlc(15), content="64")
}
