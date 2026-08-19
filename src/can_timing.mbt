///|
/// Errors raised by CAN bit-timing calculations.
pub suberror CanTimingError {
  InvalidClock
  InvalidBitrate
  InvalidSamplePoint
  NoTimingCandidate
} derive(Debug)

///|
/// A nominal or data-phase bit-timing candidate.
pub struct CanBitTiming {
  clock_hz : UInt
  bitrate : UInt
  prescaler : UInt
  time_quanta : UInt
  propagation_segment : UInt
  phase_segment_1 : UInt
  phase_segment_2 : UInt
  sample_point_percent : Double
}

///|
/// Calculate a practical timing candidate using an integer clock divider.
pub fn calculate_bit_timing(
  clock_hz : UInt,
  bitrate : UInt,
  sample_point_percent : Double,
) -> CanBitTiming raise CanTimingError {
  if clock_hz == 0 {
    raise InvalidClock
  }
  if bitrate == 0 {
    raise InvalidBitrate
  }
  if sample_point_percent <= 50.0 || sample_point_percent >= 100.0 {
    raise InvalidSamplePoint
  }
  let mut best : CanBitTiming? = None
  let mut best_error = 1.0e30
  for prescaler in 1..<=1024 {
    let prescaler_u = prescaler.reinterpret_as_uint()
    let divider = bitrate * prescaler_u
    if divider == 0 || clock_hz % divider != 0 {
      continue
    }
    let quanta = clock_hz / divider
    if quanta < 8 || quanta > 80 {
      continue
    }
    let desired_phase_one = quanta.to_double() * sample_point_percent / 100.0
    let mut phase_one : UInt = 2
    for candidate in 2..<=80 {
      if candidate.to_double() <= desired_phase_one {
        phase_one = candidate.reinterpret_as_uint()
      }
    }
    if phase_one >= quanta - 2 {
      continue
    }
    let phase_two = quanta - phase_one
    let actual_sample = phase_one.to_double() * 100.0 / quanta.to_double()
    let error = (actual_sample - sample_point_percent).abs()
    if error < best_error {
      best_error = error
      best = Some({
        clock_hz,
        bitrate,
        prescaler: prescaler_u,
        time_quanta: quanta,
        propagation_segment: 1,
        phase_segment_1: phase_one - 1,
        phase_segment_2: phase_two,
        sample_point_percent: actual_sample,
      })
    }
  }
  match best {
    Some(value) => value
    None => raise NoTimingCandidate
  }
}

///|
pub fn CanBitTiming::clock_hz(self : CanBitTiming) -> UInt {
  self.clock_hz
}

///|
pub fn CanBitTiming::bitrate(self : CanBitTiming) -> UInt {
  self.bitrate
}

///|
pub fn CanBitTiming::prescaler(self : CanBitTiming) -> UInt {
  self.prescaler
}

///|
pub fn CanBitTiming::time_quanta(self : CanBitTiming) -> UInt {
  self.time_quanta
}

///|
pub fn CanBitTiming::sample_point(self : CanBitTiming) -> Double {
  self.sample_point_percent
}

///|
pub fn CanBitTiming::bit_time_ns(self : CanBitTiming) -> UInt64 {
  1_000_000_000 / self.bitrate.to_uint64()
}

///|
/// CAN-FD timing for nominal and data phases.
pub struct CanFdTiming {
  nominal : CanBitTiming
  data : CanBitTiming
}

///|
pub fn can_fd_timing(
  nominal : CanBitTiming,
  data : CanBitTiming,
) -> CanFdTiming raise CanTimingError {
  if data.bitrate() < nominal.bitrate() {
    raise InvalidBitrate
  }
  { nominal, data }
}

///|
pub fn CanFdTiming::nominal(self : CanFdTiming) -> CanBitTiming {
  self.nominal
}

///|
pub fn CanFdTiming::data(self : CanFdTiming) -> CanBitTiming {
  self.data
}

///|
/// Estimate a frame's nominal-only transmission duration.
pub fn frame_duration_ns(frame : Frame, timing : CanBitTiming) -> UInt64 {
  frame_wire_bits(frame).to_uint64() * timing.bit_time_ns()
}

///|
/// Estimate the data-phase duration for a CAN-FD frame with BRS.
pub fn fd_frame_duration_ns(frame : Frame, timing : CanFdTiming) -> UInt64 {
  if frame.protocol() is CanFd && frame.bitrate_switch() {
    let nominal_bits = if frame.is_extended() { 70 } else { 50 }
    let data_bits = frame.data().length() * 8 +
      (if frame.data().length() <= 16 { 17 } else { 21 })
    nominal_bits.to_uint64() * timing.nominal.bit_time_ns() +
    data_bits.to_uint64() * timing.data.bit_time_ns()
  } else {
    frame_duration_ns(frame, timing.nominal)
  }
}

///|
/// Return the actual bitrate represented by a timing configuration.
pub fn CanBitTiming::actual_bitrate(self : CanBitTiming) -> UInt {
  self.clock_hz / (self.prescaler * self.time_quanta)
}
