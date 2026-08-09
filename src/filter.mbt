///|
/// A CAN acceptance filter.
pub struct Filter {
  id : UInt
  mask : UInt
  extended : Bool?
}

///|
/// Match an exact identifier.
pub fn exact_filter(id : UInt, extended? : Bool = false) -> Filter {
  { id, mask: 0x1FFFFFFF, extended: Some(extended) }
}

///|
/// Match identifier bits selected by a mask.
pub fn mask_filter(id : UInt, mask : UInt, extended? : Bool? = None) -> Filter {
  { id, mask, extended }
}

///|
/// Return whether a frame passes this filter.
pub fn Filter::matches(self : Filter, frame : Frame) -> Bool {
  let kind_matches = match self.extended {
    None => true
    Some(wanted) => wanted == frame.is_extended()
  }
  kind_matches && (frame.id() & self.mask) == (self.id & self.mask)
}

///|
/// A group of filters evaluated in insertion order.
pub struct FilterBank {
  filters : Array[Filter]
}

///|
/// Create an empty filter bank.
pub fn new_filter_bank() -> FilterBank {
  { filters: [] }
}

///|
/// Add a filter to the bank.
pub fn FilterBank::add(self : FilterBank, filter : Filter) -> Unit {
  self.filters.push(filter)
}

///|
/// Test whether any filter accepts a frame. An empty bank rejects all frames.
pub fn FilterBank::accepts(self : FilterBank, frame : Frame) -> Bool {
  for filter in self.filters {
    if filter.matches(frame) {
      return true
    }
  }
  false
}

///|
/// A deterministic in-memory CAN bus.
pub struct VirtualBus {
  capacity : Int
  queue : Array[Frame]
  mut filters : FilterBank
  mut dropped : Int
}

///|
/// Create a bus. A zero capacity means an unbounded queue.
pub fn new_bus(capacity : Int) -> VirtualBus {
  { capacity, queue: [], filters: new_filter_bank(), dropped: 0 }
}

///|
/// Configure the receiver acceptance filters.
pub fn VirtualBus::filters(self : VirtualBus) -> FilterBank {
  self.filters
}

///|
/// Replace all acceptance filters.
pub fn VirtualBus::set_filters(self : VirtualBus, filters : FilterBank) -> Unit {
  self.filters = filters
}

///|
/// Publish a frame. The queue is ordered by arbitration priority.
pub fn VirtualBus::publish(self : VirtualBus, frame : Frame) -> Bool {
  if !self.filters.accepts(frame) {
    return false
  }
  if self.capacity > 0 && self.queue.length() >= self.capacity {
    self.dropped += 1
    return false
  }
  self.queue.push(frame)
  sort_queue(self.queue)
  true
}

///|
fn sort_queue(queue : Array[Frame]) -> Unit {
  for i in 1..<queue.length() {
    let current = queue[i]
    let mut j = i
    while j > 0 && queue[j - 1].id() > current.id() {
      queue[j] = queue[j - 1]
      j -= 1
    }
    queue[j] = current
  }
}

///|
/// Receive and remove the highest-priority pending frame.
pub fn VirtualBus::receive(self : VirtualBus) -> Frame? {
  if self.queue.is_empty() {
    None
  } else {
    Some(self.queue.remove(0))
  }
}

///|
/// Number of pending frames.
pub fn VirtualBus::pending(self : VirtualBus) -> Int {
  self.queue.length()
}

///|
/// Number of dropped frames.
pub fn VirtualBus::dropped(self : VirtualBus) -> Int {
  self.dropped
}
