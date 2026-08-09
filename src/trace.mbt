///|
/// A timestamped frame captured from a virtual bus.
pub struct TraceEntry {
  timestamp_us : UInt64
  frame : Frame
}

///|
/// An append-only trace that can be replayed deterministically.
pub struct Trace {
  entries : Array[TraceEntry]
}

///|
/// Create an empty trace.
pub fn new_trace() -> Trace {
  { entries: [] }
}

///|
/// Append a timestamped frame.
pub fn Trace::record(
  self : Trace,
  timestamp_us : UInt64,
  frame : Frame,
) -> Unit {
  self.entries.push({ timestamp_us, frame })
}

///|
/// Return entries in capture order.
pub fn Trace::entries(self : Trace) -> Array[TraceEntry] {
  self.entries.copy()
}

///|
/// Return the number of captured frames.
pub fn Trace::length(self : Trace) -> Int {
  self.entries.length()
}

///|
/// The capture timestamp in microseconds.
pub fn TraceEntry::timestamp(self : TraceEntry) -> UInt64 {
  self.timestamp_us
}

///|
/// The captured frame.
pub fn TraceEntry::frame(self : TraceEntry) -> Frame {
  self.frame
}

///|
/// Replay frames to a virtual bus, preserving capture order.
pub fn Trace::replay(self : Trace, bus : VirtualBus) -> Int {
  let mut delivered = 0
  for entry in self.entries {
    if bus.publish(entry.frame) {
      delivered += 1
    }
  }
  delivered
}
