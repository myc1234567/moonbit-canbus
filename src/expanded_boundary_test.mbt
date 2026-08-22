///|
test "compatibility target clamps invalid capacity and preserves features" {
  let target = compatibility_target(
    "boundary",
    CompatibilityProtocol::CompatibilityCustom,
    -10,
    -20,
    -1,
    -2,
    -3,
    features=["routing", "diagnostics"],
  )
  inspect(target.nominal_bitrate(), content="0")
  inspect(target.data_bitrate(), content="0")
  inspect(target.max_payload(), content="0")
  inspect(target.identifier_bits(), content="0")
  inspect(target.node_capacity(), content="0")
  inspect(target.feature_count(), content="2")
  assert_true(target.has_feature("routing"))
  assert_true(!target.has_feature("missing"))
}

///|
test "compatibility matrix evaluates numeric and feature boundaries" {
  let matrix = compatibility_matrix(name="boundary matrix", strict=true)
  let target = compatibility_target(
    "small",
    CompatibilityProtocol::CompatibilityClassicCan,
    125,
    0,
    8,
    11,
    4,
    features=["classic"],
  )
  matrix.add_target(target)
  matrix.add_requirement(compatibility_minimum_bitrate("B-1", 125))
  matrix.add_requirement(compatibility_minimum_payload("B-2", 9))
  matrix.add_requirement(
    compatibility_requires_feature(
      "B-3",
      "classic",
      severity=CompatibilitySeverity::CompatibilityWarning,
    ),
  )
  matrix.add_requirement(compatibility_minimum_node_capacity("B-4", 4))
  let evaluation = matrix.evaluate(target)
  inspect(evaluation.passed(), content="3")
  inspect(evaluation.warnings(), content="0")
  inspect(evaluation.failures(), content="1")
  inspect(evaluation.score(), content="80")
  assert_true(!evaluation.is_compatible())
  inspect(compatibility_failures(evaluation).length(), content="1")
  assert_true(matrix.status() == "failed")
}

///|
test "compatibility matrix accepts gateway diagnostics and exports reports" {
  let matrix = compatibility_matrix(name="gateway check")
  let target = compatibility_gateway_target()
  matrix.add_target(target)
  matrix.add_requirement(compatibility_requires_fd("G-1"))
  matrix.add_requirement(compatibility_requires_isotp("G-2"))
  matrix.add_requirement(compatibility_requires_diagnostics("G-3"))
  matrix.add_requirement(compatibility_requires_feature("G-4", "routing"))
  matrix.add_requirement(compatibility_minimum_payload("G-5", 4095))
  let evaluation = matrix.evaluate(target)
  assert_true(evaluation.is_compatible())
  inspect(evaluation.failures(), content="0")
  assert_true(matrix.report().contains("gateway check"))
  assert_true(matrix.csv().contains("compatible"))
  assert_true(compatibility_snapshot(matrix).contains("average_score"))
  assert_true(compatibility_ci_annotations(matrix) == "")
}

///|
test "compatibility matrices expose downgrade losses and route budgets" {
  let fd = compatibility_fd_target()
  let classic = compatibility_classic_target()
  let delta = compatibility_compare_targets(fd, classic)
  assert_true(delta.payload_loss() > 0)
  assert_true(delta.data_bitrate_loss() > 0)
  assert_true(delta.lost_features().length() > 0)
  assert_true(!delta.is_lossless())
  let route = compatibility_route(
    fd,
    classic,
    CompatibilityProtocol::CompatibilityCanFd,
  )
  assert_true(!route.valid())
  inspect(compatibility_route_payload_budget(route), content="8")
  let table = compatibility_build_default_routes()
  assert_true(table.routes().length() == 4)
  table.add(
    compatibility_route(fd, classic, CompatibilityProtocol::CompatibilityCanFd),
  )
  assert_true(table.invalid_routes().length() > 0)
}

///|
test "compatibility release gate rejects empty and failed gates" {
  let empty = compatibility_release_gate()
  assert_true(!empty.ready())
  let gate = compatibility_release_gate(minimum_score=90)
  let matrix = compatibility_matrix_for_target(compatibility_gateway_target(), [
    compatibility_requires_fd("R-1"),
    compatibility_requires_feature("R-2", "routing"),
  ])
  gate.add_matrix(matrix)
  assert_true(gate.ready())
  assert_true(gate.report().contains("ready=true"))
}

