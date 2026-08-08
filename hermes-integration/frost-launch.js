/**
 * Frost Underlay Launcher — Hermes Desktop 集成插件（可选）
 *
 * 让遮罩跟随 Hermes 的启动自动恢复，不需要注册表 / 启动文件夹。
 * 原理：Hermes 桌面插件在应用打开时必加载 → 本插件检查 watch.ps1 的
 * 心跳文件新鲜度 → 不新鲜就通过 hermesDesktop.terminal.start + write
 * 拉起 watch.ps1（单实例锁保证幂等，不会双开）。
 *
 * 安装：复制到 <HERMES_HOME>/desktop-plugins/frost-launch/plugin.js
 * （HERMES_HOME 默认 D:\Hermes），重启 Hermes 即生效。
 * 依赖 watch.ps1 的心跳机制：每 2s 向 watch.heartbeat 写 UTC 时间戳。
 */
export default {
  id: 'frost-launch',
  name: 'Frost Underlay Launcher',
  defaultEnabled: true,
  register() {
    const h = window.hermesDesktop
    const HEARTBEAT = 'D:\\Hermes\\frost-underlay\\watch.heartbeat'
    const WATCH_DIR = 'D:\\Hermes\\frost-underlay'
    const LAUNCH =
      'powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden ' +
      '-File D:\\Hermes\\frost-underlay\\watch.ps1'
    let launching = false

    async function heartbeatFresh() {
      try {
        const text = await h.readFileText(HEARTBEAT)
        const t = Date.parse(text.trim())
        if (!t) return false
        return Date.now() - t < 25000
      } catch (e) {
        return false
      }
    }

    async function launch() {
      if (launching) return
      launching = true
      try {
        const term = await h.terminal.start({ cwd: WATCH_DIR })
        h.terminal.write(term.id, LAUNCH + '\r')
        console.log('frost-launch: watcher launch command sent')
      } catch (e) {
        console.error('frost-launch: launch failed', e)
      }
      launching = false
    }

    // register-time check + 30s watchdog poll
    heartbeatFresh().then(fresh => {
      if (!fresh) launch()
    })
    setInterval(() => {
      heartbeatFresh().then(fresh => {
        if (!fresh) launch()
      })
    }, 30000)
  },
}
