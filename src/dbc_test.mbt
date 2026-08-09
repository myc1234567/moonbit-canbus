///|
test "parse a compact dbc" {
  let content = "BO_ 256 VehicleStatus: 8 Vector__XXX\n SG_ Speed : 8|8@1+ (1,0) [0|250] \"km/h\" Vector__XXX"
  let db = parse_dbc(content) catch { _ => [] }
  inspect(db.length(), content="1")
  inspect(db[0].name(), content="VehicleStatus")
  debug_inspect(
    db[0].find("Speed").map(fn(item) { item.name() }),
    content="Some(\"Speed\")",
  )
}
