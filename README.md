# Hermes Desktop mica effect
# Hermes Desktop 毛玻璃效果

> ⚠️ **使用前先将 Hermes Desktop 默认透明度改为百分之 50**
> Before using: set Hermes Desktop's default window translucency to **50%**.
>
> ⚠️ **务必配合 Windhawk 的 Translucent Windows 插件使用**
> **MUST be used together with the Windhawk "Translucent Windows" mod** —
> it makes the Hermes window itself translucent (this project only provides the
> blur backing, not the window transparency).
> Windhawk: https://windhawk.net · Mod: https://windhawk.net/mods/windhawk-translucent-windows

给 **Hermes Desktop**（Hermes Agent 桌面客户端）垫一块 Windows 原生模糊背景板。用 DWM 内置的 Mica 材质做实时模糊——不截屏、不占额外 GPU、不碰窗口内容，只是一个垫在 Hermes 窗口正下方的「玻璃底」。

A native frosted-glass underlay for the **Hermes Desktop** app. It uses the DWM Mica material for real-time blur — no screen capture, no GPU overhead, no touching your app. Just a glass panel sitting right underneath the Hermes window.

配合 Hermes 的窗口透明度 + 透明背景主题，就是一套完整的**毛玻璃桌面体验**：Hermes 界面半透明，桌面/壁纸从模糊里透出来。

Paired with Hermes' window translucency and a transparent-background theme, it delivers a complete frosted-glass desktop: the Hermes UI turns translucent and your wallpaper glows through the blur.

- 🪟 **实时跟随**：事件驱动（WinEventHook），拖动、缩放、最小化、最大化、全屏全部紧贴，最大滞后 <30ms
  **Tight follow**: event-driven (WinEventHook) — drag, resize, minimize, maximize, fullscreen all tracked, <30ms lag.
- 🧊 **原生材质**：Mica（Win11 系统材质），模糊和抗锯齿都由 DWM 完成，零性能开销
  **Native material**: Mica (Win11), blur + anti-aliasing handled by DWM, zero overhead.
- 🖱️ **点击穿透**：遮罩不拦截任何鼠标事件，纯粹视觉垫底
  **Click-through**: the overlay never intercepts mouse events — pure visual backing.
- 🕳️ **无阴影无任务栏**：`WS_EX_TOOLWINDOW` 实例级样式
  **No shadow / no taskbar**: `WS_EX_TOOLWINDOW` instance-level style.
- 📐 **全屏不溢出**：`DWMWA_EXTENDED_FRAME_BOUNDS` 真实边界，最大化不会把 8px 阴影边距溢到相邻屏
  **No fullscreen overflow**: real bounds via `DWMWA_EXTENDED_FRAME_BOUNDS` — no 8px shadow bleed into adjacent monitors.
- 🔄 **自愈守护**：Hermes 重启自动重新绑定；遮罩被误杀自动复活；Hermes 退出自动关遮罩
  **Self-healing**: re-binds after Hermes restarts, respawns if killed, closes when Hermes exits.

## 效果 / Screenshot

![Frost Underlay on Hermes Desktop](assets/screenshot.jpg)

> Hermes 窗口半透明 + 遮罩垫底 = 毛玻璃质感，桌面从模糊里透出来。
> Hermes window translucent + underlay = frosted glass, desktop glowing through.

> ⚠️ **务必使用深色模式 / DARK MODE REQUIRED**
> 玻璃效果依赖深色主题：Hermes 请使用深色主题 + 半透明深色界面背景，
> 否则 Mica 白雾会让界面泛白（浅色主题下效果不可用）。
> The glass effect requires dark mode: use a dark theme with a semi-transparent
> dark UI background in Hermes, otherwise Mica's white haze washes out the UI.

## 原理 / How it works

```
┌────────────────────────────┐
│  Hermes Desktop（半透明）    │  ← target window
├────────────────────────────┤
│  遮罩窗 Frost Underlay      │  ← Electron window
│  （DWM Mica 材质）           │     click-through, frameless, shadowless
└────────────────────────────┘
        ↓ event-driven SetWindowPos
   FrostTracker.exe (WinEventHook)
```

