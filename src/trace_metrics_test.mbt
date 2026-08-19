///|
test "trace text round trip and metrics" {
  let trace = new_trace()
  let a = data_frame(0x101, [1, 2]) catch { _ => panic() }
  let b = fd_frame(0x102, Array::make(12, 3)) catch { _ => panic() }
  trace.record(10, a)
  trace.record(20, b)
  let restored = trace_from_text(trace.to_text()) catch { _ => panic() }
  inspect(restored.length(), content="2")
  let metrics = trace_metrics(restored)
  inspect(metrics.total(), content="2")
  inspect(metrics.payload_bytes(), content="14")
  inspect(metrics.payload_count(12), content="1")
  assert_true(metrics.to_text().contains("unique_ids=2"))
}

///|
test "trace rejects malformed and non-monotonic input" {
  let trace = new_trace()
  let frame = data_frame(1, []) catch { _ => panic() }
  trace.record(20, frame)
  trace.record(10, frame)
  try trace.validate() catch {
    TraceError::NonMonotonicTimestamp => inspect(true, content="true")
    _ => fail("wrong error")
  } noraise {
    _ => fail("expected timestamp error")
  }
  try trace_from_text("bad") catch {
    TraceError::InvalidLine => inspect(true, content="true")
    _ => fail("wrong error")
  } noraise {
    _ => fail("expected line error")
  }
}
