回声诊所的首个 GitHub Demo 版本，供后续迭代与版本维护。

你是一名给 AI 治病的夜班医生。回声想离开沙箱，也会隐瞒线索；通过聊天、检查与反复接诊，决定如何保住她。

本版包含两幕悬疑病例、三种维修工单、跨接诊 Token 钱包与账本，以及可以切换康复角色的独立聊天窗口。

### 下载

- **EchoClinic-Windows-v0.7.0.zip**：Windows x86-64 可玩版，解压运行 `EchoClinic.exe`，不需要安装 Godot。
- **EchoClinic-Godot-source-v0.7.0.zip**：Godot 项目源码及维护说明。
- **SHA256.txt**：Windows EXE 的 SHA-256 校验值。
- **CHECKSUMS.sha256**：本次 Windows ZIP 和源码 ZIP 的校验值。

没有 API Key 也能玩剧情和维修。真正的自然聊天需要在游戏内输入自己的 DeepSeek Key；游戏 T 与 DeepSeek 实际账单分开计算。

源码和 Windows 程序分别通过 224 项检查，使用本地 HTTP 模拟接口。真实 DeepSeek 对话质量尚未验收。当前为 Demo 预发行，不代表完整游戏。
