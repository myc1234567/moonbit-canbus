///|
test "dbc database decodes a message" {
  let input =
    #|BO_ 256 EngineData: 8 ECU
    #| SG_ speed : 0|16@1+ (0.1,0) [0|250] "km/h" ECU
  let database = parse_dbc_database(input) catch { _ => panic() }
  inspect(database.length(), content="1")
  match database.by_id(256) {
    Some(item) => {
      inspect(item.signal_count(), content="1")
      let decoded = item.decode([0x64, 0, 0, 0, 0, 0, 0, 0]) catch {
        _ => panic()
      }
      match decoded.find("speed") {
        Some(value) => {
          inspect(value.raw(), content="100")
          inspect(value.physical(), content="100")
        }
        None => fail("signal missing")
      }
    }
    None => fail("message missing")
  }
}

///|
test "signal range and layout boundaries" {
  let item = signal(
    "value",
    0,
    8,
    factor=0.5,
    offset=-2.0,
    minimum=-2.0,
    maximum=125.5,
    unit="u",
  )
  assert_true(item.is_valid(1))
  assert_true(item.accepts(10.0))
  assert_true(!item.accepts(200.0))
  inspect(item.raw_max(), content="255")
  inspect(item.unit(), content="u")
}
