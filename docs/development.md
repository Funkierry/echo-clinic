# 开发、测试与版本维护

## 工具

- Godot 4.7.2，使用 Compatibility 渲染器。Windows 调试建议使用 `*_console.exe`，方便看日志。
- Python 3，测试与打包仅使用标准库。
- Git；需要从命令行发 Release 时使用 GitHub CLI。
- 导出 Windows 前，在 Godot 编辑器“管理导出模板”中安装与引擎版本一致的模板。

引擎、模板、导出程序、玩家存档和真实 API 配置均不进入 Git。`project/export_presets.cfg` 使用默认导出模板，不依赖某台机器的路径。

## 代码地图

| 文件 | 职责 |
|---|---|
| `project/main.tscn` | 当前入口，绑定 v7/main.gd |
| `project/scripts/v7/main.gd` | 三栏界面、诊疗编排、确认、病历和存档 |
| `project/scripts/v7/case.gd` | 阶段、证据、约定与结局的本地状态机 |
| `project/scripts/v7/story.gd` | 预写剧情、事件对白与演出文案 |
| `project/scripts/v7/workbench.gd` | 右侧检查台与操作 |
| `project/scripts/v7/profile.gd` | 钱包、预留、账本、工单、康复联系人 |
| `project/scripts/v7/workshop.gd` | 三种维修工单界面 |
| `project/scripts/v7/companions.gd` | 康复角色独立聊天与会话隔离 |
| `project/scripts/v7/dialogue_router.gd` | 输入意图、允许的调查、关键操作确认 |
| `project/scripts/v7/director.gd` | AI 公开上下文、角色约束与输出检查 |
| `project/scripts/v5/ai_client.gd` | DeepSeek HTTP、超时、取消、响应解析 |
| `project/scripts/v4/ui.gd`、`cinema.gd` | 当前仍复用的像素 UI 与演出 |
| `project/scripts/v7/tests.gd` | v0.7 流程和经济测试入口 |

旧版本目录不是分支替代品。今后的修改直接用 Git 提交、分支和标签维护；不必每次再复制整个 `v7` 文件夹。删除旧目录前，先检查所有 `preload`、`load` 和测试依赖。

## 本地测试

```powershell
python tools/test_v7.py --godot "C:/path/to/Godot_v4.7.2-stable_win64_console.exe"
```

测试器会自动启动本机临时端口的模拟服务，结束时关闭；不使用真实密钥，也不请求 DeepSeek。正常结果为 224 项通过，详细记录与截图在 `captures/v0.7/`。需要可用的图形环境；只有资源导入阶段使用 `--headless`，涉及截图和鼠标的游戏测试不能直接改成纯无图形运行。

已有独立夹具的低层命令：

```powershell
python tools/mock_deepseek_v7.py --port 18919
# 在另一个终端运行：
& "C:/path/to/Godot_console.exe" --path project -- --self-test --ai-mock-url=http://127.0.0.1:18919 --capture-dir=C:/absolute/path/to/captures/v0.7
```

## Windows 导出与打包

先安装对应版本导出模板，然后执行：

```powershell
New-Item -ItemType Directory -Force release/EchoClinic-Windows-v0.7.0 | Out-Null
& "C:/path/to/Godot_console.exe" --headless --path project --export-release "Windows Desktop" "../release/EchoClinic-Windows-v0.7.0/EchoClinic.exe"
python tools/test_v7.py --exe "C:/absolute/path/to/echo-clinic/release/EchoClinic-Windows-v0.7.0/EchoClinic.exe"
python tools/package_v7.py
```

打包要求源码与 EXE 的两份报告都通过。输出 Windows ZIP、Godot 源码 ZIP、许可证、截图、测试报告和 EXE 的 SHA-256。引擎二进制不加入 Git；安装包通过 Release 分发。

## 建议的迭代流程

```powershell
git switch main
git pull --ff-only
git switch -c feature/next-patient
# 修改、试玩、运行相关检查
git add project README-v0.7.md CHANGELOG.md
git commit -m "Add next patient encounter"
git push -u origin feature/next-patient
```

稳定后合入 `main`。发版本前更新 `CHANGELOG.md`、版本文案和 `export_presets.cfg` 的版本字段；同步更新测试/打包脚本中的版本目录。标签从 `v0.7.0` 开始，后续修复用 `v0.7.1`，下一批功能可用 `v0.8.0`。

本次上传仅建立一个经过验证的版本基线，没有伪造之前每次迭代的 Git 提交。旧版本源码与说明仍保留，可按需整理。

## 存档与 AI 注意事项

开发运行与导出程序默认使用同一 Godot 用户存档目录。不要同时打开两个正常运行实例；自动测试使用隔离的测试模式，不覆盖玩家进度。共享状态时同时保存病例与 profile，避免钱包与阶段不同步。

Key 只在游戏设置中输入，或通过 `DEEPSEEK_API_KEY` 环境变量提供。不要提交 `.env`、密钥、玩家对话存档。模型永远不能替代本地授权、结算或病例状态机。
