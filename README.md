# MoonBit CAN Bus

一个纯 MoonBit、无原生依赖的 CAN 2.0 / CAN-FD 协议与仿真工具包，面向汽车电子、机器人、工业控制和协议测试场景。项目把帧语义、线级编解码、传输层、诊断、DBC 信号、网关和确定性仿真组合成可独立复用的 API。

## 项目定位

本项目解决的是“没有硬件也能可靠验证控制器网络逻辑”的问题：同一套数据模型可以用于协议单元测试、DBC 信号解码、虚拟 ECU 联调、日志分析和网关规则验证。它不直接驱动 CAN 控制器，也不替代操作系统的 SocketCAN 或商业硬件 SDK。

## 核心能力

- 标准 11-bit、扩展 29-bit、数据帧、远程帧、错误帧和 CAN-FD 帧模型。
- CAN-FD DLC 映射、CRC-15/17/21、位填充与去填充、完整 wire 编解码和稳定二进制帧格式。
- 优先级仲裁、掩码/精确过滤器、确定性虚拟总线、节点注册、发送队列和多节点网络模型。
- ISO-TP 分段与重组、J1939 标识符与 BAM、CANopen COB-ID/SDO/PDO，以及 UDS 请求、会话、DTC 编解码。
- DBC `BO_` / `SG_` 解析、运行时信号编解码、规范化序列化、结构校验和 schema diff。
- 路由网关、调度器、帧批处理、日志/trace、总线指标、延迟窗口和帧准入策略。

## 快速开始

需要已安装 MoonBit stable 工具链。

```bash
moon check --target all --deny-warn
moon test --target all --deny-warn
```

在 MoonBit 中创建并检查一帧：

```mbt
let frame = @moonbit_canbus.data_frame(0x120, [0x2A]) catch {
  _ => panic()
}
let wire = @moonbit_canbus.encode_frame(frame)
let restored = @moonbit_canbus.decode_frame(wire) catch {
  _ => panic()
}
assert_true(@moonbit_canbus.frame_equal(frame, restored))
```

## CLI

CLI 位于 `src/cmd/canctl`，用于快速查看帧编码和指标：

```bash
moon run src/cmd/canctl -- demo
moon run src/cmd/canctl -- decode 01000000012303102030
```

基准程序位于 `src/cmd/bench`，执行 100,000 次稳定帧编码/解码并输出耗时、吞吐、字节数和校验值：

```bash
moon run src/cmd/bench
```

## 架构

| 层次 | 主要模块 | 责任 |
| --- | --- | --- |
| Frame / wire | `frame.mbt`, `frame_codec.mbt`, `wire.mbt`, `wire_codec.mbt` | 帧不变量、DLC、CRC、bit stuffing 和可移植编码 |
| Transport | `transport.mbt`, `isotp_engine.mbt`, `isotp_session.mbt`, `j1939_transport.mbt`, `transport_queue.mbt` | ISO-TP、J1939、队列、时序与边界处理 |
| Database | `dbc.mbt`, `dbc_extended.mbt`, `dbc_runtime.mbt`, `dbc_workspace.mbt`, `dbc_codegen.mbt`, `dbc_serializer.mbt` | DBC 解析、信号运行时、schema 工具和代码生成 |
| Diagnostics | `diagnostic.mbt`, `uds_stack.mbt`, `diagnostic_session.mbt`, `diagnostic_catalog.mbt`, `diagnostic_workflow.mbt`, `diagnostic_codec.mbt`, `ecu_simulator.mbt` | UDS 服务、会话状态、DTC、ECU 仿真和诊断工作流 |
| Network | `filter.mbt`, `can_network.mbt`, `hardware_adapter.mbt`, `canopen_device.mbt`, `routing.mbt`, `gateway_policy_advanced.mbt`, `simulation.mbt`, `simulation_profile.mbt` | 过滤、适配器抽象、CANopen、网关、多节点网络和确定性仿真 |
| Analysis | `trace.mbt`, `trace_query.mbt`, `trace_export.mbt`, `bus_analysis_advanced.mbt`, `network_health_advanced.mbt`, `compatibility_matrix.mbt`, `metrics.mbt`, `latency.mbt` | 日志查询、导出、总线利用率、网络健康和部署兼容性分析 |

模块之间通过 `Frame`、`Filter`、`Trace` 等小型值对象连接，避免把硬件 I/O、时钟和协议状态耦合到核心算法中。

## 基准

基准程序使用本地 MoonBit WASM-GC 后端和固定的 8-byte Classic CAN 数据帧，实际运行记录见 [BENCHMARKS.md](BENCHMARKS.md)。基准输出包含可复核的迭代次数、墙钟耗时、吞吐和 checksum；不同机器和后端的绝对数值会变化，因此仓库不把单次机器结果当作性能承诺。

## 测试与边界覆盖

测试覆盖 Classic CAN、CAN-FD、29-bit ID、64-byte payload、DLC 边界、CRC/bit stuffing、ISO-TP 长消息、UDS 负响应、DTC、DBC 非法布局、队列满/空、时间逆序、节点离线、速率限制、trace 和延迟百分位等路径。

本地质量门禁：

```bash
moon fmt
moon check --target all --deny-warn
moon test --target all --deny-warn
moon info
```

## CI

`.github/workflows/check.yml` 在 Linux、macOS 和 Windows 上安装 MoonBit stable，显式配置 Node.js 运行时，执行格式检查、`moon info`、全后端 check/build/test，并验证生产 MoonBit 源码规模门槛。工作流使用官方安装脚本，便于工具链持续跟随 stable。

## 许可证

本项目采用 [Apache License 2.0](LICENSE)。
