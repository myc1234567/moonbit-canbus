///|
test "gateway transforms matching frames" {
  let gateway = new_gateway()
  let rule = route_rule(
    "telemetry",
    mask_filter(0x100, 0x700),
    output_id=Some(0x300),
    prefix=[0xAA],
    strip_prefix=1,
  ) catch {
    _ => panic()
  }
  gateway.add_rule(rule)
  let frame = data_frame(0x123, [0x01, 0x02, 0x03]) catch { _ => panic() }
  let routed = gateway.forward(frame)
  match routed {
    Some(item) => {
      inspect(item.rule_name(), content="telemetry")
      inspect(item.frame().id(), content="768")
      debug_inspect(item.frame().data(), content="[0xaa, 0x02, 0x03]")
    }
    None => fail("route missing")
  }
}

///|
test "gateway reports unmatched frames" {
  let gateway = new_gateway()
  gateway.add_rule(route_rule("only", exact_filter(7)) catch { _ => panic() })
  let frame = data_frame(8, []) catch { _ => panic() }
  let routed = gateway.forward(frame)
  assert_true(routed is None)
  inspect(gateway.rejected(), content="1")
}
