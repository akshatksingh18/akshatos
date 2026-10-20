using System.IO;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using StudyDesk.Core;

namespace StudyDesk.App;

internal static class NativeEvidence
{
    public static void Capture(string output)
    {
        Directory.CreateDirectory(output);
        var app = new Application();
        var at = new DateTimeOffset(2026, 10, 20, 15, 0, 0, TimeSpan.Zero);
        var root = Path.Combine(Path.GetTempPath(), "study-desk-synthetic-" + Guid.NewGuid()); Directory.CreateDirectory(root);
        var store = new StudyStore(Path.Combine(root, "state.json"));
        store.SetPreferences(store.State.Preferences with { Topic = "Read a chapter" });
        store.Start(at.AddHours(-2), "Etc/UTC"); store.Pause(at.AddMinutes(-30)); store.Start(at.AddMinutes(-15), "Etc/UTC");
        foreach (var (name, width, height, size, details) in new[] {
            ("normal", 720, 650, 92, false), ("narrow-large-text", 480, 540, 180, false),
            ("large-focus", 1100, 760, 180, false), ("transfer", 800, 1100, 92, true) })
        {
            var window = new MainWindow(store, () => at, true) { Width = width, Height = height };
            window.TimerScale.Value = size; window.Transfer.IsExpanded = details; window.History.IsExpanded = details;
            window.Show(); window.UpdateLayout();
            var bitmap = new RenderTargetBitmap((int)window.ActualWidth, (int)window.ActualHeight, 96, 96, PixelFormats.Pbgra32);
            bitmap.Render(window); var encoder = new PngBitmapEncoder(); encoder.Frames.Add(BitmapFrame.Create(bitmap));
            using (var file = File.Create(Path.Combine(output, name + ".png"))) encoder.Save(file);
            // Do not trigger the real close-pause lifecycle during a render matrix.
            window.Hide();
        }
        app.Shutdown();
    }
}
