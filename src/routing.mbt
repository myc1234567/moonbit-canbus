///|
/// Errors raised when a gateway transforms a frame.
pub suberror RoutingError {
  InvalidOutputIdentifier
  InvalidPrefix
  PayloadOverflow
} derive(Debug)

///|
/// A deterministic one-way gateway rule.
pub struct RouteRule {
  name : String
  filter : Filter
  output_id : UInt?
  output_extended : Bool?
  prefix : Array[Byte]
  strip_prefix : Int
}

///|
/// A frame accepted and transformed by a route.
pub struct RoutedFrame {
  rule_name : String
  input_id : UInt
  frame : Frame
}

///|
/// A stateless rule-based CAN gateway.
pub struct CanGateway {
  routes : Array[RouteRule]
  mut forwarded : Int
  mut rejected : Int
}

///|
/// Create an empty gateway.
pub fn new_gateway() -> CanGateway {
  { routes: [], forwarded: 0, rejected: 0 }
}

///|
/// Construct a route rule with optional identifier and payload rewrites.
pub fn route_rule(
  name : String,
  filter : Filter,
  output_id? : UInt? = None,
  output_extended? : Bool? = None,
  prefix? : Array[Byte] = [],
  strip_prefix? : Int = 0,
) -> RouteRule raise RoutingError {
  if strip_prefix < 0 || strip_prefix > 64 {
    raise InvalidPrefix
  }
  {
    name,
    filter,
    output_id,
    output_extended,
    prefix: prefix.copy(),
    strip_prefix,
  }
}

///|
pub fn CanGateway::add_rule(self : CanGateway, rule : RouteRule) -> Unit {
  self.routes.push(rule)
}

///|
pub fn CanGateway::rule_count(self : CanGateway) -> Int {
  self.routes.length()
}

///|
/// Return route names in insertion order.
pub fn CanGateway::rule_names(self : CanGateway) -> Array[String] {
  self.routes.map(rule => rule.name)
}

///|
/// Apply the first matching rule.
pub fn CanGateway::forward(
  self : CanGateway,
  input : Frame,
) -> RoutedFrame? raise RoutingError {
  for rule in self.routes {
    if rule.filter.matches(input) {
      let original = input.id()
      let data = input.data()
      if rule.strip_prefix > data.length() {
        self.rejected += 1
        raise InvalidPrefix
      }
      let output_data = rule.prefix + data[rule.strip_prefix:].to_owned()
      let output_id = match rule.output_id {
        Some(id) => id
        None => input.id()
      }
      let extended = match rule.output_extended {
        Some(value) => value
        None => input.is_extended()
      }
      let frame = match input.kind() {
        Remote =>
          remote_frame(output_id, extended~) catch {
            _ => {
              self.rejected += 1
              raise InvalidOutputIdentifier
            }
          }
        Error =>
          error_frame(if output_data.is_empty() { 0 } else { output_data[0] })
        Data =>
          match input.protocol() {
            Can20 =>
              data_frame(output_id, output_data, extended~) catch {
                _ => {
                  self.rejected += 1
                  raise PayloadOverflow
                }
              }
            CanFd =>
              fd_frame(
                output_id,
                output_data,
                extended~,
                bitrate_switch=input.bitrate_switch(),
                error_state_indicator=input.error_state_indicator(),
              ) catch {
                _ => {
                  self.rejected += 1
                  raise PayloadOverflow
                }
              }
          }
      }
      self.forwarded += 1
      return Some({ rule_name: rule.name, input_id: original, frame })
    }
  }
  self.rejected += 1
  None
}

///|
pub fn CanGateway::forwarded(self : CanGateway) -> Int {
  self.forwarded
}

///|
pub fn CanGateway::rejected(self : CanGateway) -> Int {
  self.rejected
}

///|
pub fn RoutedFrame::rule_name(self : RoutedFrame) -> String {
  self.rule_name
}

///|
pub fn RoutedFrame::input_id(self : RoutedFrame) -> UInt {
  self.input_id
}

///|
pub fn RoutedFrame::frame(self : RoutedFrame) -> Frame {
  self.frame
}

///|
/// Route a batch and keep only successfully forwarded frames.
pub fn route_batch(
  gateway : CanGateway,
  frames : Array[Frame],
) -> Array[RoutedFrame] raise RoutingError {
  let result : Array[RoutedFrame] = []
  for frame in frames {
    match gateway.forward(frame) {
      Some(routed) => result.push(routed)
      None => ()
    }
  }
  result
}

///|
/// Create a bidirectional bridge from two gateways.
pub struct GatewayPair {
  left_to_right : CanGateway
  right_to_left : CanGateway
}

///|
pub fn gateway_pair(
  left_to_right : CanGateway,
  right_to_left : CanGateway,
) -> GatewayPair {
  { left_to_right, right_to_left }
}

///|
pub fn GatewayPair::left(self : GatewayPair) -> CanGateway {
  self.left_to_right
}

///|
pub fn GatewayPair::right(self : GatewayPair) -> CanGateway {
  self.right_to_left
}

///|
/// Return a route's stable name.
pub fn RouteRule::name(self : RouteRule) -> String {
  self.name
}

///|
/// Return the rule's payload prefix.
pub fn RouteRule::prefix(self : RouteRule) -> Array[Byte] {
  self.prefix.copy()
}
