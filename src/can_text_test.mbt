///|
test "CAN text log round trip" {
  let log = new_can_log()
  let frame = data_frame(0x123, [1, 2, 3]) catch { _ => panic() }
  log.push(42, frame, channel="can1")
  let restored = can_log_from_text(log.to_text()) catch { _ => panic() }
  inspect(restored.length(), content="1")
  inspect(restored.entries()[0].channel(), content="can1")
  let (timestamp, decoded) = parse_can_line(can_line(42, frame)) catch {
    _ => panic()
  }
  inspect(timestamp, content="42")
  assert_true(frame_equal(decoded, frame))
}

///|
test "frame batch binary archive and checksum" {
  let first = data_frame(1, [1]) catch { _ => panic() }
  let second = fd_frame(2, [2, 3, 4]) catch { _ => panic() }
  let batch = frame_batch(7, [first, second]) catch { _ => panic() }
  let restored = decode_frame_batch(batch.encode()) catch { _ => panic() }
  inspect(restored.sequence(), content="7")
  inspect(restored.payload_bytes(), content="4")
  let corrupted = batch.encode()
  corrupted[corrupted.length() - 1] = corrupted[corrupted.length() - 1] ^ 1
  try decode_frame_batch(corrupted) catch {
    BatchError::ChecksumMismatch => inspect(true, content="true")
    _ => fail("wrong error")
  } noraise {
    _ => fail("expected checksum mismatch")
  }
}
