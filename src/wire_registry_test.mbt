///|
test "wire codec round trips classic and FD data" {
  let classic = data_frame(0x123, [1, 2, 3]) catch { _ => panic() }
  let fd = fd_frame(0x1ABCDE, Array::make(12, 0x5A), extended=true) catch {
    _ => panic()
  }
  assert_true(wire_round_trip(classic))
  assert_true(wire_round_trip(fd))
  assert_true(encoded_wire_length(fd) > encoded_wire_length(classic))
}

///|
test "node registry delivers to matching nodes" {
  let registry = new_node_registry()
  registry.register(1, "ecu", exact_filter(0x100)) catch {
    _ => panic()
  }
  registry.register(2, "logger", mask_filter(0x100, 0x700)) catch {
    _ => panic()
  }
  let frame = data_frame(0x123, []) catch { _ => panic() }
  let names = registry.deliver(frame)
  inspect(names.length(), content="1")
  match registry.find(2) {
    Some(node) => inspect(node.received(), content="1")
    None => fail("node missing")
  }
}
