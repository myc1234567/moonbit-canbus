///|
test "health assessment distinguishes healthy and overloaded buses" {
  let frame = data_frame(1, [1]) catch { _ => panic() }
  let metrics = frame_metrics([frame])
  let healthy = assess_bus_health(metrics, 0, 1_000_000, 500)
  inspect(bus_health_name(healthy.state()), content="healthy")
  let overloaded = assess_bus_health(metrics, 1, 1, 1)
  inspect(bus_health_name(overloaded.state()), content="overloaded")
}

///|
test "trace analysis captures changes and gaps" {
  let trace = new_trace()
  let a = data_frame(1, [1]) catch { _ => panic() }
  let b = data_frame(2, [2]) catch { _ => panic() }
  trace.record(10, a)
  trace.record(20, a)
  trace.record(50, b)
  let analysis = analyze_trace(trace)
  inspect(analysis.unique_ids(), content="2")
  inspect(analysis.changed_payloads(), content="1")
  inspect(analysis.repeated_payloads(), content="1")
  debug_inspect(analysis.minimum_gap(), content="Some(10)")
}
