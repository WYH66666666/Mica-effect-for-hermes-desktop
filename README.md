# Hermes Desktop 毛玻璃效果
使用前先将Hermes Desktop默认透明度改为百分之50
给 **Hermes Desktop**（Hermes Agent 桌面客户端）垫一块 Windows 原生模糊背景板。用 DWM 内置的 Mica 材质做实时模糊——不截屏、不占额外 GPU、不碰窗口内容，只是一个垫在 Hermes 窗口正下方的「玻璃底」。

配合 Hermes 的窗口透明度 + 透明背景主题，就是一套完整的**毛玻璃桌面体验**：Hermes 界面半透明，桌面/壁纸从模糊里透出来。

- 🪟 **实时跟随**：事件驱动（WinEventHook），拖动、缩放、最小化、最大化、全屏全部紧贴，最大滞后 <30ms
- 🧊 **原生材质**：Mica（Win11 系统材质），模糊和抗锯齿都由 DWM 完成，零性能开销
- 🖱️ **点击穿透**：遮罩不拦截任何鼠标事件，纯粹视觉垫底
- 🕳️ **无阴影无任务栏**：`WS_EX_TOOLWINDOW` 实例级样式，干净利落
- 📐 **全屏不溢出**：用 `DWMWA_EXTENDED_FRAME_BOUNDS` 取真实边界，最大化时不会把 8px 阴影边距溢到相邻屏
- 🔄 **自愈守护**：Hermes 重启后自动重新绑定；遮罩被误杀自动复活；Hermes 退出自动关掉遮罩

## 效果

> Hermes 窗口半透明 + 遮罩垫底 = 毛玻璃质感，桌面从模糊里透出来。
> （截图待补充）

## 原理

```
┌────────────────────────────┐
│  Hermes Desktop（半透明）    │  ← 目标窗口
├────────────────────────────┤
│  遮罩窗 Frost Underlay      │  ← Electron 窗口
│  （DWM Mica 材质）           │     点击穿透、无边框、无阴影
└────────────────────────────┘
        ↓ 事件驱动 SetWindowPos
   FrostTracker.exe (WinEventHook)
```

- **main.js** — Electron 遮罩窗（Mica 材质、点击穿透、自动拉起跟随器）
- **FrostTracker.exe** — C# 跟随器：监听 Hermes 窗口移动/尺寸事件，实时同步遮罩窗位置尺寸
- **watch.ps1** — 守护脚本：Hermes 在 → 自动拉遮罩；Hermes 退出 → 自动关遮罩；心跳文件供外部看门狗

## 环境要求

- Windows 11（Mica 需要 22621+）
- [Electron](https://www.electronjs.org/)（开发用 `npm install electron` 即可）
- .NET Framework 4.x（仅编译 FrostTracker 需要，Windows 自带）

## 快速开始

```powershell
# 1. 安装 electron（或设置 ELECTRON_PATH 指向已有 electron.exe）
npm install electron --save-dev

# 2. 一键启动，跟随 Hermes
powershell -ExecutionPolicy Bypass -File start.ps1
```

或手动：

```powershell
npx electron .     # 或 electron.exe main.js
```

遮罩窗出现后，拖动 / 缩放 / 全屏 Hermes 都会实时贴合。

## 与 Hermes 搭配的完整玻璃效果

1. **Hermes 窗口透明度**：50% 左右（文字仍清晰，桌面能透进来）
2. **Hermes 主题**：用深色主题 + 透明背景（界面 body 半透明深色，压住 Mica 白雾不泛白）
3. **遮罩窗**：本项目的 Mica 垫底
4. **开机自启**（可选）：启动文件夹放快捷方式指向 `watch.ps1`

## 配置

| 环境变量 | 说明 | 默认 |
|---|---|---|
| `FROST_TARGET` | 跟随的进程名（默认 Hermes；也可指向其他程序） | `Hermes` |
| `FROST_MATERIAL` | 材质：`mica` / `acrylic` | `mica` |
| `FROST_DARK` | `1` 时跟随系统深色模式（Mica 暗色变体） | 亮色 |
| `ELECTRON_PATH` | electron.exe 完整路径（watch/start 脚本用） | 自动探测 |

## 构建 FrostTracker

```powershell
cd frost-underlay
"C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe" /nologo /target:winexe /out:FrostTracker.exe /r:System.Windows.Forms.dll /r:System.Drawing.dll FrostTracker.cs
```

## 开机自启（可选）

启动文件夹放一个快捷方式指向 `watch.ps1`：

```powershell
$ws = New-Object -ComObject WScript.Shell
$sc = $ws.CreateShortcut("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\FrostUnderlayWatch.lnk")
$sc.TargetPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
$sc.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PWD\watch.ps1`""
$sc.WindowStyle = 7
$sc.Save()
```

## 常见问题

- **遮罩溢出到其他屏？** 已修复：跟随器优先取 `DWMWA_EXTENDED_FRAME_BOUNDS`（真实边界），最大化窗口不会带出阴影边距。
- **Mica 效果泛白？** Mica 本身是浅色半透材质；Hermes 透明度太高时白雾会透出。建议：Hermes 透明度 50% + 界面背景半透明深色，即可压住白雾又不失玻璃感。
- **Hermes 重启后不跟随？** FrostTracker 每 30ms 兜底轮询 + 事件驱动，进程重启自动重新绑定主窗口，无需手动干预。

## License

MIT