- **main.js** — Electron 遮罩窗（Mica 材质、点击穿透、自动拉起跟随器 / overlay window, click-through, spawns the tracker）
- **FrostTracker.exe** — C# 跟随器：监听 Hermes 窗口事件实时同步（C# follower, WinEventHook + real-bounds sync）
- **watch.ps1** — 守护脚本：Hermes 在 → 拉遮罩；退出 → 关遮罩；心跳供外部看门狗（daemon: spawn/close with Hermes, heartbeat file）

## 环境要求 / Requirements

- Windows 11（Mica 需要 22621+ / Mica needs 22621+）
- [Electron](https://www.electronjs.org/)（`npm install electron`）
- .NET Framework 4.x（仅编译 FrostTracker 需要，Windows 自带 / only to rebuild FrostTracker, ships with Windows）

## 快速开始 / Quick start

```powershell
# 1. 安装 electron / install electron
npm install electron --save-dev

# 2. 一键启动，跟随 Hermes / one-click start, follows Hermes
powershell -ExecutionPolicy Bypass -File start.ps1
```

或手动 / or manually:

```powershell
npx electron .     # 或 / or electron.exe main.js
```

遮罩窗出现后，拖动 / 缩放 / 全屏 Hermes 都会实时贴合。
Once the overlay appears, drag / resize / fullscreen Hermes and it follows in real time.

## 与 Hermes 搭配的完整玻璃效果 / Full glass setup with Hermes

1. **Windhawk Translucent Windows**：用该插件把 Hermes 窗口设为半透明（约 50%，文字仍清晰，桌面能透进来）
   Use the Windhawk "Translucent Windows" mod to make the Hermes window ~50% translucent (text stays crisp, desktop glows through).
2. **深色主题 + 透明背景**：界面半透明深色，压住 Mica 白雾不泛白 / dark theme + transparent UI background (suppresses Mica's white haze)
3. **本项目的 Mica 遮罩垫底** / this project's Mica underlay
4. **开机自启（可选）**：启动文件夹快捷方式指向 `watch.ps1` / optional autostart via Startup folder shortcut

## 配置 / Configuration

| 环境变量 / Env var | 说明 / Description | 默认 / Default |
|---|---|---|
| `FROST_TARGET` | 跟随的进程名（默认 Hermes）/ target process (Hermes by design) | `Hermes` |
| `FROST_MATERIAL` | 材质 / material: `mica` / `acrylic` | `mica` |
| `FROST_DARK` | `1` = 跟随系统深色模式 / follow system dark mode | 亮色 / light |
| `ELECTRON_PATH` | electron.exe 完整路径 / full path to electron.exe | auto-detect |

## 构建 FrostTracker / Build

```powershell
cd frost-underlay
"C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe" /nologo /target:winexe /out:FrostTracker.exe /r:System.Windows.Forms.dll /r:System.Drawing.dll FrostTracker.cs
```

## 开机自启（可选）/ Autostart (optional)

```powershell
$ws = New-Object -ComObject WScript.Shell
$sc = $ws.CreateShortcut("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\FrostUnderlayWatch.lnk")
$sc.TargetPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
$sc.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PWD\watch.ps1`""
$sc.WindowStyle = 7
$sc.Save()
```

## 常见问题 / FAQ

- **遮罩溢出到其他屏？/ Overflow to other monitors?** 已修复：`DWMWA_EXTENDED_FRAME_BOUNDS` 真实边界。Fixed: real bounds, no shadow bleed.
- **Mica 泛白？/ Haze?** Mica 是浅色材质；Hermes 透明度太高会泛白。建议透明度 50% + 界面半透明深色背景。Mica is a light material; keep Hermes at ~50% translucency with a semi-transparent dark UI to suppress haze.
- **Hermes 重启后不跟随？/ Not following after restart?** 自动重绑，无需干预。Auto re-binds, no action needed.

## License

MIT
