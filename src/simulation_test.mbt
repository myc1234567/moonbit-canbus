///|
test "deterministic simulation orders time and arbitration" {
  let simulation = new_simulation(8, 500)
  let low = data_frame(0x200, [2]) catch { _ => panic() }
  let high = data_frame(0x100, [1]) catch { _ => panic() }
  simulation.schedule(20, low, source="slow") catch {
    _ => panic()
  }
  simulation.schedule(10, high, source="fast") catch {
    _ => panic()
  }
  inspect(simulation.run_until(20) catch { _ => panic() }, content="2")
  let first = simulation.receive()
  match first {
    Some(frame) => inspect(frame.id(), content="256")
    None => fail("frame missing")
  }
  let report = simulation.report(0)
  inspect(report.delivered(), content="2")
  inspect(report.duration_us(), content="20")
}

///|
test "periodic simulation publisher" {
  let simulation = new_simulation(0, 500)
  let frame = data_frame(1, [0xAA]) catch { _ => panic() }
  simulation.add_periodic("heartbeat", frame, 5, 10, 3) catch {
    _ => panic()
  }
  inspect(simulation.run_until(30) catch { _ => panic() }, content="3")
  let report = simulation.report(0)
  inspect(report.scheduled(), content="3")
  inspect(report.delivered(), content="3")
}
