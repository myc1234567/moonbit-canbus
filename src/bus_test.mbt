///|
test "bus filters and arbitration" {
  let bus = new_bus(4)
  let filters = new_filter_bank()
  filters.add(mask_filter(0x100, 0x700))
  bus.set_filters(filters)
  let low = data_frame(0x101, [1]) catch { _ => panic() }
  let high = data_frame(0x200, [2]) catch { _ => panic() }
  inspect(bus.publish(high), content="false")
  inspect(bus.publish(low), content="true")
  inspect(bus.pending(), content="1")
  debug_inspect(
    bus.receive().map(fn(frame) { frame.id() }),
    content="Some(257)",
  )
}

///|
test "signal round trip" {
  let item = signal("speed", 8, 8)
  let encoded = item.encode_raw([0, 0], 120)
  inspect(item.decode_raw(encoded), content="120")
}
