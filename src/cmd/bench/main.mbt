///|
/// Run a repeatable in-process frame codec benchmark.
fn main {
  let iterations = 100_000
  let start = @env.now()
  let mut checksum : UInt = 0
  let mut encoded_bytes = 0
  for index in 0..<iterations {
    let id = (index % 0x7FF).reinterpret_as_uint()
    let frame = @can.data_frame(id, [1, 2, 3, 4, 5, 6, 7, 8]) catch {
      _ => continue
    }
    let encoded = @can.encode_frame(frame)
    let decoded = @can.decode_frame(encoded) catch { _ => continue }
    checksum = checksum ^ decoded.id()
    encoded_bytes += encoded.length()
  }
  let elapsed = @env.now() - start
  let operations_per_second = if elapsed == 0 {
    0.0
  } else {
    iterations.to_double() * 1000.0 / elapsed.to_double()
  }
  println("benchmark=frame-codec")
  println("iterations=\{iterations}")
  println("elapsed_ms=\{elapsed}")
  println("operations_per_second=\{operations_per_second}")
  println("encoded_bytes=\{encoded_bytes}")
  println("checksum=\{checksum}")
}
