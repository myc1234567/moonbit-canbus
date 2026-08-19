///|
test "scheduler orders due frames by arbitration" {
  let scheduler = new_scheduler()
  let slow = data_frame(0x200, [2]) catch { _ => panic() }
  let fast = data_frame(0x100, [1]) catch { _ => panic() }
  scheduler.add("slow", slow, 0, 10, 5, 2) catch {
    _ => panic()
  }
  scheduler.add("fast", fast, 0, 10, 5, 2) catch {
    _ => panic()
  }
  let ticks = scheduler.tick(0) catch { _ => panic() }
  inspect(ticks.length(), content="2")
  inspect(ticks[0].task_name(), content="fast")
  let second = scheduler.tick(10) catch { _ => panic() }
  inspect(second.length(), content="2")
}

///|
test "scheduler deadline and duplicate boundaries" {
  let scheduler = new_scheduler()
  let frame = data_frame(1, []) catch { _ => panic() }
  scheduler.add("one", frame, 10, 0, 1, 1) catch {
    _ => panic()
  }
  let ticks = scheduler.tick(20) catch { _ => panic() }
  assert_true(ticks[0].is_late())
  inspect(scheduler.missed(), content="1")
  try scheduler.add("one", frame, 30, 0, 1, 1) catch {
    SchedulerError::DuplicateTask => inspect(true, content="true")
    _ => fail("wrong error")
  } noraise {
    _ => fail("expected duplicate")
  }
}
