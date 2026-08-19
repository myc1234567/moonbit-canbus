///|
test "extended DBC reader keeps physical metadata" {
  let input =
    #|VERSION ""
    #|BO_ 256 EngineData: 8 ECU
    #| SG_ speed : 0|16@1+ (0.1,-2) [0|250] "km/h" ECU
    #|CM_ SG_ 256 speed "vehicle speed";
  let report = parse_dbc_extended(input) catch { _ => panic() }
  inspect(report.message_count(), content="1")
  inspect(report.signal_lines(), content="1")
  match report.messages()[0].find("speed") {
    Some(item) => {
      inspect(item.factor(), content="0.1")
      inspect(item.offset(), content="-2")
      inspect(item.unit(), content="km/h")
      inspect(report.messages()[0].required_bytes(), content="2")
    }
    None => fail("signal missing")
  }
}

///|
test "extended DBC reader catches malformed ranges" {
  try
    parse_dbc_extended(
      "BO_ 1 Broken: 8 ECU\n SG_ bad : 0|8@1+ (bad) [0|1] \"\" ECU",
    )
  catch {
    DbcExtendedError::InvalidNumber => inspect(true, content="true")
    _ => fail("wrong error")
  } noraise {
    _ => fail("expected invalid number")
  }
}
