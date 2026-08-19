///|
/// Errors raised by the deterministic message scheduler.
pub suberror SchedulerError {
  InvalidPeriod
  InvalidDeadline
  DuplicateTask
  UnknownTask
} derive(Debug)

///|
/// A periodic or one-shot transmission task.
pub struct CanTask {
  name : String
  frame : Frame
  mut next_due_us : UInt64
  period_us : UInt64
  deadline_us : UInt64
  mut remaining : Int
  priority : Int
}

///|
/// A scheduler execution result.
pub struct SchedulerTick {
  timestamp_us : UInt64
  task_name : String
  frame : Frame
  late : Bool
}

///|
/// A deterministic task scheduler independent from wall-clock time.
pub struct CanScheduler {
  tasks : Array[CanTask]
  mut now_us : UInt64
  mut executed : Int
  mut missed : Int
}

///|
pub fn new_scheduler() -> CanScheduler {
  { tasks: [], now_us: 0, executed: 0, missed: 0 }
}

///|
/// Add a task. `period_us == 0` creates a one-shot task.
pub fn CanScheduler::add(
  self : CanScheduler,
  name : String,
  frame : Frame,
  first_due_us : UInt64,
  period_us : UInt64,
  deadline_us : UInt64,
  count : Int,
) -> Unit raise SchedulerError {
  if count < 0 || (period_us == 0 && count != 1) {
    raise InvalidPeriod
  }
  if deadline_us > 0 && period_us > 0 && deadline_us > period_us {
    raise InvalidDeadline
  }
  if self.find(name) is Some(_) {
    raise DuplicateTask
  }
  self.tasks.push({
    name,
    frame,
    next_due_us: first_due_us,
    period_us,
    deadline_us,
    remaining: count,
    priority: frame.id().reinterpret_as_int(),
  })
  self.tasks.sort_by((left, right) => compare_tasks(left, right))
}

///|
pub fn CanScheduler::remove(
  self : CanScheduler,
  name : String,
) -> Unit raise SchedulerError {
  match self.find_index(name) {
    Some(index) => ignore(self.tasks.remove(index))
    None => raise UnknownTask
  }
}

///|
pub fn CanScheduler::find(self : CanScheduler, name : String) -> CanTask? {
  for task in self.tasks {
    if task.name == name {
      return Some(task)
    }
  }
  None
}

///|
pub fn CanScheduler::task_count(self : CanScheduler) -> Int {
  self.tasks.length()
}

///|
pub fn CanScheduler::now(self : CanScheduler) -> UInt64 {
  self.now_us
}

///|
/// Return the next due time among pending tasks.
pub fn CanScheduler::next_due(self : CanScheduler) -> UInt64? {
  let mut result : UInt64? = None
  for task in self.tasks {
    if task.remaining > 0 {
      match result {
        Some(value) =>
          if task.next_due_us < value {
            result = Some(task.next_due_us)
          }
        None => result = Some(task.next_due_us)
      }
    }
  }
  result
}

///|
/// Execute all tasks due by `timestamp_us`, ordered by CAN arbitration.
pub fn CanScheduler::tick(
  self : CanScheduler,
  timestamp_us : UInt64,
) -> Array[SchedulerTick] raise SchedulerError {
  if timestamp_us < self.now_us {
    raise InvalidDeadline
  }
  self.now_us = timestamp_us
  let result : Array[SchedulerTick] = []
  while true {
    match self.next_task() {
      Some(index) => {
        let task = self.tasks[index]
        if task.remaining <= 0 || task.next_due_us > timestamp_us {
          break
        }
        let late = task.deadline_us > 0 &&
          timestamp_us > task.next_due_us + task.deadline_us
        if late {
          self.missed += 1
        }
        self.executed += 1
        result.push({
          timestamp_us,
          task_name: task.name,
          frame: task.frame,
          late,
        })
        if self.tasks[index].remaining > 0 {
          self.tasks[index].remaining -= 1
        }
        if self.tasks[index].period_us > 0 && self.tasks[index].remaining > 0 {
          self.tasks[index].next_due_us += self.tasks[index].period_us
        } else {
          self.tasks[index].remaining = 0
        }
      }
      None => break
    }
  }
  result.sort_by((left, right) => compare_frames(left.frame, right.frame))
  result
}

///|
pub fn CanScheduler::executed(self : CanScheduler) -> Int {
  self.executed
}

///|
pub fn CanScheduler::missed(self : CanScheduler) -> Int {
  self.missed
}

///|
pub fn SchedulerTick::timestamp(self : SchedulerTick) -> UInt64 {
  self.timestamp_us
}

///|
pub fn SchedulerTick::task_name(self : SchedulerTick) -> String {
  self.task_name
}

///|
pub fn SchedulerTick::frame(self : SchedulerTick) -> Frame {
  self.frame
}

///|
pub fn SchedulerTick::is_late(self : SchedulerTick) -> Bool {
  self.late
}

///|
fn CanScheduler::find_index(self : CanScheduler, name : String) -> Int? {
  for index in 0..<self.tasks.length() {
    if self.tasks[index].name == name {
      return Some(index)
    }
  }
  None
}

///|
fn CanScheduler::next_task(self : CanScheduler) -> Int? {
  let mut best : Int? = None
  for index in 0..<self.tasks.length() {
    let candidate = self.tasks[index]
    if candidate.remaining <= 0 {
      continue
    }
    match best {
      Some(previous) =>
        if compare_tasks(candidate, self.tasks[previous]) < 0 {
          best = Some(index)
        }
      None => best = Some(index)
    }
  }
  best
}

///|
fn compare_tasks(left : CanTask, right : CanTask) -> Int {
  if left.next_due_us < right.next_due_us {
    -1
  } else if left.next_due_us > right.next_due_us {
    1
  } else if left.priority < right.priority {
    -1
  } else if left.priority > right.priority {
    1
  } else {
    left.name.compare(right.name)
  }
}

///|
/// Estimate the total wire bits for one scheduler window.
pub fn schedule_wire_bits(ticks : Array[SchedulerTick]) -> Int {
  ticks.fold(init=0, (total, tick) => total + frame_wire_bits(tick.frame))
}

///|
/// Return the fraction of ticks that missed their deadline.
pub fn schedule_miss_rate(ticks : Array[SchedulerTick]) -> Double {
  if ticks.is_empty() {
    0.0
  } else {
    ticks.count_if(tick => tick.late).to_double() / ticks.length().to_double()
  }
}
