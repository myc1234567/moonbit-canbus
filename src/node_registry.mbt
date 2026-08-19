///|
/// Errors raised by node registry operations.
pub suberror NodeRegistryError {
  InvalidNodeId
  DuplicateNode
  UnknownNode
} derive(Debug)

///|
/// A monitored node and its receive filter.
pub struct CanNode {
  node_id : Byte
  name : String
  filter : Filter
  mut received : Int
  mut transmitted : Int
}

///|
/// A registry used by simulations and gateway applications.
pub struct NodeRegistry {
  nodes : Array[CanNode]
}

///|
pub fn new_node_registry() -> NodeRegistry {
  { nodes: [] }
}

///|
pub fn NodeRegistry::register(
  self : NodeRegistry,
  node_id : Byte,
  name : String,
  filter : Filter,
) -> Unit raise NodeRegistryError {
  if node_id == 0 || node_id > 127 {
    raise InvalidNodeId
  }
  if self.find(node_id) is Some(_) {
    raise DuplicateNode
  }
  self.nodes.push({ node_id, name, filter, received: 0, transmitted: 0 })
}

///|
pub fn NodeRegistry::unregister(
  self : NodeRegistry,
  node_id : Byte,
) -> Unit raise NodeRegistryError {
  for index in 0..<self.nodes.length() {
    if self.nodes[index].node_id == node_id {
      ignore(self.nodes.remove(index))
      return
    }
  }
  raise UnknownNode
}

///|
pub fn NodeRegistry::find(self : NodeRegistry, node_id : Byte) -> CanNode? {
  for node in self.nodes {
    if node.node_id == node_id {
      return Some(node)
    }
  }
  None
}

///|
pub fn NodeRegistry::length(self : NodeRegistry) -> Int {
  self.nodes.length()
}

///|
/// Deliver a frame to every matching registered node.
pub fn NodeRegistry::deliver(
  self : NodeRegistry,
  frame : Frame,
) -> Array[String] {
  let names : Array[String] = []
  for index in 0..<self.nodes.length() {
    if self.nodes[index].filter.matches(frame) {
      self.nodes[index].received += 1
      names.push(self.nodes[index].name)
    }
  }
  names
}

///|
/// Record a transmission for a node.
pub fn NodeRegistry::record_transmission(
  self : NodeRegistry,
  node_id : Byte,
) -> Unit raise NodeRegistryError {
  match self.find_index(node_id) {
    Some(index) => self.nodes[index].transmitted += 1
    None => raise UnknownNode
  }
}

///|
pub fn CanNode::node_id(self : CanNode) -> Byte {
  self.node_id
}

///|
pub fn CanNode::name(self : CanNode) -> String {
  self.name
}

///|
pub fn CanNode::received(self : CanNode) -> Int {
  self.received
}

///|
pub fn CanNode::transmitted(self : CanNode) -> Int {
  self.transmitted
}

///|
fn NodeRegistry::find_index(self : NodeRegistry, node_id : Byte) -> Int? {
  for index in 0..<self.nodes.length() {
    if self.nodes[index].node_id == node_id {
      return Some(index)
    }
  }
  None
}
