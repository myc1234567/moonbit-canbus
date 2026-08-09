# MoonBit CAN 总线协议与诊断工具包

**项目方向**：汽车电子、机器人与工业控制基础软件；**项目标识**：`moonbit-canbus`。

**项目简介**：本项目使用 MoonBit 原生实现可复用的 CAN 2.0/CAN-FD 协议与仿真工具包，覆盖帧模型、DLC、CRC、位填充、优先级仲裁、接收过滤、内存虚拟总线、DBC 信号解析、ISO-TP、J1939、基础 UDS 诊断和总线记录回放，面向 ECU 联调、机器人控制器模拟、工业设备测试和教学实验。

**核心价值**：MoonBit 生态已有通用数据结构与异步基础设施，但缺少面向控制器网络的协议语义、确定性仿真和信号层工具。本项目保持无原生依赖、可测试、可扩展的 API 边界，后续可接入 CANopen、硬件适配层、SocketCAN、日志回放和更完整的 DBC/ISO-TP 能力。

**当前交付**：标准帧、扩展帧、远程帧、错误帧、CAN-FD 帧；CAN-FD DLC 与 CRC-15/17/21；位填充/去填充和数值仲裁；掩码过滤器与有界虚拟总线；DBC `BO_`/`SG_` 子集；信号物理值编解码；UDS 会话控制、ECU Reset、ReadDataByIdentifier、TesterPresent；ISO-TP 分段重组；J1939 标识符/PGN；时间戳记录与确定性回放。

**工程计划**：第一阶段完成协议模型、虚拟总线与测试基础；第二阶段完善 DBC、ISO-TP、J1939 和诊断会话；第三阶段增加硬件适配接口、记录格式和示例工具，并持续通过 MoonBit 0.10.3 的格式化、检查、测试和接口生成流程验证。

**质量与开源**：仓库包含 Apache-2.0 LICENSE、可复现 README、生成的 `pkg.generated.mbti`、9 个核心测试和三平台 GitHub Actions CI。项目为原创 MoonBit 实现，不直接复制 MoonBit 生态已有项目或第三方源码；协议实现依据公开协议概念，示例数据为手写最小样例。

**仓库链接**：

- GitHub：https://github.com/myc1234567/moonbit-canbus
- Gitlink：https://gitlink.org.cn/mycmyc/moonbit-canbus
