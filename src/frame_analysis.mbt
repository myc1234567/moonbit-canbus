///|
/// A compact analysis of identifier and payload behavior.
pub struct FrameAnalysis {
  unique_ids : Int
  changed_payloads : Int
  repeated_payloads : Int
  average_payload : Double
  minimum_gap_us : UInt64?
  maximum_gap_us : UInt64?
}

///|
/// Analyze adjacent frames in capture order.
pub fn analyze_trace(trace : Trace) -> FrameAnalysis {
  let entries = trace.entries()
  let ids : Array[UInt] = []
  let mut changed = 0
  let mut repeated = 0
  let mut payload_total = 0
  let mut previous_frame : Frame? = None
  let mut previous_time : UInt64? = None
  let mut minimum_gap : UInt64? = None
  let mut maximum_gap : UInt64? = None
  for entry in entries {
    ids.push(entry.frame.id())
    payload_total += entry.frame.data().length()
    match previous_frame {
      Some(frame) =>
        if frame.data() == entry.frame.data() {
          repeated += 1
        } else {
          changed += 1
        }
      None => ()
    }
    match previous_time {
      Some(timestamp) => {
        let gap = entry.timestamp_us - timestamp
        match minimum_gap {
          Some(value) => if gap < value { minimum_gap = Some(gap) }
          None => minimum_gap = Some(gap)
        }
        match maximum_gap {
          Some(value) => if gap > value { maximum_gap = Some(gap) }
          None => maximum_gap = Some(gap)
        }
      }
      None => ()
    }
    previous_frame = Some(entry.frame)
    previous_time = Some(entry.timestamp_us)
  }
  ids.sort()
  ids.dedup()
  {
    unique_ids: ids.length(),
    changed_payloads: changed,
    repeated_payloads: repeated,
    average_payload: if entries.is_empty() {
      0.0
    } else {
      payload_total.to_double() / entries.length().to_double()
    },
    minimum_gap_us: minimum_gap,
    maximum_gap_us: maximum_gap,
  }
}

///|
pub fn FrameAnalysis::unique_ids(self : FrameAnalysis) -> Int {
  self.unique_ids
}

///|
pub fn FrameAnalysis::changed_payloads(self : FrameAnalysis) -> Int {
  self.changed_payloads
}

///|
pub fn FrameAnalysis::repeated_payloads(self : FrameAnalysis) -> Int {
  self.repeated_payloads
}

///|
pub fn FrameAnalysis::average_payload(self : FrameAnalysis) -> Double {
  self.average_payload
}

///|
pub fn FrameAnalysis::minimum_gap(self : FrameAnalysis) -> UInt64? {
  self.minimum_gap_us
}

///|
pub fn FrameAnalysis::maximum_gap(self : FrameAnalysis) -> UInt64? {
  self.maximum_gap_us
}

///|
pub fn FrameAnalysis::to_text(self : FrameAnalysis) -> String {
  "unique_ids=\{self.unique_ids} changed=\{self.changed_payloads} repeated=\{self.repeated_payloads} average_payload=\{self.average_payload}"
}
