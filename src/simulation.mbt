///|
/// Errors raised by deterministic network simulation.
pub suberror SimulationError {
  TimeWentBackwards
  InvalidPeriod
  EventLimitReached
} derive(Debug)

///|
/// A frame scheduled for a simulated bus time.
pub struct ScheduledFrame {
  timestamp_us : UInt64
  frame : Frame
  source : String
}

///|
/// A periodic publisher registered with a simulation.
pub struct PeriodicPublisher {
  source : String
  frame : Frame
  period_us : UInt64
  mut remaining : Int
}

///|
/// Counters produced by a deterministic simulation run.
pub struct SimulationReport {
  start_us : UInt64
  end_us : UInt64
  scheduled : Int
  delivered : Int
  dropped : Int
  arbitration_bits : UInt64
}

///|
/// A deterministic, single-threaded CAN network model.
pub struct Simulation {
  mut now_us : UInt64
  bus : VirtualBus
  events : Array[ScheduledFrame]
  publishers : Array[PeriodicPublisher]
  trace : Trace
  mut scheduled : Int
  mut delivered : Int
  mut dropped : Int
  mut arbitration_bits : UInt64
  bitrate_kbps : UInt
}

///|
/// Create a simulation with a bounded or unbounded receive queue.
pub fn new_simulation(capacity : Int, bitrate_kbps : UInt) -> Simulation {
  let bus = new_bus(capacity)
  let filters = new_filter_bank()
  filters.add(mask_filter(0, 0))
  bus.set_filters(filters)
  {
    now_us: 0,
    bus,
    events: [],
    publishers: [],
    trace: new_trace(),
    scheduled: 0,
    delivered: 0,
    dropped: 0,
    arbitration_bits: 0,
    bitrate_kbps,
  }
}

///|
pub fn Simulation::now(self : Simulation) -> UInt64 {
  self.now_us
}

///|
pub fn Simulation::pending_events(self : Simulation) -> Int {
  self.events.length()
}

///|
pub fn Simulation::bus(self : Simulation) -> VirtualBus {
  self.bus
}

///|
/// Schedule a frame at an absolute microsecond timestamp.
pub fn Simulation::schedule(
  self : Simulation,
  timestamp_us : UInt64,
  frame : Frame,
  source? : String = "anonymous",
) -> Unit raise SimulationError {
  if timestamp_us < self.now_us {
    raise TimeWentBackwards
  }
  self.events.push({ timestamp_us, frame, source })
  self.events.sort_by((left, right) => compare_events(left, right))
  self.scheduled += 1
}

///|
/// Register a periodic publisher and schedule its first event.
pub fn Simulation::add_periodic(
  self : Simulation,
  source : String,
  frame : Frame,
  first_timestamp_us : UInt64,
  period_us : UInt64,
  count : Int,
) -> Unit raise SimulationError {
  if period_us == 0 || count < 0 {
    raise InvalidPeriod
  }
  self.publishers.push({ source, frame, period_us, remaining: count })
  if count > 0 {
    self.schedule(first_timestamp_us, frame, source~)
  }
}

///|
/// Execute the next event and deliver it through the virtual bus.
pub fn Simulation::step(self : Simulation) -> ScheduledFrame? {
  if self.events.is_empty() {
    return None
  }
  let event = self.events.remove(0)
  self.now_us = event.timestamp_us
  self.trace.record(event.timestamp_us, event.frame)
  self.arbitration_bits += frame_wire_bits(event.frame).to_uint64()
  if self.bus.publish(event.frame) {
    self.delivered += 1
  } else {
    self.dropped += 1
  }
  self.reschedule_periodic(event)
  Some(event)
}

///|
/// Execute events up to an inclusive timestamp.
pub fn Simulation::run_until(
  self : Simulation,
  end_us : UInt64,
) -> Int raise SimulationError {
  if end_us < self.now_us {
    raise TimeWentBackwards
  }
  let mut count = 0
  while self.events.length() > 0 {
    match self.events.get(0) {
      Some(event) => {
        if event.timestamp_us > end_us {
          break
        }
        ignore(self.step())
        count += 1
      }
      None => break
    }
  }
  self.now_us = end_us
  count
}

///|
/// Execute at most `limit` events.
pub fn Simulation::run_steps(
  self : Simulation,
  limit : Int,
) -> Int raise SimulationError {
  if limit < 0 {
    raise EventLimitReached
  }
  let mut count = 0
  while count < limit && self.events.length() > 0 {
    ignore(self.step())
    count += 1
  }
  count
}

///|
/// Drain the highest-priority frame ready at the current time.
pub fn Simulation::receive(self : Simulation) -> Frame? {
  self.bus.receive()
}

///|
/// Return the captured trace.
pub fn Simulation::trace(self : Simulation) -> Trace {
  self.trace
}

///|
/// Return a summary of the run so far.
pub fn Simulation::report(
  self : Simulation,
  start_us : UInt64,
) -> SimulationReport {
  {
    start_us,
    end_us: self.now_us,
    scheduled: self.scheduled,
    delivered: self.delivered,
    dropped: self.dropped,
    arbitration_bits: self.arbitration_bits,
  }
}

///|
pub fn SimulationReport::scheduled(self : SimulationReport) -> Int {
  self.scheduled
}

///|
pub fn SimulationReport::delivered(self : SimulationReport) -> Int {
  self.delivered
}

///|
pub fn SimulationReport::dropped(self : SimulationReport) -> Int {
  self.dropped
}

///|
pub fn SimulationReport::duration_us(self : SimulationReport) -> UInt64 {
  self.end_us - self.start_us
}

///|
pub fn SimulationReport::arbitration_bits(self : SimulationReport) -> UInt64 {
  self.arbitration_bits
}

///|
pub fn ScheduledFrame::timestamp(self : ScheduledFrame) -> UInt64 {
  self.timestamp_us
}

///|
pub fn ScheduledFrame::frame(self : ScheduledFrame) -> Frame {
  self.frame
}

///|
pub fn ScheduledFrame::source(self : ScheduledFrame) -> String {
  self.source
}

///|
fn compare_events(left : ScheduledFrame, right : ScheduledFrame) -> Int {
  if left.timestamp_us < right.timestamp_us {
    -1
  } else if left.timestamp_us > right.timestamp_us {
    1
  } else {
    compare_frames(left.frame, right.frame)
  }
}

///|
fn Simulation::reschedule_periodic(
  self : Simulation,
  event : ScheduledFrame,
) -> Unit {
  for index in 0..<self.publishers.length() {
    let publisher = self.publishers[index]
    if publisher.source == event.source &&
      frame_equal(publisher.frame, event.frame) &&
      publisher.remaining > 0 {
      self.publishers[index].remaining -= 1
      if self.publishers[index].remaining > 0 {
        let next_time = event.timestamp_us + publisher.period_us
        self.events.push({
          timestamp_us: next_time,
          frame: publisher.frame,
          source: publisher.source,
        })
        self.events.sort_by((left, right) => compare_events(left, right))
        self.scheduled += 1
      }
    }
  }
}
