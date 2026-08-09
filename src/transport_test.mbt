///|
test "isotp segmentation and reassembly" {
  let payload = Array::make(20, (42).to_byte())
  let packets = isotp_segment(payload)
  inspect(packets.length(), content="3")
  let first = isotp_decode(packets[0])
  let tail = packets[1:].map(fn(item) { isotp_decode(item).unwrap() })
  debug_inspect(
    isotp_reassemble(first.unwrap(), tail).map(fn(item) { item.length() }),
    content="Some(20)",
  )
}

///|
test "j1939 pgn" {
  let value = j1939_id(3, false, 240, 1, 128)
  inspect(value.pgn(), content="61441")
  debug_inspect(decode_j1939(encode_j1939(value)).source(), content="0x80")
}

///|
test "trace replay" {
  let trace = new_trace()
  let bus = new_bus(4)
  let filters = new_filter_bank()
  filters.add(mask_filter(0, 0))
  bus.set_filters(filters)
  let frame = data_frame(1, [1]) catch { _ => panic() }
  trace.record(100, frame)
  inspect(trace.replay(bus), content="1")
  inspect(trace.length(), content="1")
}
