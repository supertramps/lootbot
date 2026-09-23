using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Threading;

public static class LootBotCapture {
    [StructLayout(LayoutKind.Sequential)] struct Point { public int X; public int Y; }
    [StructLayout(LayoutKind.Sequential)] struct Rect { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] static extern bool ClientToScreen(IntPtr window, ref Point point);
    [DllImport("user32.dll")] static extern bool GetClientRect(IntPtr window, out Rect rect);
    [DllImport("user32.dll")] static extern bool IsIconic(IntPtr window);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr window);
    [DllImport("user32.dll")] static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] static extern bool SetProcessDpiAwarenessContext(IntPtr context);

    static bool IsWoW(Process p) {
        return p.ProcessName.Equals("WowClassic", StringComparison.OrdinalIgnoreCase) ||
            p.ProcessName.Equals("WowClassicT", StringComparison.OrdinalIgnoreCase) ||
            p.ProcessName.Equals("Wow", StringComparison.OrdinalIgnoreCase) ||
            p.ProcessName.Equals("WowT", StringComparison.OrdinalIgnoreCase);
    }
    static IntPtr FindWindow(int pid) {
        foreach (Process p in Process.GetProcesses()) {
            using (p) {
                try {
                    if ((pid == 0 || p.Id == pid) && IsWoW(p) && p.MainWindowHandle != IntPtr.Zero &&
                        IsWindowVisible(p.MainWindowHandle) && !IsIconic(p.MainWindowHandle)) return p.MainWindowHandle;
                } catch (InvalidOperationException) {} catch (System.ComponentModel.Win32Exception) {}
            }
        }
        return IntPtr.Zero;
    }
    public static byte[] Decode(Bitmap image, int cell) {
        if (image.Width != 128 * cell || image.Height != 16 * cell) return null;
        byte[] data = new byte[256];
        for (int i = 0; i < 2048; i++) {
            Color c = image.GetPixel((i % 128) * cell + cell / 2, (i / 128) * cell + cell / 2);
            int level = (c.R + c.G + c.B) / 3;
            if (level > 85 && level < 170) return null;
            if (level >= 170) data[i / 8] |= (byte)(1 << (7 - i % 8));
        }
        if (data[0] != 76 || data[1] != 66 || data[2] != 48 || (data[3] != 49 && data[3] != 50)) return null;
        return data;
    }
    public static string SelfTest(string base64) {
        byte[] original = Convert.FromBase64String(base64);
        const int cell = 1;
        using (Bitmap bitmap = new Bitmap(128 * cell, 16 * cell)) {
            using (Graphics g = Graphics.FromImage(bitmap)) {
                g.Clear(Color.Black);
                for (int i = 0; i < 2048; i++) {
                    if ((original[i / 8] & (1 << (7 - i % 8))) != 0)
                        g.FillRectangle(Brushes.White, (i % 128) * cell, (i / 128) * cell, cell, cell);
                }
            }
            byte[] decoded = Decode(bitmap, cell);
            if (decoded == null) throw new Exception("Synthetic marker was not decoded");
            for (int i = 0; i < 256; i++) if (decoded[i] != original[i]) throw new Exception("Pixel byte mismatch");
            bitmap.SetPixel(cell / 2, cell / 2, Color.Gray);
            if (Decode(bitmap, cell) != null) throw new Exception("Ambiguous pixel accepted");
            return Convert.ToBase64String(decoded);
        }
    }
    public static void Run(int x, int y, int cell, int pollMs, int targetPid) {
        try { if (!SetProcessDpiAwarenessContext(new IntPtr(-4))) SetProcessDPIAware(); }
        catch (EntryPointNotFoundException) { SetProcessDPIAware(); }
        string lastStatus = "";
        IntPtr window = IntPtr.Zero;
        DateTime nextSearch = DateTime.MinValue;
        using (Bitmap bitmap = new Bitmap(128 * cell, 16 * cell, PixelFormat.Format24bppRgb))
        using (Graphics graphics = Graphics.FromImage(bitmap)) {
            while (true) {
                if (DateTime.UtcNow >= nextSearch) {
                    window = FindWindow(targetPid);
                    nextSearch = DateTime.UtcNow.AddSeconds(2);
                }
                string status = null;
                Rect rect;
                if (window == IntPtr.Zero || IsIconic(window) || !IsWindowVisible(window)) {
                    status = "Waiting for a visible WoW window.";
                } else if (!GetClientRect(window, out rect) || rect.Right < x + bitmap.Width || rect.Bottom < y + bitmap.Height) {
                    status = "WoW window is too small for the marker region.";
                } else {
                    Point origin = new Point { X = x, Y = y };
                    if (!ClientToScreen(window, ref origin)) {
                        status = "Could not locate the WoW client area.";
                    } else {
                        try {
                            graphics.CopyFromScreen(origin.X, origin.Y, 0, 0, bitmap.Size, CopyPixelOperation.SourceCopy);
                            byte[] bytes = Decode(bitmap, cell);
                            if (bytes != null) {
                                Console.WriteLine("{\"packet\":\"" + Convert.ToBase64String(bytes) + "\"}");
                                lastStatus = "";
                            } else status = "Waiting for relay transmissions (the strip is hidden while idle).";
                        } catch (System.ComponentModel.Win32Exception) {
                            status = "Screen capture unavailable. Use a visible windowed WoW session.";
                        }
                    }
                }
                if (status != null && status != lastStatus) {
                    Console.WriteLine("{\"status\":\"" + status + "\"}"); lastStatus = status;
                }
                Thread.Sleep(pollMs);
            }
        }
    }
}
