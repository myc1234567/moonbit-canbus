///|
/// Errors raised by the bounded transmit queue.
pub suberror QueueError {
  InvalidCapacity
  InvalidLimit
  Full
  Empty
  UnknownSequence
} derive(Debug)

///|
/// A queued frame with timing and channel metadata.
pub struct QueueItem {
  sequence : UInt
  channel : Byte
  frame : Frame
  enqueued_us : UInt64
  deadline_us : UInt64
}

///|
/// A deterministic priority queue for CAN transmit pipelines.
pub struct FrameQueue {
  capacity : Int
  mut next_sequence : UInt
  items : Array[QueueItem]
  mut dropped : Int
}

///|
/// Create a queue. Capacity zero means unlimited buffering.
pub fn new_frame_queue(capacity : Int) -> FrameQueue raise QueueError {
  if capacity < 0 {
    raise InvalidCapacity
  }
  { capacity, next_sequence: 1, items: [], dropped: 0 }
}

///|
/// Add a frame and return its monotonic sequence number.
pub fn FrameQueue::enqueue(
  self : FrameQueue,
  channel : Byte,
  frame : Frame,
  enqueued_us : UInt64,
  deadline_us : UInt64,
) -> UInt raise QueueError {
  if deadline_us > 0 && deadline_us < enqueued_us {
    raise InvalidLimit
  }
  if self.capacity > 0 && self.items.length() >= self.capacity {
    self.dropped += 1
    raise Full
  }
  let sequence = self.next_sequence
  self.next_sequence = if sequence == 0xFFFFFFFF { 1 } else { sequence + 1 }
  self.items.push({ sequence, channel, frame, enqueued_us, deadline_us })
  sort_queue_items(self.items)
  sequence
}

///|
/// Return the highest-priority item without removing it.
pub fn FrameQueue::peek(self : FrameQueue) -> QueueItem? {
  if self.items.is_empty() {
    None
  } else {
    Some(self.items[0])
  }
}

///|
/// Remove the highest-priority item.
pub fn FrameQueue::dequeue(self : FrameQueue) -> QueueItem raise QueueError {
  if self.items.is_empty() {
    raise Empty
  }
  self.items.remove(0)
}

///|
/// Remove a particular sequence number.
pub fn FrameQueue::remove(
  self : FrameQueue,
  sequence : UInt,
) -> QueueItem raise QueueError {
  for index in 0..<self.items.length() {
    if self.items[index].sequence == sequence {
      return self.items.remove(index)
    }
  }
  raise UnknownSequence
}

///|
/// Remove items whose deadline has expired at `now_us`.
pub fn FrameQueue::expire(
  self : FrameQueue,
  now_us : UInt64,
) -> Array[QueueItem] {
  let expired : Array[QueueItem] = []
  let mut index = 0
  while index < self.items.length() {
    let item = self.items[index]
    if item.deadline_us > 0 && item.deadline_us <= now_us {
      expired.push(self.items.remove(index))
    } else {
      index += 1
    }
  }
  expired
}

///|
/// Take up to `limit` items for one logical channel.
pub fn FrameQueue::take_channel(
  self : FrameQueue,
  channel : Byte,
  limit : Int,
) -> Array[QueueItem] raise QueueError {
  if limit < 0 {
    raise InvalidLimit
  }
  let result : Array[QueueItem] = []
  if limit == 0 {
    return result
  }
  let mut index = 0
  while index < self.items.length() && result.length() < limit {
    if self.items[index].channel == channel {
      result.push(self.items.remove(index))
    } else {
      index += 1
    }
  }
  result
}

///|
/// Remove every pending item.
pub fn FrameQueue::clear(self : FrameQueue) -> Unit {
  self.items.clear()
}

///|
pub fn FrameQueue::length(self : FrameQueue) -> Int {
  self.items.length()
}

///|
pub fn FrameQueue::is_empty(self : FrameQueue) -> Bool {
  self.items.is_empty()
}

///|
pub fn FrameQueue::is_full(self : FrameQueue) -> Bool {
  self.capacity > 0 && self.items.length() >= self.capacity
}

///|
pub fn FrameQueue::capacity(self : FrameQueue) -> Int {
  self.capacity
}

///|
pub fn FrameQueue::dropped(self : FrameQueue) -> Int {
  self.dropped
}

///|
pub fn FrameQueue::snapshot(self : FrameQueue) -> Array[QueueItem] {
  self.items.copy()
}

///|
pub fn QueueItem::sequence(self : QueueItem) -> UInt {
  self.sequence
}

///|
pub fn QueueItem::channel(self : QueueItem) -> Byte {
  self.channel
}

///|
pub fn QueueItem::frame(self : QueueItem) -> Frame {
  self.frame
}

///|
pub fn QueueItem::enqueued_at(self : QueueItem) -> UInt64 {
  self.enqueued_us
}

///|
pub fn QueueItem::deadline(self : QueueItem) -> UInt64 {
  self.deadline_us
}

///|
fn sort_queue_items(items : Array[QueueItem]) -> Unit {
  for index in 1..<items.length() {
    let current = items[index]
    let mut position = index
    while position > 0 && compare_queue_items(current, items[position - 1]) < 0 {
      items[position] = items[position - 1]
      position -= 1
    }
    items[position] = current
  }
}

///|
fn compare_queue_items(left : QueueItem, right : QueueItem) -> Int {
  let frame_order = compare_frames(left.frame, right.frame)
  if frame_order != 0 {
    frame_order
  } else if left.enqueued_us < right.enqueued_us {
    -1
  } else if left.enqueued_us > right.enqueued_us {
    1
  } else if left.sequence < right.sequence {
    -1
  } else if left.sequence > right.sequence {
    1
  } else {
    0
  }
}
