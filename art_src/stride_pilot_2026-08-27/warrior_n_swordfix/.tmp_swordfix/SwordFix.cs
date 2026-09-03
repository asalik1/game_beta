using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;

public static class SwordFix
{
    private const int CellWidth = 473;
    private const int FrameCount = 6;

    private static bool IsBladeMask(int xr, int y)
    {
        if (y < 356 || y > 435 || xr < 145)
            return false;

        // The blade runs down-left from the gauntlet in the same place in all
        // six cells. This boundary follows its right edge without entering the cloak.
        double rightEdge = 200.0 - (0.38 * (y - 356));
        return xr <= rightEdge;
    }

    private static bool IsHotRootGlow(int xr, int y, byte r, byte g, byte b, byte a)
    {
        if (a == 0 || y < 330 || y > 365 || xr < 178 || xr > 202)
            return false;

        int max = Math.Max(r, Math.Max(g, b));
        int min = Math.Min(r, Math.Min(g, b));
        return max >= 95 && (max - min) >= 35 && r >= b + 35 && g >= b + 20;
    }

    private static byte Composite(byte foreground, byte background, byte alpha)
    {
        return (byte)((foreground * alpha + background * (255 - alpha) + 127) / 255);
    }

    public static string Process(string inputPath, string outputPath)
    {
        using (var loaded = new Bitmap(inputPath))
        using (var src = new Bitmap(loaded.Width, loaded.Height, PixelFormat.Format32bppArgb))
        {
            using (var g = Graphics.FromImage(src))
            {
                g.CompositingMode = System.Drawing.Drawing2D.CompositingMode.SourceCopy;
                g.DrawImageUnscaled(loaded, 0, 0);
            }

            if (src.Width != CellWidth * FrameCount || src.Height != 473)
                throw new InvalidOperationException("Unexpected source dimensions: " + src.Width + "x" + src.Height);

            using (var dst = new Bitmap(src.Width, src.Height, PixelFormat.Format32bppArgb))
            {
                var rect = new Rectangle(0, 0, src.Width, src.Height);
                var srcData = src.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
                var dstData = dst.LockBits(rect, ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
                int byteCount = Math.Abs(srcData.Stride) * src.Height;
                var inBytes = new byte[byteCount];
                var outBytes = new byte[byteCount];
                Marshal.Copy(srcData.Scan0, inBytes, 0, byteCount);

                var removedByFrame = new int[FrameCount];
                var neutralizedByFrame = new int[FrameCount];

                for (int y = 0; y < src.Height; y++)
                {
                    int row = y * srcData.Stride;
                    for (int x = 0; x < src.Width; x++)
                    {
                        int i = row + x * 4;
                        byte b = inBytes[i + 0];
                        byte g = inBytes[i + 1];
                        byte r = inBytes[i + 2];
                        byte a = inBytes[i + 3];
                        int frame = x / CellWidth;
                        int xr = x - frame * CellWidth;

                        bool removeBlade = IsBladeMask(xr, y);
                        if (removeBlade && a != 0)
                            removedByFrame[frame]++;

                        if (removeBlade)
                        {
                            r = 0;
                            g = 255;
                            b = 0;
                            a = 255;
                        }
                        else
                        {
                            if (IsHotRootGlow(xr, y, r, g, b, a))
                            {
                                byte neutral = (byte)((r * 54 + g * 183 + b * 19 + 128) >> 8);
                                r = neutral;
                                g = neutral;
                                b = neutral;
                                neutralizedByFrame[frame]++;
                            }

                            r = Composite(r, 0, a);
                            g = Composite(g, 255, a);
                            b = Composite(b, 0, a);
                            a = 255;
                        }

                        outBytes[i + 0] = b;
                        outBytes[i + 1] = g;
                        outBytes[i + 2] = r;
                        outBytes[i + 3] = a;
                    }
                }

                // Remove only tiny, detached remnants left in the former blade corridor.
                // Components connected to the arm or cloak are explicitly preserved.
                for (int frame = 0; frame < FrameCount; frame++)
                {
                    int roiLeft = frame * CellWidth + 140;
                    int roiTop = 330;
                    int roiWidth = 66;
                    int roiHeight = 99;
                    var ink = new bool[roiWidth, roiHeight];
                    var seen = new bool[roiWidth, roiHeight];
                    for (int yy = 0; yy < roiHeight; yy++)
                        for (int xx = 0; xx < roiWidth; xx++)
                        {
                            int i = (roiTop + yy) * srcData.Stride + (roiLeft + xx) * 4;
                            ink[xx, yy] = !(outBytes[i + 2] == 0 && outBytes[i + 1] == 255 && outBytes[i + 0] == 0);
                        }

                    for (int sy = 0; sy < roiHeight; sy++)
                        for (int sx = 0; sx < roiWidth; sx++)
                        {
                            if (!ink[sx, sy] || seen[sx, sy]) continue;
                            bool connectedToBody = false;
                            int minGlobalY = roiTop + sy;
                            int maxGlobalY = minGlobalY;
                            var points = new System.Collections.Generic.List<Point>();
                            var queue = new System.Collections.Generic.Queue<Point>();
                            queue.Enqueue(new Point(sx, sy));
                            seen[sx, sy] = true;
                            while (queue.Count > 0)
                            {
                                Point q = queue.Dequeue();
                                points.Add(q);
                                minGlobalY = Math.Min(minGlobalY, roiTop + q.Y);
                                maxGlobalY = Math.Max(maxGlobalY, roiTop + q.Y);
                                if (q.X == roiWidth - 1 || q.Y == 0) connectedToBody = true;
                                for (int dy = -1; dy <= 1; dy++)
                                    for (int dx = -1; dx <= 1; dx++)
                                    {
                                        int nx = q.X + dx, ny = q.Y + dy;
                                        if (nx < 0 || ny < 0 || nx >= roiWidth || ny >= roiHeight || seen[nx, ny] || !ink[nx, ny]) continue;
                                        seen[nx, ny] = true;
                                        queue.Enqueue(new Point(nx, ny));
                                    }
                            }

                            if (!connectedToBody && minGlobalY >= 366 && maxGlobalY <= 427)
                                foreach (Point q in points)
                                {
                                    int i = (roiTop + q.Y) * srcData.Stride + (roiLeft + q.X) * 4;
                                    outBytes[i + 0] = 0;
                                    outBytes[i + 1] = 255;
                                    outBytes[i + 2] = 0;
                                    outBytes[i + 3] = 255;
                                }
                        }
                }

                Marshal.Copy(outBytes, 0, dstData.Scan0, byteCount);
                src.UnlockBits(srcData);
                dst.UnlockBits(dstData);

                string directory = Path.GetDirectoryName(outputPath);
                if (!String.IsNullOrEmpty(directory))
                    Directory.CreateDirectory(directory);
                dst.Save(outputPath, ImageFormat.Png);

                var result = new StringBuilder();
                result.AppendLine("output=" + outputPath);
                result.AppendLine("dimensions=" + dst.Width + "x" + dst.Height);
                for (int f = 0; f < FrameCount; f++)
                    result.AppendLine(String.Format("frame={0} blade_pixels_removed={1} root_glow_pixels_neutralized={2}", f + 1, removedByFrame[f], neutralizedByFrame[f]));
                return result.ToString();
            }
        }
    }

    public static string AnalyzeComponents(string imagePath)
    {
        using (var bmp = new Bitmap(imagePath))
        {
            var report = new StringBuilder();
            for (int frame = 0; frame < FrameCount; frame++)
            {
                int left = frame * CellWidth + 140;
                int top = 320;
                int width = 80;
                int height = 125;
                var ink = new bool[width, height];
                var seen = new bool[width, height];
                for (int yy = 0; yy < height; yy++)
                    for (int xx = 0; xx < width; xx++)
                    {
                        Color p = bmp.GetPixel(left + xx, top + yy);
                        ink[xx, yy] = !(p.R == 0 && p.G == 255 && p.B == 0 && p.A == 255);
                    }

                report.AppendLine("frame=" + (frame + 1));
                for (int sy = 0; sy < height; sy++)
                    for (int sx = 0; sx < width; sx++)
                    {
                        if (!ink[sx, sy] || seen[sx, sy]) continue;
                        int count = 0, minX = sx, maxX = sx, minY = sy, maxY = sy;
                        bool touchesBodyBoundary = false;
                        var queue = new System.Collections.Generic.Queue<Point>();
                        queue.Enqueue(new Point(sx, sy));
                        seen[sx, sy] = true;
                        while (queue.Count > 0)
                        {
                            Point q = queue.Dequeue();
                            count++;
                            minX = Math.Min(minX, q.X); maxX = Math.Max(maxX, q.X);
                            minY = Math.Min(minY, q.Y); maxY = Math.Max(maxY, q.Y);
                            if (q.X == width - 1 || q.Y == 0) touchesBodyBoundary = true;
                            for (int dy = -1; dy <= 1; dy++)
                                for (int dx = -1; dx <= 1; dx++)
                                {
                                    int nx = q.X + dx, ny = q.Y + dy;
                                    if (nx < 0 || ny < 0 || nx >= width || ny >= height || seen[nx, ny] || !ink[nx, ny]) continue;
                                    seen[nx, ny] = true;
                                    queue.Enqueue(new Point(nx, ny));
                                }
                        }
                        report.AppendLine(String.Format("  component pixels={0} bbox=({1},{2})-({3},{4}) body_connected={5}", count, left + minX, top + minY, left + maxX, top + maxY, touchesBodyBoundary));
                    }
            }
            return report.ToString();
        }
    }

    public static string Verify(string inputPath, string outputPath)
    {
        using (var src = new Bitmap(inputPath))
        using (var dst = new Bitmap(outputPath))
        {
            if (src.Width != dst.Width || src.Height != dst.Height)
                throw new InvalidOperationException("Dimension mismatch");

            var report = new StringBuilder();
            report.AppendLine("dimensions=" + dst.Width + "x" + dst.Height);
            for (int frame = 0; frame < FrameCount; frame++)
            {
                long differences = 0;
                long differencesOutsideAllowedRegion = 0;
                long nonGreenInBladeMask = 0;
                long remainingHotRootGlow = 0;
                int edgeNonGreen = 0;

                for (int y = 0; y < dst.Height; y++)
                    for (int xr = 0; xr < CellWidth; xr++)
                    {
                        int x = frame * CellWidth + xr;
                        Color s = src.GetPixel(x, y);
                        Color d = dst.GetPixel(x, y);
                        byte expectedR = Composite(s.R, 0, s.A);
                        byte expectedG = Composite(s.G, 255, s.A);
                        byte expectedB = Composite(s.B, 0, s.A);
                        bool differs = d.R != expectedR || d.G != expectedG || d.B != expectedB || d.A != 255;
                        if (differs)
                        {
                            differences++;
                            bool allowed = xr >= 140 && xr <= 205 && y >= 330 && y <= 435;
                            if (!allowed) differencesOutsideAllowedRegion++;
                        }
                        if (IsBladeMask(xr, y) && !(d.R == 0 && d.G == 255 && d.B == 0 && d.A == 255))
                            nonGreenInBladeMask++;
                        if (IsHotRootGlow(xr, y, d.R, d.G, d.B, d.A))
                            remainingHotRootGlow++;
                        if ((xr == 0 || xr == CellWidth - 1 || y == 0 || y == dst.Height - 1) && !(d.R == 0 && d.G == 255 && d.B == 0 && d.A == 255))
                            edgeNonGreen++;
                    }

                report.AppendLine(String.Format("frame={0} changed_pixels={1} changed_outside_sword_glow_region={2} non_green_pixels_in_blade_mask={3} hot_root_glow_pixels={4} non_green_edge_pixels={5}",
                    frame + 1, differences, differencesOutsideAllowedRegion, nonGreenInBladeMask, remainingHotRootGlow, edgeNonGreen));
            }
            return report.ToString();
        }
    }
}
