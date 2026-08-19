///|
test "CAN timing calculator finds exact common rates" {
  let timing = calculate_bit_timing(80_000_000, 500_000, 87.5) catch {
    _ => panic()
  }
  inspect(timing.actual_bitrate(), content="500000")
  assert_true(timing.sample_point() > 80.0)
  assert_true(timing.sample_point() < 95.0)
  inspect(timing.bit_time_ns(), content="2000")
}

///|
test "CAN timing validates impossible inputs" {
  try calculate_bit_timing(0, 500_000, 87.5) catch {
    CanTimingError::InvalidClock => inspect(true, content="true")
    _ => fail("wrong error")
  } noraise {
    _ => fail("expected invalid clock")
  }
  let nominal = calculate_bit_timing(80_000_000, 500_000, 87.5) catch {
    _ => panic()
  }
  let data = calculate_bit_timing(80_000_000, 2_000_000, 80.0) catch {
    _ => panic()
  }
  let timing = can_fd_timing(nominal, data) catch { _ => panic() }
  let frame = fd_frame(1, Array::make(12, 0), bitrate_switch=true) catch {
    _ => panic()
  }
  assert_true(fd_frame_duration_ns(frame, timing) > 0)
}
