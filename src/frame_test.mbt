///|
test "classic and fd dlc" {
  let classic = data_frame(0x123, [1, 2, 3]) catch { _ => panic() }
  debug_inspect(classic.dlc(), content="0x03")
  let fd = fd_frame(0x123, Array::make(20, 0)) catch { _ => panic() }
  debug_inspect(fd.dlc(), content="0x0b")
  inspect(fd_length_from_dlc(13), content="32")
}

///|
test "frame identifiers are validated" {
  let result = try data_frame(0x800, []) catch {
    err => err
  } noraise {
    _ => panic()
  }
  debug_inspect(result, content="InvalidIdentifier")
}

///|
test "crc and stuffing" {
  let bits = bits_of(0x15, 8)
  inspect(crc15(bits), content="12481")
  let original = [true, true, true, true, true, false, false]
  let encoded = stuff(original)
  let decoded = destuff(encoded) catch { _ => [] }
  debug_inspect(decoded, content="[true, true, true, true, true, false, false]")
}
