///|
test "latency window computes rolling percentiles and jitter" {
  let window = new_latency_window(3) catch { _ => panic() }
  inspect(window.record(0, 10, 1) catch { _ => 0 }, content="1")
  ignore(window.record(20, 50, 2) catch { _ => panic() })
  ignore(window.record(60, 100, 3) catch { _ => panic() })
  let stats = window.stats()
  inspect(stats.count(), content="3")
  match stats.minimum() {
    Some(value) => inspect(value, content="10")
    None => fail("missing minimum")
  }
  match stats.p95() {
    Some(value) => inspect(value, content="40")
    None => fail("missing p95")
  }
  inspect(stats.jitter(), content="30")
  inspect(window.percentile(0) catch { _ => 0 }, content="10")
  inspect(window.percentile(100) catch { _ => 0 }, content="40")
}

///|
test "latency window evicts oldest sample and handles empty boundaries" {
  let window = new_latency_window(2) catch { _ => panic() }
  ignore(window.record(0, 1, 4) catch { _ => panic() })
  ignore(window.record(2, 12, 5) catch { _ => panic() })
  ignore(window.record(20, 50, 6) catch { _ => panic() })
  inspect(window.length(), content="2")
  inspect(window.samples()[0].sequence(), content="2")
  inspect(window.stats().payload_bytes(), content="11")
  let empty = new_latency_window(0) catch { _ => panic() }
  inspect(empty.stats().count(), content="0")
  try empty.percentile(50) catch {
    LatencyError::InvalidPercentile => inspect(true, content="true")
    _ => fail("wrong empty percentile error")
  } noraise {
    _ => fail("expected empty percentile error")
  }
}

///|
test "latency window rejects reversed timestamps and invalid capacity" {
  try new_latency_window(-1) catch {
    LatencyError::InvalidCapacity => inspect(true, content="true")
    _ => fail("wrong capacity error")
  } noraise {
    _ => fail("expected invalid capacity")
  }
  let window = new_latency_window(2) catch { _ => panic() }
  ignore(window.record(10, 20, 0) catch { _ => panic() })
  try window.record(30, 25, 1) catch {
    LatencyError::InvalidTimestamp => inspect(true, content="true")
    _ => fail("wrong timestamp error")
  } noraise {
    _ => fail("expected timestamp error")
  }
}
