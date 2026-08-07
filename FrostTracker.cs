// FrostTracker — 事件驱动窗口跟随器（Hermes Desktop 专用）
// WinEventHook 监听 Hermes 主窗口的移动/尺寸变化事件，触发时立即
// 取真实边界（DWM 扩展帧边界，不含阴影边距）+ SetWindowPos 同步遮罩窗；
// 30ms Timer 兜底防失步。
// 用法: FrostTracker <overlayHwnd> [targetProcessName]
//   targetProcessName 默认 Hermes。
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;

class FrostTracker {
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [DllImport("user32.dll")] static extern IntPtr SetWinEventHook(uint evMin, uint evMax, IntPtr mod, WinEventDelegate cb, uint pid, uint tid, uint flags);
    [DllImport("user32.dll")] static extern bool UnhookWinEvent(IntPtr hook);
    [DllImport("user32.dll")] static extern bool IsWindow(IntPtr h);
    [DllImport("dwmapi.dll")] static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);
    [DllImport("dwmapi.dll")] static extern int DwmGetWindowAttribute(IntPtr hwnd, int attr, out RECT value, int size);
    [DllImport("user32.dll")] static extern int GetWindowLong(IntPtr h, int idx);
    [DllImport("user32.dll")] static extern int SetWindowLong(IntPtr h, int idx, int v);
    [StructLayout(LayoutKind.Sequential)] struct RECT { public int L, T, R, B; }
    delegate void WinEventDelegate(IntPtr hook, uint evt, IntPtr hwnd, int idObj, int idChild, uint evtThread, uint evtTime);

    const int DWMWA_NCRENDERING_POLICY = 2;
    const int DWMWA_EXTENDED_FRAME_BOUNDS = 9;   // 真实渲染边界（不含 DWM 阴影边距）
    const int DWMNCRP_DISABLED = 1;
    const int GWL_EXSTYLE = -20;
    const int WS_EX_TOOLWINDOW = 0x00000080;   // 工具窗：无阴影、无任务栏（实例级，不影响同类其他窗口）

    const uint EVENT_SYSTEM_MOVESIZESTART   = 0x000A;
    const uint EVENT_SYSTEM_MOVESIZEEND     = 0x000B;
    const uint EVENT_OBJECT_LOCATIONCHANGE  = 0x800B;
    const uint WINEVENT_OUTOFCONTEXT        = 0x0000;
    const uint SWP_NOACTIVATE               = 0x0010;
    const uint SWP_SHOWWINDOW               = 0x0040;

    static IntPtr hermesHwnd, overlayHwnd;
    static string targetName = "Hermes";

    static IntPtr FindTarget() {
        foreach (var p in System.Diagnostics.Process.GetProcessesByName(targetName)) {
            if (p.MainWindowHandle != IntPtr.Zero) return p.MainWindowHandle;
        }
        return IntPtr.Zero;
    }

    static void Sync() {
        if (hermesHwnd == IntPtr.Zero || !IsWindow(hermesHwnd)) {
            hermesHwnd = FindTarget();   // 目标重启后自动重新绑定
            if (hermesHwnd == IntPtr.Zero) return;
        }
        RECT r;
        // 优先真实边界（不含阴影边距，避免最大化时 -8px 溢出到相邻屏）
        bool ok = DwmGetWindowAttribute(hermesHwnd, DWMWA_EXTENDED_FRAME_BOUNDS, out r, Marshal.SizeOf(typeof(RECT))) == 0;
        if (!ok) ok = GetWindowRect(hermesHwnd, out r);
        if (ok) {
            SetWindowPos(overlayHwnd, hermesHwnd, r.L, r.T, r.R - r.L, r.B - r.T,
                         SWP_NOACTIVATE | SWP_SHOWWINDOW);
        }
    }

    static void OnEvent(IntPtr hook, uint evt, IntPtr hwnd, int idObj, int idChild, uint evtThread, uint evtTime) {
        if (hwnd == hermesHwnd || hermesHwnd == IntPtr.Zero) Sync();
    }

    static void Main(string[] args) {
        if (args.Length < 1) return;
        overlayHwnd = new IntPtr(long.Parse(args[0]));
        if (args.Length > 1 && !string.IsNullOrWhiteSpace(args[1])) targetName = args[1].Trim();
        hermesHwnd  = FindTarget();

        // 关掉遮罩窗的 DWM 系统阴影：
        // 1) NCRENDERING_POLICY 禁用 DWM 非客户区渲染（对 Mica 窗口读回无效，双保险）
        // 2) WS_EX_TOOLWINDOW 工具窗样式——真正生效的方案（实例级，不影响目标窗口）
        int noRender = DWMNCRP_DISABLED;
        DwmSetWindowAttribute(overlayHwnd, DWMWA_NCRENDERING_POLICY, ref noRender, sizeof(int));
        int ex = GetWindowLong(overlayHwnd, GWL_EXSTYLE);
        SetWindowLong(overlayHwnd, GWL_EXSTYLE, ex | WS_EX_TOOLWINDOW);

        // 监听目标窗口移动/尺寸变化（系统拖拽帧级触发）
        SetWinEventHook(EVENT_SYSTEM_MOVESIZESTART, EVENT_SYSTEM_MOVESIZEEND,
                        IntPtr.Zero, OnEvent, 0, 0, WINEVENT_OUTOFCONTEXT);
        SetWinEventHook(EVENT_OBJECT_LOCATIONCHANGE, EVENT_OBJECT_LOCATIONCHANGE,
                        IntPtr.Zero, OnEvent, 0, 0, WINEVENT_OUTOFCONTEXT);

        Sync();  // 初始对齐

        // 兜底：30ms 轮询，防事件漏发；遮罩窗销毁则退出
        var timer = new Timer { Interval = 30 };
        timer.Tick += (s, e) => {
            if (!IsWindow(overlayHwnd)) Environment.Exit(0);
            Sync();
        };
        timer.Start();
        Application.Run();
    }
}
