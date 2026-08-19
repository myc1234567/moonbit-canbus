///|
fn main {
  let args = @env.args()
  if args.contains("--help") || args.contains("-h") || args.length() <= 1 {
    print_usage()
  } else if args.contains("demo") {
    run_demo()
  } else if args.contains("decode") {
    let text = if args.length() > 2 { args[2] } else { "" }
    decode_hex(text)
  } else {
    println("unknown command")
    print_usage()
  }
}

///|
fn print_usage() -> Unit {
  println("canctl - deterministic MoonBit CAN inspection tool")
  println("usage:")
  println("  moon run cmd/canctl -- demo")
  println("  moon run cmd/canctl -- decode <frame-hex>")
}

///|
fn run_demo() -> Unit {
  let classic = @can.data_frame(0x123, [0x10, 0x20, 0x30]) catch {
    _ => {
      println("failed to create demo frame")
      return
    }
  }
  let fd = @can.fd_frame(0x1ABCDE, Array::make(12, 0x5A), extended=true) catch {
    _ => {
      println("failed to create demo CAN-FD frame")
      return
    }
  }
  println(@can.frame_summary(classic))
  println(@can.frame_to_hex(classic))
  println(@can.frame_summary(fd))
  println(@can.frame_to_hex(fd))
  println(@can.frame_metrics([classic, fd]).to_text())
}

///|
fn decode_hex(text : String) -> Unit {
  try @can.frame_from_hex(text) catch {
    _ => println("invalid frame encoding")
  } noraise {
    frame => {
      println(@can.frame_summary(frame))
      println("round-trip=" + @can.frame_to_hex(frame))
    }
  }
}
