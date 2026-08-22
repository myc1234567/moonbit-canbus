# Benchmarks

## Frame codec

Command:

```text
moon run src/cmd/bench
```

One local run on 2026-08-19 with MoonBit `0.1.20260807` / MoonC `0.10.7+bc794d341`, WASM-GC backend:

```text
benchmark=frame-codec
iterations=100000
elapsed_ms=64
operations_per_second=1562500
encoded_bytes=1500000
checksum=0
```

The loop encodes and decodes 100,000 fixed 8-byte Classic CAN data frames. `checksum` is accumulated from decoded identifiers so the decoded result participates in the measurement. The elapsed time is wall-clock time from `moonbitlang/core/env`; repeat the command on the target machine for release comparisons.
