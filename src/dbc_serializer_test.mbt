///|
test "DBC schema validates, serializes canonically and reports statistics" {
  let input = "VERSION \"demo\"\nBO_ 512 Status: 8 Vector__XXX\n SG_ Speed : 0|16@1+ (0.1,-10) [0|250] \"km/h\" Vector__XXX\n"
  let parsed = parse_dbc_extended(input) catch { _ => panic() }
  let report = validate_dbc_schema(parsed.messages()) catch { _ => panic() }
  inspect(report.message_count(), content="1")
  inspect(report.signal_count(), content="1")
  inspect(report.maximum_required_bytes(), content="2")
  let canonical = serialize_dbc_schema(parsed.messages()) catch { _ => panic() }
  assert_true(canonical.has_prefix("VERSION \"\"\n"))
  assert_true(canonical.contains("BO_ 512 Status: 8"))
  assert_true(canonical.contains("SG_ Speed : 0|16@1+"))
  let normalized = canonicalize_dbc(input) catch { _ => "" }
  assert_true(normalized == canonical)
}

///|
test "DBC schema diff detects added removed and changed messages" {
  let first = message(10, "A", 8)
  first.add_signal(signal("x", 0, 8))
  let changed = message(10, "A", 8)
  changed.add_signal(signal("x", 0, 4))
  let added = message(20, "B", 4)
  let changes = diff_dbc_schema([first], [changed, added])
  inspect(changes.length(), content="2")
  inspect(changes[0].kind(), content="changed")
  inspect(changes[1].kind(), content="added")
  let removed = diff_dbc_schema([first, added], [changed])
  inspect(removed.length(), content="2")
  inspect(removed[1].kind(), content="removed")
}

///|
test "DBC schema rejects duplicate ids overlap and invalid ranges" {
  let left = message(1, "Left", 1)
  let right = message(1, "Right", 1)
  try validate_dbc_schema([left, right]) catch {
    DbcSchemaError::DuplicateMessageId => inspect(true, content="true")
    _ => fail("wrong duplicate error")
  } noraise {
    _ => fail("expected duplicate id")
  }
  let overlap = message(2, "Overlap", 1)
  overlap.add_signal(signal("a", 0, 5, minimum=0.0, maximum=31.0))
  overlap.add_signal(signal("b", 4, 4, minimum=0.0, maximum=15.0))
  try validate_dbc_schema([overlap]) catch {
    DbcSchemaError::OverlappingSignals => inspect(true, content="true")
    _ => fail("wrong overlap error")
  } noraise {
    _ => fail("expected overlap")
  }
}
