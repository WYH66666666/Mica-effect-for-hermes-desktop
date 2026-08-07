# Frost Underlay

给任意 Windows 窗口垫一块 **原生模糊背景板**。用 DWM 内置的 Mica / Acrylic 材质做实时模糊——不截屏、不占额外 GPU、不碰窗口内容，只是一个垫在目标窗口正下方的「玻璃底」。

- 🪟 **实时跟随**：事件驱动（WinEventHook），拖动、缩放、最小化、最大化、全屏全部紧贴，最大滞后 <30ms
- 🧊 **原生材质**：Mica（Win11）/ Acrylic，系统级模糊，透明抗锯齿都由 DWM 完成
- 🖱️ **点击穿透**：遮罩不拦截任何鼠标事件，纯粹视觉垫底
- 🕳️ **无阴影无任务栏**：`WS_EX_TOOLWINDOW` 实例级样式，干净利落
- 📐 **全屏不溢出**：用 `DWMWA_EXTENDED_FRAME_BOUNDS` 取真实边界，最大化时不会把 8px 阴影边距溢到相邻屏
- 🔄 **自愈守护**：目标窗口重启后自动重新绑定；遮罩被误杀自动复活

## 效果

> 目标窗口半透明 + 遮罩垫底 = 毛玻璃质感，桌面/壁纸从模糊里透出来。
> （README 截图待补充）

## 原理

```
┌────────────────────────────┐
│  目标窗口（半透明）          │  ← 你要美化的应用
├────────────────────────────┤
│  遮罩窗 Frost Underlay      │  ← 本项目的 Electron 窗口
│  （DWM Mica/Acrylic 模糊）   │     点击穿透、无边框、无阴影
└────────────────────────────┘
        ↓ 事件驱动 SetWindowPos
   FrostTracker.exe (WinEventHook)
```

- **main.js** — Electron 遮罩窗（Mica/Acrylic 材质、点击穿透）
- **FrostTracker.exe** — C# 跟随器：监听目标窗口移动/尺寸事件，实时同步遮罩窗位置尺寸
- **watch.ps1** — 可选守护：目标在 → 自动拉遮罩；目标退出 → 自动关遮罩；心跳文件供外部看门狗

## 环境要求

- Windows 11（Mica 需要 22621+；Acrylic 在 Win10 1803+ 可用）
- [Electron](https://www.electronjs.org/)（任意现代版本，开发用 `npm install electron` 即可）
- .NET Framework 4.x（仅编译 FrostTracker 需要，Windows 自带）

## 快速开始

```powershell
# 1. 安装 electron（或设置 ELECTRON_PATH 指向已有 electron.exe）
npm install electron --save-dev

# 2. 一键启动，默认跟随 Hermes
powershell -ExecutionPolicy Bypass -File start.ps1

# 3. 跟随其他程序
powershell -ExecutionPolicy Bypass -File start.ps1 -Target notepad
```

或手动：

```powershell
$env:FROST_TARGET = "notepad"        # 跟随的目标进程名
npx electron .                        # 或 electron.exe main.js
```

## 配置

| 环境变量 | 说明 | 默认 |
|---|---|---|
| `FROST_TARGET` | 跟随的目标进程名（`Get-Process` 名称，不含 .exe） | `Hermes` |
| `FROST_MATERIAL` | 材质：`mica` / `acrylic` | `mica` |
| `FROST_DARK` | `1` 时跟随系统深色模式（Mica 暗色变体） | 亮色 |
| `ELECTRON_PATH` | electron.exe 完整路径（watch/start 脚本用） | 自动探测 |

## 构建 FrostTracker

```powershell
cd frost-underlay
"C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe" /nologo /target:winexe /out:FrostTracker.exe /r:System.Windows.Forms.dll /r:System.Drawing.dll FrostTracker.cs
```

## 开机自启（可选）

启动文件夹放一个快捷方式指向 `watch.ps1` 即可：

```powershell
$ws = New-Object -ComObject WScript.Shell
$sc = $ws.CreateShortcut("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\FrostUnderlayWatch.lnk")
$sc.TargetPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
$sc.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PWD\watch.ps1`""
$sc.WindowStyle = 7
$sc.Save()
```

## 常见问题

- **遮罩溢出到其他屏？** 已修复：跟随器优先取 `DWMWA_EXTENDED_FRAME_BOUNDS`（真实边界），最大化窗口不会带出阴影边距。若仍有异常，确认 FrostTracker.exe 是最新编译版本。
- **Mica 效果像白雾/发灰？** Mica 本身是浅色半透材质；目标窗口透明度过高时白雾会透出。降低目标窗口透明度，或改用 `FROST_MATERIAL=acrylic`。
- **目标窗口重开（进程重启）后不跟随？** FrostTracker 每 30ms 兜底轮询 + 事件驱动，进程重启会自动重新绑定主窗口，无需重启遮罩。

## License

MIT
