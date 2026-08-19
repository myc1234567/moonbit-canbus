///|
test "bit cursor round trip and alignment" {
  let writer = new_bit_writer()
  writer.write(0b101, 3)
  writer.write(0b11, 2)
  writer.align_byte()
  inspect(writer.length(), content="8")
  inspect(bits_to_string(writer.finish()), content="10111000")
  let reader = new_bit_reader(writer.finish())
  inspect(reader.read(3), content="5")
  inspect(reader.read(2), content="3")
  inspect(reader.remaining(), content="3")
}

///|
test "bit cursor signed values" {
  let writer = new_bit_writer()
  writer.write_signed(-3, 5)
  writer.write_signed(7, 5)
  let reader = new_bit_reader(writer.finish())
  inspect(reader.read_signed(5), content="-3")
  inspect(reader.read_signed(5), content="7")
}

///|
test "bit cursor bytes conversion" {
  let bytes : Array[Byte] = [0x80, 0x01]
  let bits = bytes_to_bits(bytes)
  inspect(bits.length(), content="16")
  debug_inspect(bits_to_bytes(bits), content="[0x80, 0x01]")
  debug_inspect(bits_to_bytes([true, false, true]), content="[0xa0]")
}

///|
test "bit cursor reports invalid reads" {
  let reader = new_bit_reader([true])
  try reader.read(2) catch {
    BitError::OutOfBounds => inspect(true, content="true")
    _ => fail("wrong error")
  } noraise {
    _ => fail("expected out of bounds")
  }
}
