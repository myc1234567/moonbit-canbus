# MoonBit CAN Bus

MoonBit CAN Bus 是面向汽车电子、机器人和工业控制仿真的 CAN 2.0 / CAN-FD 基础工具包。它提供纯 MoonBit、无原生依赖的帧模型、DLC 处理、CRC、位填充、优先级仲裁、接收过滤、内存虚拟总线、DBC 消息/信号读取，以及一组可继续扩展的 UDS 诊断请求构造器。

## 为什么做这个项目

MoonBit 生态已经有通用数据结构、序列化和异步基础设施，但面向控制器网络的 CAN 帧语义、确定性总线仿真、DBC 信号解码和诊断请求仍缺少一个组合式的基础包。本项目选择从协议语义和仿真边界出发，保持 API 小而稳定，后续可以接入 J1939、CANopen、硬件适配器和记录回放工具。

项目为原创实现，不是对现有 MoonBit 包的直接移植，也不复制其他仓库的源码、测试数据或生成文件。协议字段按公开的 ISO 11898 / ISO 15765 概念实现；实现不包含受限标准正文或商业硬件驱动。

## 当前能力

- 标准 11-bit、扩展 29-bit、数据帧、远程帧和本地错误帧模型。
- CAN 2.0 载荷校验（0–8 字节）和 CAN-FD 载荷校验（0–64 字节）。
- CAN-FD DLC 映射、CRC-15、CRC-17、CRC-21、位填充/去填充。
- 按数值 ID 进行确定性优先级仲裁。
- 精确过滤器、掩码过滤器和有界虚拟总线队列。
- DBC 中常用的 `BO_` / `SG_` 消息与信号描述读取。
- 小型信号编解码 API，以及 UDS 会话控制、ECU Reset、ReadDataByIdentifier、TesterPresent 请求。

## 快速开始

需要 MoonBit 0.10.3 或更新版本。

```bash
moon check --deny-warn
moon test --deny-warn
```

在 MoonBit 代码中，帧和总线可以这样组合：

```mbt nocheck
let frame = @moonbit_canbus.data_frame(0x120, [0x2A]) catch { _ => panic() }
let bus = @moonbit_canbus.new_bus(16)
let filters = @moonbit_canbus.new_filter_bank()
filters.add(@moonbit_canbus.mask_filter(0x100, 0x700))
bus.set_filters(filters)
ignore(bus.publish(frame))
let received = bus.receive()
```

## 目录结构

`src/frame.mbt` 定义帧与 DLC；`src/crc.mbt` 和 `src/wire.mbt` 负责线级算法；`src/filter.mbt` 提供过滤器和虚拟总线；`src/signal.mbt`、`src/dbc.mbt` 负责 DBC 子集和信号；`src/diagnostic.mbt` 提供 UDS 请求骨架。`*_test.mbt` 覆盖这些核心路径。

## 设计边界与路线

当前包专注于可测试的协议模型，不声称直接驱动 CAN 控制器。后续按兼容性优先增加：完整 DBC 属性/注释解析、ISO-TP 分段、J1939 PGN、CANopen 对象字典、事件型虚拟总线、日志回放，以及 Linux SocketCAN/串口适配层。

## 许可证与来源

本项目使用 Apache License 2.0，许可证见根目录 `LICENSE`。项目没有第三方源码拷贝，DBC 示例是手写的最小文本片段；若后续加入公开数据库样例或硬件适配代码，会在 `NOTICE` 或独立来源文件中记录名称、链接、许可证和取用范围。

## 质量检查

本地和 CI 使用 MoonBit 0.10.3 工具链执行：

```bash
moon fmt --check
moon check --deny-warn
moon test --deny-warn
moon info
git diff --exit-code
```

生成的 `pkg.generated.mbti` 只通过 `moon info` 更新，不手工编辑。提交前应将实际 GitHub 账号写入 `moon.mod` 的 `name` 与 `repository`，再把同一默认分支同步到 Gitlink；本地仓库不包含任何远程推送配置。
