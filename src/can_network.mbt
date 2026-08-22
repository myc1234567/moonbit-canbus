///|
/// Errors raised by the deterministic multi-node network model.
pub suberror NetworkError {
  InvalidNodeId
  DuplicateNode
  UnknownNode
  InvalidTimestamp
  QueueFull
} derive(Debug)

///|
/// A node registered with the network model.
pub struct NetworkNode {
  node_id : Byte
  name : String
  mut last_seen_us : UInt64
  mut online : Bool
  mut transmitted : Int
  mut received : Int
}

///|
/// One broadcast delivery produced by `CanNetwork::poll`.
pub struct NetworkDelivery {
  timestamp_us : UInt64
  sender : Byte
  frame : Frame
  recipients : Array[String]
}

///|
/// A deterministic CAN network with bounded transmit buffering and liveness.
pub struct CanNetwork {
  timeout_us : UInt64
  mut now_us : UInt64
  nodes : Array[NetworkNode]
  queue : FrameQueue
  mut delivered : Int
}

///|
/// Create a network. A zero timeout disables automatic offline detection.
pub fn new_can_network(
  timeout_us? : UInt64 = 100_000,
  queue_capacity? : Int = 0,
) -> CanNetwork raise QueueError {
  {
    timeout_us,
    now_us: 0,
    nodes: [],
    queue: new_frame_queue(queue_capacity),
    delivered: 0,
  }
}

///|
/// Register a node at a known timestamp.
pub fn CanNetwork::add_node(
  self : CanNetwork,
  node_id : Byte,
  name : String,
  timestamp_us : UInt64,
) -> Unit raise NetworkError {
  if node_id == 0 || node_id > 127 {
    raise InvalidNodeId
  }
  if self.find_index(node_id) is Some(_) {
    raise DuplicateNode
  }
  if timestamp_us < self.now_us {
    raise InvalidTimestamp
  }
  self.now_us = timestamp_us
  self.nodes.push({
    node_id,
    name,
    last_seen_us: timestamp_us,
    online: true,
    transmitted: 0,
    received: 0,
  })
}

///|
/// Record a heartbeat and bring a node online.
pub fn CanNetwork::heartbeat(
  self : CanNetwork,
  node_id : Byte,
  timestamp_us : UInt64,
) -> Unit raise NetworkError {
  if timestamp_us < self.now_us {
    raise InvalidTimestamp
  }
  self.now_us = timestamp_us
  match self.find_index(node_id) {
    Some(index) => {
      self.nodes[index].last_seen_us = timestamp_us
      self.nodes[index].online = true
    }
    None => raise UnknownNode
  }
}

///|
/// Queue a frame from a registered sender.
pub fn CanNetwork::send(
  self : CanNetwork,
  sender : Byte,
  frame : Frame,
  timestamp_us : UInt64,
) -> UInt raise NetworkError {
  if timestamp_us < self.now_us {
    raise InvalidTimestamp
  }
  let index = match self.find_index(sender) {
    Some(value) => value
    None => raise UnknownNode
  }
  self.now_us = timestamp_us
  self.nodes[index].transmitted += 1
  self.queue.enqueue(sender, frame, timestamp_us, 0) catch {
    QueueError::Full => raise QueueFull
    _ => raise QueueFull
  }
}

///|
/// Deliver every frame queued by `timestamp_us` in arbitration order.
pub fn CanNetwork::poll(
  self : CanNetwork,
  timestamp_us : UInt64,
) -> Array[NetworkDelivery] raise NetworkError {
  if timestamp_us < self.now_us {
    raise InvalidTimestamp
  }
  self.now_us = timestamp_us
  self.refresh_liveness(timestamp_us)
  let deliveries : Array[NetworkDelivery] = []
  while true {
    match self.queue.peek() {
      Some(item) => {
        if item.enqueued_at() > timestamp_us {
          break
        }
        let queued = self.queue.dequeue() catch { _ => break }
        let recipients : Array[String] = []
        for index in 0..<self.nodes.length() {
          if self.nodes[index].node_id != queued.channel() &&
            self.nodes[index].online {
            self.nodes[index].received += 1
            recipients.push(self.nodes[index].name)
          }
        }
        self.delivered += 1
        deliveries.push({
          timestamp_us,
          sender: queued.channel(),
          frame: queued.frame(),
          recipients,
        })
      }
      None => break
    }
  }
  deliveries
}

///|
/// Mark nodes stale at a timestamp and return their stable names.
pub fn CanNetwork::offline_nodes(
  self : CanNetwork,
  timestamp_us : UInt64,
) -> Array[String] raise NetworkError {
  if timestamp_us < self.now_us {
    raise InvalidTimestamp
  }
  self.now_us = timestamp_us
  self.refresh_liveness(timestamp_us)
  let result : Array[String] = []
  for node in self.nodes {
    if !node.online {
      result.push(node.name)
    }
  }
  result
}

///|
pub fn CanNetwork::node(self : CanNetwork, node_id : Byte) -> NetworkNode? {
  match self.find_index(node_id) {
    Some(index) => Some(self.nodes[index])
    None => None
  }
}

///|
pub fn CanNetwork::node_count(self : CanNetwork) -> Int {
  self.nodes.length()
}

///|
pub fn CanNetwork::pending(self : CanNetwork) -> Int {
  self.queue.length()
}

///|
pub fn CanNetwork::now(self : CanNetwork) -> UInt64 {
  self.now_us
}

///|
pub fn CanNetwork::delivered(self : CanNetwork) -> Int {
  self.delivered
}

///|
pub fn NetworkNode::node_id(self : NetworkNode) -> Byte {
  self.node_id
}

///|
pub fn NetworkNode::name(self : NetworkNode) -> String {
  self.name
}

///|
pub fn NetworkNode::last_seen(self : NetworkNode) -> UInt64 {
  self.last_seen_us
}

///|
pub fn NetworkNode::online(self : NetworkNode) -> Bool {
  self.online
}

///|
pub fn NetworkNode::transmitted(self : NetworkNode) -> Int {
  self.transmitted
}

///|
pub fn NetworkNode::received(self : NetworkNode) -> Int {
  self.received
}

///|
pub fn NetworkDelivery::timestamp(self : NetworkDelivery) -> UInt64 {
  self.timestamp_us
}

///|
pub fn NetworkDelivery::sender(self : NetworkDelivery) -> Byte {
  self.sender
}

///|
pub fn NetworkDelivery::frame(self : NetworkDelivery) -> Frame {
  self.frame
}

///|
pub fn NetworkDelivery::recipients(self : NetworkDelivery) -> Array[String] {
  self.recipients.copy()
}

///|
fn CanNetwork::find_index(self : CanNetwork, node_id : Byte) -> Int? {
  for index in 0..<self.nodes.length() {
    if self.nodes[index].node_id == node_id {
      return Some(index)
    }
  }
  None
}

///|
fn CanNetwork::refresh_liveness(
  self : CanNetwork,
  timestamp_us : UInt64,
) -> Unit {
  if self.timeout_us == 0 {
    return
  }
  for index in 0..<self.nodes.length() {
    let elapsed = timestamp_us - self.nodes[index].last_seen_us
    self.nodes[index].online = elapsed <= self.timeout_us
  }
}
