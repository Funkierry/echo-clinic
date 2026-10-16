# 开发、测试与版本维护

## 工具与入口

- Godot 4.7.2，Compatibility 渲染器；Windows 调试使用 `*_console.exe`。
- Python 3，测试与打包仅使用标准库。
- Git；从命令行发布 Release 可使用 GitHub CLI。
- Windows 导出前，在 Godot 中安装与引擎版本一致的导出模板。

当前版本为 v0.9.5-prototype。`project/main.tscn` 绑定 `project/scripts/v9/main.gd`，音频自动加载为 `v9/audio.gd`。导出配置使用默认模板，无本机绝对路径。

| 文件 | 职责 |
|---|---|
| `project/scripts/v9/main.gd` | 诊疗编排、聊天、证据出示、确认和经济事件 |
| `project/scripts/v9/desktop.gd`、`window.gd` | 桌面、应用解锁、任务栏与窗口 |
| `project/scripts/v9/app_taskmgr.gd`、`app_monitor.gd` | 第一幕任务管理器与患者监护 |
| `project/scripts/v9/case.gd`、`story.gd` | 本地状态机、证据、预写对白与结局 |
| `project/scripts/v9/workbench.gd` | 后续各幕保留的检查台 |
| `project/scripts/v9/profile.gd`、`cache_job.gd` | 钱包、外包与康复联系人 |
| `project/scripts/v9/companions.gd` | 康复角色独立聊天 |
| `project/scripts/v9/dialogue_router.gd`、`director.gd` | 调查意图、角色约束与输出检查 |
| `project/scripts/v5/ai_client.gd` | DeepSeek HTTP、超时、取消、响应解析 |
| `project/scripts/v9/saves.gd`、`menu.gd`、`coach.gd` | 存档、菜单和教学 |
| `project/scripts/v9/tests.gd` | 当前流程、桌面、经济和网络检查 |

旧目录保留历史实验与复用依赖，删除前先检查 `preload`、`load`。今后的修改通过 Git 分支、提交和标签维护。

## 本地测试

```powershell
python tools/test_v9.py --godot "C:/path/to/Godot_v4.7.2-stable_win64_console.exe"
```

测试器导入资源、启动仅监听本机临时端口的模拟服务，并运行游戏自测；完成后关闭服务。不需要真实 Key，不请求 DeepSeek。当前为 366 项，截图和报告在 `captures/v0.9.5-prototype/`。需可用的图形环境，只有资源导入阶段使用 `--headless`。

## Windows 导出与打包

```powershell
New-Item -ItemType Directory -Force release/EchoClinic-Windows-v0.9.5-prototype | Out-Null
& "C:/path/to/Godot_console.exe" --headless --path project --export-release "Windows Desktop" "../release/EchoClinic-Windows-v0.9.5-prototype/EchoClinic.exe"
python tools/test_v9.py --exe "C:/absolute/path/to/echo-clinic/release/EchoClinic-Windows-v0.9.5-prototype/EchoClinic.exe"
# 先把要发布的源码、文档和资源加入 Git 暂存区。
git add project tools README.md README-v0.9.md CHANGELOG.md docs CREDITS.md
python tools/package_v8.py
```

`package_v8.py` 沿用既有文件名，当前目标为 v0.9.5-prototype。要求源码与 EXE 两份报告通过、检查数量一致且不少于 366。输出 Windows ZIP、Godot 源码 ZIP、许可证、截图、验证报告和 SHA-256 校验文件。

源码 ZIP 按 Git 跟踪清单读取工作区文件，因此新增文件必须先加入暂存区。忽略的本地缓存、存档、密钥和导出文件不会进入源码包。

引擎、模板、导出程序、玩家存档与 API 配置不进入 Git；Windows 程序通过 Release 分发。

## 版本维护

日常迭代可从 `main` 创建功能分支，修改后运行相关检查并提交。发布时更新 `CHANGELOG.md`、README、导出版本及测试/打包目录，提交后给该提交打标签。v0.7.0 保留为首个 GitHub 基线，v0.9.1-prototype 为桌面原型基线；本次 v0.9.5-prototype 汇入 v0.9.2 至 v0.9.5 的角色与演出迭代。

## 存档与 AI

开发运行与导出程序默认共用 Godot 用户数据目录，避免同时运行两个正常游戏实例。自动测试使用测试模式和 `qa-saves`，不覆盖正常玩家进度。

Key 可在游戏内填写或通过 `DEEPSEEK_API_KEY` 提供。不要提交 `.env`、密钥、玩家存档和真实聊天记录。模型不能替代本地授权、结算与病例状态机。

`tools/run_npc_probe.ps1` 是可选的真实模型测试，会使用 DeepSeek 账户并产生实际费用；常规回归只运行 `test_v9.py`。既有 v0.8 人设测试记录在 `docs/v0.8-npc.md`，不能替代后续版本验收。
