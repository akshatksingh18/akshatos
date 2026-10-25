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
            ("large-focus", 1100, 760, 180, false), ("transfer", 800, 1100, 92, true),
            ("customize", 800, 1100, 120, false) })
        {
            var window = new MainWindow(store, () => at, true) { Width = width, Height = height };
            window.TimerScale.Value = size; window.Transfer.IsExpanded = details; window.History.IsExpanded = details;
            window.Customize.IsExpanded = name == "customize";
            // Render the actual native client tree independently of the CI runner's desktop
            // resolution. Keeping it parented under an HWND clips tall/large logical viewports.
            var content = (FrameworkElement)window.Content;
            content.Resources.MergedDictionaries.Add(window.Resources);
            window.Content = null;
            content.Width = width; content.Height = height;
            content.Measure(new Size(width, height)); content.Arrange(new Rect(0, 0, width, height)); content.UpdateLayout();
            content.Dispatcher.Invoke(System.Windows.Threading.DispatcherPriority.Render, new Action(() => { }));
            var bitmap = new RenderTargetBitmap(width, height, 96, 96, PixelFormats.Pbgra32);
            bitmap.Render(content); var encoder = new PngBitmapEncoder(); encoder.Frames.Add(BitmapFrame.Create(bitmap));
            using (var file = File.Create(Path.Combine(output, name + ".png"))) encoder.Save(file);
        }
        var early = DateTime.SpecifyKind(DateTime.Today.AddHours(2), DateTimeKind.Unspecified);
        var earlyClock = new DateTimeOffset(early, TimeZoneInfo.Local.GetUtcOffset(early));
        var earlyView = new MainWindow(store, () => earlyClock, true);
        if (!earlyView.DayLabel.Text.StartsWith(early.AddDays(-1).ToString("dddd, d MMMM")))
            throw new InvalidOperationException("The date heading did not follow the 03:00 study-day boundary.");
        var check = new MainWindow(store, () => at, true);
        check.Show(); check.UpdateLayout();
        check.TimerAction.RaiseEvent(new RoutedEventArgs(System.Windows.Controls.Button.ClickEvent));
        if (store.Running) throw new InvalidOperationException("Native Pause did not stop the timer.");
        check.TimerAction.RaiseEvent(new RoutedEventArgs(System.Windows.Controls.Button.ClickEvent));
        check.Close();
        if (store.Running || check.IsVisible) throw new InvalidOperationException("Native X close did not pause and close.");
        app.Shutdown();
    }
}
