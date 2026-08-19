///|
test "checked ISO-TP round trip" {
  let config = isotp_config() catch { _ => panic() }
  let payload : Array[Byte] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]
  let raw = isotp_segment_checked(payload, config)
  inspect(raw.length(), content="3")
  let packets = raw.map(packet => {
    isotp_decode_checked(packet, config) catch {
      _ => panic()
    }
  })
  let rebuilt = isotp_reassemble_checked(packets) catch { _ => panic() }
  assert_true(rebuilt == payload)
  let frames = isotp_frames(0x700, payload, config) catch { _ => panic() }
  let rebuilt_frames = isotp_reassemble_frames(frames, config) catch {
    _ => panic()
  }
  assert_true(rebuilt_frames == payload)
}

///|
test "incremental ISO-TP receiver catches sequence errors" {
  let config = isotp_config() catch { _ => panic() }
  let receiver = new_isotp_receiver(config)
  let first = isotp_decode_checked([0x10, 10, 1, 2, 3, 4, 5, 6], config) catch {
    _ => panic()
  }
  let first_status = receiver.push(first) catch { _ => panic() }
  match first_status {
    Waiting(received=6, total=10) => inspect(true, content="true")
    _ => fail("unexpected first status")
  }
  let wrong = isotp_decode_checked([0x23, 7, 8, 9, 10], config) catch {
    _ => panic()
  }
  try receiver.push(wrong) catch {
    IsoTpError::SequenceMismatch => inspect(true, content="true")
    _ => fail("wrong error")
  } noraise {
    _ => fail("expected sequence mismatch")
  }
}

///|
test "ISO-TP frame size and flow control boundaries" {
  let config = isotp_config(frame_bytes=64, block_size=8, separation_time=5) catch {
    _ => panic()
  }
  inspect(config.frame_bytes(), content="64")
  let frames = isotp_frames(
    0x18DA00F1,
    Array::make(130, 0xAA),
    config,
    extended=true,
  ) catch {
    _ => panic()
  }
  assert_true(frames.length() > 2)
  let receiver = new_isotp_receiver(config)
  debug_inspect(receiver.flow_control(), content="[0x30, 0x08, 0x05]")
}
