///|
test "transport queue orders by arbitration and expires deadlines" {
  let queue = new_frame_queue(3) catch { _ => panic() }
  let low = data_frame(0x700, [1]) catch { _ => panic() }
  let high = data_frame(0x100, [2]) catch { _ => panic() }
  let middle = data_frame(0x300, [3]) catch { _ => panic() }
  let first = queue.enqueue(1, low, 10, 100) catch { _ => panic() }
  let second = queue.enqueue(1, high, 20, 40) catch { _ => panic() }
  ignore(queue.enqueue(2, middle, 30, 0) catch { _ => panic() })
  inspect(first, content="1")
  inspect(second, content="2")
  match queue.peek() {
    Some(item) => inspect(item.frame().id(), content="256")
    None => fail("queue unexpectedly empty")
  }
  let expired = queue.expire(40)
  inspect(expired.length(), content="1")
  inspect(queue.length(), content="2")
}

///|
test "transport queue enforces capacity and channel drains" {
  let queue = new_frame_queue(1) catch { _ => panic() }
  let frame = data_frame(1, []) catch { _ => panic() }
  ignore(queue.enqueue(7, frame, 0, 0) catch { _ => panic() })
  try queue.enqueue(8, frame, 0, 0) catch {
    QueueError::Full => inspect(queue.dropped(), content="1")
    _ => fail("wrong queue error")
  } noraise {
    _ => fail("expected full queue")
  }
  let drained = queue.take_channel(7, 1) catch { _ => panic() }
  inspect(drained.length(), content="1")
  try queue.dequeue() catch {
    QueueError::Empty => inspect(true, content="true")
    _ => fail("wrong empty error")
  } noraise {
    _ => fail("expected empty queue")
  }
}

///|
test "unbounded queue accepts boundary sequence and invalid limits" {
  let queue = new_frame_queue(0) catch { _ => panic() }
  let frame = fd_frame(1, Array::make(64, 0xAA)) catch { _ => panic() }
  ignore(queue.enqueue(0, frame, 5, 0) catch { _ => panic() })
  try queue.take_channel(0, -1) catch {
    QueueError::InvalidLimit => inspect(true, content="true")
    _ => fail("wrong limit error")
  } noraise {
    _ => fail("expected invalid limit")
  }
  inspect(queue.capacity(), content="0")
}
