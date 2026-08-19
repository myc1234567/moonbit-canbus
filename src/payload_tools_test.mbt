///|
test "payload endian and checksum helpers" {
  let data : Array[Byte] = [0x12, 0x34, 0x56, 0x78]
  inspect(payload_uint(data, 0, 2, BigEndian) catch { _ => 0 }, content="4660")
  inspect(
    payload_uint(data, 0, 2, LittleEndian) catch {
      _ => 0
    },
    content="13330",
  )
  let changed = payload_set_uint(data, 1, 2, 0xCAFE, BigEndian) catch {
    _ => panic()
  }
  debug_inspect(changed, content="[0x12, 0xca, 0xfe, 0x78]")
  inspect(crc8_sae_j1850([1, 2, 3]).to_int(), content="151")
}

///|
test "payload counter and frame transforms" {
  let data = set_counter_nibble([0xF0], 0, 3, false) catch { _ => panic() }
  debug_inspect(data, content="[0xf3]")
  inspect(
    (counter_nibble(data, 0, false) catch { _ => 0 }).to_int(),
    content="3",
  )
  assert_true(counter_is_next(15, 0))
  let frame = data_frame(1, [1, 2, 3]) catch { _ => panic() }
  let changed = frame_with_id(frame, 2) catch { _ => panic() }
  inspect(changed.id(), content="2")
  debug_inspect(
    reverse_payload([1, 2, 3], 0, 3) catch {
      _ => []
    },
    content="[0x03, 0x02, 0x01]",
  )
}
