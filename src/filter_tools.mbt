///|
/// Return a filter's identifier pattern.
pub fn Filter::id(self : Filter) -> UInt {
  self.id
}

///|
pub fn Filter::mask(self : Filter) -> UInt {
  self.mask
}

///|
pub fn Filter::extended(self : Filter) -> Bool? {
  self.extended
}

///|
/// Validate a filter against the selected identifier width.
pub fn filter_is_valid(filter : Filter) -> Bool {
  filter.id <= 0x1FFFFFFF && filter.mask <= 0x1FFFFFFF
}

///|
pub fn FilterBank::length(self : FilterBank) -> Int {
  self.filters.length()
}

///|
pub fn FilterBank::filters(self : FilterBank) -> Array[Filter] {
  self.filters.copy()
}

///|
/// Return all filters that match a frame.
pub fn matching_filters(bank : FilterBank, frame : Frame) -> Array[Filter] {
  bank.filters.filter(filter => filter.matches(frame))
}

///|
/// Return whether all filters in a bank are valid.
pub fn filter_bank_is_valid(bank : FilterBank) -> Bool {
  bank.filters.all(filter => filter_is_valid(filter))
}

///|
/// A compact exact-or-mask index for a monitoring application.
pub struct FilterIndex {
  bank : FilterBank
  mut accepted : Int
  mut rejected : Int
}

///|
pub fn new_filter_index(bank : FilterBank) -> FilterIndex {
  { bank, accepted: 0, rejected: 0 }
}

///|
pub fn FilterIndex::check(self : FilterIndex, frame : Frame) -> Bool {
  if self.bank.accepts(frame) {
    self.accepted += 1
    true
  } else {
    self.rejected += 1
    false
  }
}

///|
pub fn FilterIndex::accepted(self : FilterIndex) -> Int {
  self.accepted
}

///|
pub fn FilterIndex::rejected(self : FilterIndex) -> Int {
  self.rejected
}
