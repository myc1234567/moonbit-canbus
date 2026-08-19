///|
/// Health levels for a monitored CAN channel.
pub enum BusHealthState {
  Healthy
  Busy
  Degraded
  Overloaded
  Silent
} derive(Debug)

///|
/// A deterministic health assessment for dashboards and CI.
pub struct BusHealth {
  state : BusHealthState
  utilization : Double
  drop_rate : Double
  error_rate : Double
  recommendations : Array[String]
}

///|
/// Assess health from frame metrics and virtual-bus counters.
pub fn assess_bus_health(
  metrics : FrameMetrics,
  dropped : Int,
  duration_us : UInt64,
  bitrate_kbps : UInt,
) -> BusHealth {
  let utilization = bus_utilization(metrics, duration_us, bitrate_kbps)
  let total = metrics.total()
  let drop_rate = if total == 0 {
    0.0
  } else {
    dropped.to_double() / total.to_double()
  }
  let error_rate = if total == 0 {
    0.0
  } else {
    metrics.errors().to_double() / total.to_double()
  }
  let recommendations : Array[String] = []
  let state = if total == 0 {
    Silent
  } else if drop_rate > 0.05 || utilization > 1.0 {
    recommendations.push("reduce load or increase receive capacity")
    Overloaded
  } else if error_rate > 0.01 {
    recommendations.push("inspect error frames and physical layer")
    Degraded
  } else if utilization > 0.7 {
    recommendations.push("monitor arbitration latency")
    Busy
  } else {
    Healthy
  }
  { state, utilization, drop_rate, error_rate, recommendations }
}

///|
pub fn BusHealth::state(self : BusHealth) -> BusHealthState {
  self.state
}

///|
pub fn BusHealth::utilization(self : BusHealth) -> Double {
  self.utilization
}

///|
pub fn BusHealth::drop_rate(self : BusHealth) -> Double {
  self.drop_rate
}

///|
pub fn BusHealth::error_rate(self : BusHealth) -> Double {
  self.error_rate
}

///|
pub fn BusHealth::recommendations(self : BusHealth) -> Array[String] {
  self.recommendations.copy()
}

///|
pub fn bus_health_name(state : BusHealthState) -> String {
  match state {
    Healthy => "healthy"
    Busy => "busy"
    Degraded => "degraded"
    Overloaded => "overloaded"
    Silent => "silent"
  }
}

///|
pub fn BusHealth::to_text(self : BusHealth) -> String {
  "state=\{bus_health_name(self.state)} utilization=\{self.utilization} drop_rate=\{self.drop_rate} error_rate=\{self.error_rate}"
}
