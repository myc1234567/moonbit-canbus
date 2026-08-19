///|
test "network broadcasts queued frames and tracks node counters" {
  let network = new_can_network(timeout_us=1000, queue_capacity=4) catch {
    _ => panic()
  }
  network.add_node(1, "ecu-a", 0) catch {
    _ => panic()
  }
  network.add_node(2, "ecu-b", 0) catch {
    _ => panic()
  }
  network.add_node(3, "logger", 0) catch {
    _ => panic()
  }
  let frame = data_frame(0x101, [0xAA]) catch { _ => panic() }
  ignore(network.send(1, frame, 10) catch { _ => panic() })
  inspect(network.pending(), content="1")
  let delivered = network.poll(10) catch { _ => panic() }
  inspect(delivered.length(), content="1")
  inspect(delivered[0].recipients().length(), content="2")
  match network.node(2) {
    Some(node) => inspect(node.received(), content="1")
    None => fail("node missing")
  }
}

///|
test "network liveness expires and heartbeat restores a node" {
  let network = new_can_network(timeout_us=100) catch { _ => panic() }
  network.add_node(1, "ecu-a", 0) catch {
    _ => panic()
  }
  network.add_node(2, "ecu-b", 0) catch {
    _ => panic()
  }
  let offline = network.offline_nodes(101) catch { _ => panic() }
  inspect(offline.length(), content="2")
  network.heartbeat(2, 120) catch {
    _ => panic()
  }
  let restored = network.offline_nodes(120) catch { _ => panic() }
  inspect(restored.length(), content="1")
  match network.node(2) {
    Some(node) => assert_true(node.online())
    None => fail("heartbeat node missing")
  }
}

///|
test "network rejects duplicate nodes, stale time and full queues" {
  let network = new_can_network(queue_capacity=1) catch { _ => panic() }
  network.add_node(1, "ecu", 0) catch {
    _ => panic()
  }
  try network.add_node(1, "duplicate", 0) catch {
    NetworkError::DuplicateNode => inspect(true, content="true")
    _ => fail("wrong duplicate error")
  } noraise {
    _ => fail("expected duplicate error")
  }
  let frame = data_frame(1, []) catch { _ => panic() }
  ignore(network.send(1, frame, 10) catch { _ => panic() })
  try network.send(1, frame, 9) catch {
    NetworkError::InvalidTimestamp => inspect(true, content="true")
    _ => fail("wrong time error")
  } noraise {
    _ => fail("expected stale time error")
  }
  try network.send(1, frame, 11) catch {
    NetworkError::QueueFull => inspect(true, content="true")
    _ => fail("wrong queue error")
  } noraise {
    _ => fail("expected full network queue")
  }
}
