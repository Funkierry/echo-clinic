# 回声诊所 v0.1 · 历史说明



Godot 4.7.2 · Windows x86-64 · 纯 2D 诊疗台动效样片 · 2026-10-16

## 运行

最终运行包位于 `release/EchoClinic-Windows-v0.1/`。双击 `EchoClinic.exe` 即可运行，无需安装 Godot、Node 或其他运行环境。游戏资源已经嵌入 EXE。

这是离线动效与交互样片，使用本地预写对话及关键词回应，尚未接入真实语言模型，也不是完整剧情 Demo。程序不会发送聊天内容或发起网络请求。

## 建议体验顺序

1. 在左侧输入中文，或点击问诊提示。
2. 点击右侧“扫描”，观察扫描光带和检查记录。
3. 悬停、拖动底部的三张卡，查看浮起、倾斜、回弹与流光。
4. 将“残留记忆”拖到右侧记忆插槽。
5. 点击“执行修复”，观察像素患者逐步恢复、稳定度变化与回应。
6. 点击“外部请求”，选择“模拟越界”，查看信号故障效果。
7. 点击右下角“重启会话”，观察解体重组，再打开医生病历。

病历在当前程序运行期间跨会话保留；关闭程序后清除。声音与动效偏好保存在 Godot 的用户数据目录。

## 操作

- 鼠标：点击、悬停、拖拽卡片。
- Enter：发送输入框中的内容。
- R：输入框未聚焦时重启会话。
- F11：切换全屏。
- Esc：关闭病历弹窗；全屏时退出全屏。
- F8：将当前游戏画面保存到桌面。
- 顶部按钮：开关声音、切换轻柔动效。

## 资源规则

每轮 60T，问诊 5T，扫描 10T，修复 20T；回收缓存可以获得 20T，每轮一次。查看病历、卡片和重启免费。重复修复不扣费，额度不足也可以恢复快照。

## 工程

- `project/project.godot`：用 Godot 打开的工程。
- `project/scripts/main.gd`：界面、预写对话、诊疗状态、重启与自检。
- `project/scripts/card.gd`：卡片拖动、弹簧旋转、悬停与卡面。
- `project/scripts/stage.gd`：原创程序像素患者、诊疗仪表、扫描与粒子。
- `project/shaders/`：卡片流光、终端信号故障与轻微扫描纹理。
- `tools/bootstrap.py`：获取官方 Godot 与 Windows 导出模板、开源字体。
- `tools/prepare_assets.py`：生成原创合成音效与本机导出配置。
- `captures/test-report.json`：导出版本的自动流程检查结果。

正式构建使用 Godot 4.7.2。`bootstrap.py` 会读取官方发布信息，重建时应核对 `tools/release.json` 中的版本。导出配置中的模板路径由 `prepare_assets.py` 按当前目录重新生成。

自检命令：

```text
EchoClinic.exe -- --self-test --capture-dir=C:/path/to/captures
```

流程检查覆盖费用、缓存重复领取、扫描记录、错误卡片、锚点、修复、重复修复、跨轮病历、越界记录、额度不足与重启恢复。画面使用游戏实际渲染输出。

## 素材与署名

本样片的像素患者、界面图形、音效和 Shader 为本项目编写。视觉构图参考 MisakaZentai 的 `world-execute-me-dsh-pv` 和用户的 `dsh-thought-window`；交互反馈参考 Balatro。不包含上述作品的音乐、角色贴图、代码或游戏素材。

字体：Noto Sans CJK SC、JetBrains Mono（SIL OFL，见字体许可证）。Godot 引擎及其第三方组件声明见运行包的 `licenses/`。