///|
test "payload codec checksum round trip and corruption boundary" {
  let options = payload_codec_options(
    profile=PayloadCodecProfile::PayloadCodecCounterChecksum,
    counter_offset=0,
    checksum_offset=3,
    expected_length=4,
    counter_modulus=16,
  )
  assert_true(payload_codec_layout_valid(options))
  let codec = new_payload_codec(options~)
  let encoded = codec.encode([0, 0x12, 0x34, 0])
  assert_true(encoded.accepted())
  inspect(codec.encoded(), content="1")
  let decoded = codec.decode(encoded.data(), None)
  assert_true(decoded.accepted())
  inspect(codec.decoded(), content="1")
  let corrupted = encoded.data()
  corrupted[1] = 0x13
  let rejected = codec.decode(corrupted, None)
  assert_true(!rejected.accepted())
  assert_true(rejected.status() is PayloadCodecStatus::PayloadCodecBadChecksum)
  inspect(codec.failures(), content="1")
}

///|
test "payload codec crc and counter sequence boundaries" {
  let options = payload_codec_options(
    profile=PayloadCodecProfile::PayloadCodecCounterCrc,
    counter_offset=0,
    crc_offset=3,
    expected_length=4,
  )
  let codec = new_payload_codec(options~)
  let first = codec.encode([0, 1, 2, 0])
  assert_true(first.accepted())
  let second = codec.encode([0, 3, 4, 0])
  assert_true(second.accepted())
  let wrong_counter = codec.decode(second.data(), Some(1))
  assert_true(
    wrong_counter.status() is PayloadCodecStatus::PayloadCodecBadCounter,
  )
  let bad_crc_data = first.data()
  bad_crc_data[1] = 9
  let bad_crc = codec.decode(bad_crc_data, None)
  assert_true(bad_crc.status() is PayloadCodecStatus::PayloadCodecBadCrc)
  assert_true(payload_codec_counter_valid(15, 0, 16))
  assert_true(!payload_codec_counter_valid(2, 2, 16))
  assert_true(
    !payload_codec_layout_valid(payload_codec_options(counter_modulus=1)),
  )
}

///|
test "payload codec invalid length is observable and reset is deterministic" {
  let options = payload_codec_options(
    profile=PayloadCodecProfile::PayloadCodecCounterChecksum,
    expected_length=3,
    checksum_offset=2,
  )
  let codec = new_payload_codec(options~)
  let result = codec.encode([1, 2])
  assert_true(result.status() is PayloadCodecStatus::PayloadCodecBadLength)
  inspect(codec.failures(), content="1")
  codec.reset()
  inspect(codec.encoded(), content="0")
  inspect(codec.decoded(), content="0")
  inspect(codec.failures(), content="0")
  inspect(codec.next_counter(), content="b'\\x00'")
}

///|
test "frame pipeline rejects oversized payload and rewrites matching id" {
  let pipeline = new_frame_pipeline()
  pipeline.add_rule(
    frame_pipeline_rule(
      "rewrite",
      exact_filter(0x123),
      FramePipelineAction::FramePipelineRewriteId(0x456),
      max_payload=2,
      allow_fd=false,
    ) catch {
      _ => panic()
    },
  )
  let frame = data_frame(0x123, [1, 2]) catch { _ => panic() }
  match pipeline.process(frame) {
    FramePipelineResult::FramePipelineAccepted(updated, name) => {
      inspect(updated.id(), content="1110")
      inspect(name, content="rewrite")
    }
    _ => fail("expected rewrite")
  }
  let oversized = data_frame(0x123, [1, 2, 3]) catch { _ => panic() }
  match pipeline.process(oversized) {
    FramePipelineResult::FramePipelineUnmatched(_) =>
      inspect(true, content="true")
    _ => fail("oversized frame must not match")
  }
  inspect(pipeline.processed(), content="2")
  inspect(pipeline.accepted(), content="1")
  inspect(pipeline.unmatched(), content="1")
}

///|
test "network health tracker handles timeout and recovery boundaries" {
  let tracker = new_network_health_tracker()
  ignore(tracker.add_node(network_node_health(1, "ecu", timeout_us=100)))
  let frame = data_frame(0x100, [1]) catch { _ => panic() }
  ignore(tracker.observe_frame(1, 10, frame, false))
  ignore(tracker.observe_heartbeat(1, 20))
  assert_true(tracker.find(1) is Some(_))
  ignore(tracker.poll(121))
  let degraded = tracker.find(1)
  match degraded {
    Some(node) => assert_true(!node.online())
    None => fail("node disappeared")
  }
  ignore(tracker.observe_heartbeat(1, 130))
  let recovered = tracker.find(1)
  match recovered {
    Some(node) => assert_true(node.online())
    None => fail("node disappeared after recovery")
  }
}
