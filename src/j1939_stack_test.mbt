///|
test "J1939 message and identifier round trip" {
  let identifier = j1939_id(3, false, 0xEF, 0x80, 0x22)
  let message = j1939_message(identifier, [1, 2, 3]) catch { _ => panic() }
  let frame = message.to_frame() catch { _ => panic() }
  let decoded = decode_j1939_frame(frame) catch { _ => panic() }
  match decoded {
    Some(item) => {
      inspect(item.identifier().pgn(), content="61184")
      assert_true(item.payload() == [1, 2, 3])
    }
    None => fail("message missing")
  }
}

///|
test "J1939 BAM boundaries" {
  let payload : Array[Byte] = Array::make(20, 0x5A)
  let packets = j1939_bam(0x00F004, payload) catch { _ => panic() }
  match j1939_parse_bam(packets[0]) {
    Some((length, count, pgn)) => {
      inspect(length, content="20")
      inspect(count, content="3")
      inspect(pgn, content="61444")
    }
    None => fail("announcement missing")
  }
  let data = j1939_reassemble_bam(packets[1:].to_owned(), 20) catch {
    _ => panic()
  }
  assert_true(data == payload)
}
