// Frost Underlay — 给任意窗口垫一块 Windows 原生模糊背景板
// 独立遮罩窗，用 DWM Mica/Acrylic 材质做实时模糊（不截屏、不占额外性能）。
// 位置/尺寸由 FrostTracker.exe 事件驱动 SetWindowPos 同步到目标窗口正下方，
// 拖拽/缩放/最小化/全屏全部实时跟随。窗口自身点击穿透，不拦截任何鼠标。
//
// 参数（环境变量，可选）：
//   FROST_TARGET   跟随的目标进程名，默认 Hermes
//   FROST_MATERIAL 材质 mica|acrylic，默认 mica
//   FROST_DARK     1 时强制系统深色模式（Mica 暗色变体）
const { app, BrowserWindow, nativeTheme } = require('electron')
const path = require('path')
const { spawn } = require('child_process')

const TARGET = process.env.FROST_TARGET || 'Hermes'
const MATERIAL = process.env.FROST_MATERIAL || 'mica'

// 默认亮色 Mica：系统深色模式下 Mica 用暗色变体（近黑），半透明透出就是一片黑。
// 亮色变体 = 浅色柔和模糊，不黑不花。必须在 app ready 前设置。
// 如需跟随系统，设置 FROST_DARK=1。
if (process.env.FROST_DARK !== '1') {
  nativeTheme.themeSource = 'light'
}

let overlay = null

function createOverlay() {
  overlay = new BrowserWindow({
    width: 800,
    height: 600,
    x: 0,
    y: 0,
    frame: false,
    backgroundMaterial: MATERIAL,     // Windows 内置模糊材质（mica / acrylic）
    backgroundColor: '#00000000',     // 必须全透明，否则盖住材质
    resizable: true,                  // 必须可调：FrostTracker 靠 SetWindowPos 同步尺寸
    movable: false,
    minimizable: false,
    maximizable: false,
    fullscreenable: false,
    skipTaskbar: true,
    focusable: false,                 // 永不抢焦点
    hasShadow: false,
    show: false,
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false
    }
  })

  // 点击穿透：遮罩只做视觉垫底，鼠标事件全部穿过
  overlay.setIgnoreMouseEvents(true, { forward: true })

  overlay.loadFile(path.join(__dirname, 'overlay.html'))

  overlay.once('ready-to-show', () => {
    overlay.show()
    startTracker()
  })

  overlay.on('closed', () => {
    overlay = null
    app.quit()
  })
}

// 把原生窗口句柄传给 FrostTracker.exe，由它事件驱动 SetWindowPos 跟随
function startTracker() {
  try {
    const buf = overlay.getNativeWindowHandle()
    const hwnd = buf.readBigUInt64LE(0).toString()
    console.log('FROST_HWND=' + hwnd)
    const child = spawn(path.join(__dirname, 'FrostTracker.exe'), [hwnd, TARGET], {
      detached: true,          // 独立进程，遮罩窗销毁后 FrostTracker 自动退出（IsWindow 检测）
      stdio: 'ignore'
    })
    child.unref()
  } catch (e) {
    console.log('FROST_TRACK_ERR=' + e.message)
  }
}

app.whenReady().then(createOverlay)
app.on('window-all-closed', () => app.quit())
