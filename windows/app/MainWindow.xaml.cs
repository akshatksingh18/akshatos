using System.ComponentModel;
using System.Globalization;
using System.IO;
using System.Windows;
using System.Windows.Threading;
using Microsoft.Win32;
using StudyDesk.Core;

namespace StudyDesk.App;

public partial class MainWindow : Window
{
    private readonly StudyStore store;
    private readonly bool evidence;
    private readonly Func<DateTimeOffset> now;
    private readonly DispatcherTimer timer = new() { Interval = TimeSpan.FromSeconds(1) };
    private bool ready, transferBusy, saveFailed;
    private DateTimeOffset lastTick, lastCheckpoint;

    public MainWindow(StudyStore? fixture = null, Func<DateTimeOffset>? clock = null, bool evidence = false)
    {
        this.evidence = evidence; now = clock ?? (() => DateTimeOffset.UtcNow);
        store = fixture ?? new StudyStore(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "AkshatOS", "StudyDesk", "state.json"));
        if (!evidence) store.RecoverInterrupted();
        InitializeComponent();
        var p = store.State.Preferences;
        Width = p.Width; Height = p.Height; TimerScale.Value = p.TimerSize; Remaining.FontSize = p.TimerSize;
        Pin.IsChecked = p.Pinned; Topmost = p.Pinned;
        TargetInput.Text = (p.TargetSeconds / 3600.0).ToString("0.##", CultureInfo.InvariantCulture); TopicInput.Text = p.Topic;
        if (p.Left is double left && p.Top is double top && left + p.Width > SystemParameters.VirtualScreenLeft + 80 &&
            left < SystemParameters.VirtualScreenLeft + SystemParameters.VirtualScreenWidth - 80 &&
            top >= SystemParameters.VirtualScreenTop && top < SystemParameters.VirtualScreenTop + SystemParameters.VirtualScreenHeight - 80)
        { WindowStartupLocation = WindowStartupLocation.Manual; Left = left; Top = top; }
        ready = true; lastTick = lastCheckpoint = now();
        Notice.Text = store.RecoveryMessage ?? "Pause for breaks. Keep this window visible while you study.";
        Closing += OnClosing;
        StateChanged += (_, _) => { if (WindowState == WindowState.Minimized) Pause("Paused because the window was minimized."); };
        if (!evidence)
        {
            SystemEvents.SessionSwitch += SessionChanged;
            SystemEvents.PowerModeChanged += PowerChanged;
            timer.Tick += Tick; timer.Start();
        }
        Render();
    }

    private void Run(Action action)
    {
        try { action(); saveFailed = false; }
        catch (Exception ex) { Notice.Text = "Not saved: " + ex.Message + " Your existing records were kept. Retry before closing."; saveFailed = true; }
        Render();
    }
    private void Tick(object? sender, EventArgs e)
    {
        var current = now();
        if (store.Running && (current < lastTick || current - lastTick > TimeSpan.FromSeconds(10)))
            PauseAt(lastTick, "Paused at the last visible timer update after a clock change or interruption. Resume manually.");
        if (store.Running && current - lastCheckpoint >= TimeSpan.FromSeconds(15))
        { Run(() => store.Checkpoint(current)); lastCheckpoint = current; }
        lastTick = current; Render();
    }
    private void ToggleTimer(object sender, RoutedEventArgs e)
    {
        Run(() =>
        {
            if (store.Running) { store.Pause(now()); Notice.Text = "Paused. Break time is not counted."; }
            else { store.Start(now()); lastTick = lastCheckpoint = now(); Notice.Text = "Studying. Pause whenever you take a break."; }
        });
    }
    private void Pause(string reason) => PauseAt(now(), reason);
    private void PauseAt(DateTimeOffset at, string reason)
    {
        if (!store.Running) return;
        Run(() => { store.Pause(at); Notice.Text = reason; });
    }
    private void SessionChanged(object sender, SessionSwitchEventArgs e)
    {
        if (e.Reason is SessionSwitchReason.SessionLock or SessionSwitchReason.SessionLogoff or SessionSwitchReason.ConsoleDisconnect or SessionSwitchReason.RemoteDisconnect)
            Dispatcher.Invoke(() => Pause("Paused because Windows was locked or disconnected. Resume when you are ready."));
    }
    private void PowerChanged(object sender, PowerModeChangedEventArgs e)
    {
        if (e.Mode == PowerModes.Suspend) Dispatcher.Invoke(() => Pause("Paused before sleep. Resume when you are ready."));
    }
    private void OnClosing(object? sender, CancelEventArgs e)
    {
        Pause("Paused because Study Desk was closed.");
        if (saveFailed) { e.Cancel = true; return; }
        Run(() => store.SetPreferences(CurrentPreferences()));
        if (saveFailed) { e.Cancel = true; return; }
        if (!evidence)
        { timer.Stop(); SystemEvents.SessionSwitch -= SessionChanged; SystemEvents.PowerModeChanged -= PowerChanged; }
    }
    private Preferences CurrentPreferences() => store.State.Preferences with
    { Width = RestoreBounds.IsEmpty ? Width : RestoreBounds.Width, Height = RestoreBounds.IsEmpty ? Height : RestoreBounds.Height,
      Left = RestoreBounds.IsEmpty ? Left : RestoreBounds.Left, Top = RestoreBounds.IsEmpty ? Top : RestoreBounds.Top,
      TimerSize = TimerScale.Value, Pinned = Pin.IsChecked == true };
    private void PreferenceChanged(object sender, RoutedEventArgs e)
    { if (ready) { Topmost = Pin.IsChecked == true; Run(() => store.SetPreferences(CurrentPreferences())); } }
    private void ScaleChanged(object sender, RoutedPropertyChangedEventArgs<double> e)
    { if (Remaining is not null) Remaining.FontSize = e.NewValue; }
    private void SavePreferences(object sender, RoutedEventArgs e)
    {
        Run(() =>
        {
            if (!double.TryParse(TargetInput.Text, NumberStyles.Float, CultureInfo.InvariantCulture, out var hours) ||
                !double.IsFinite(hours) || hours is < 0.5 or > 24)
                throw new InvalidDataException("Choose a daily aim from 0.5 to 24 hours.");
            store.SetPreferences(CurrentPreferences() with { TargetSeconds = (int)(hours * 3600), Topic = TopicInput.Text.Trim() });
            Notice.Text = "Preferences saved. Existing study days retain their recorded aim.";
        });
    }
    public void Render()
    {
        if (!ready) return;
        var current = now(); var studied = store.Studied(current); var target = store.Target(current);
        DayLabel.Text = $"{DateTime.Now:dddd, d MMMM} · study day starts at 03:00";
        Remaining.Text = StudyClock.Display(Math.Max(0, target - studied));
        RemainingLabel.Text = studied >= target ? "Daily aim reached · study time still counts" : "Remaining today";
        Studied.Text = $"{StudyClock.Display(studied)} studied today";
        RunState.Text = store.Running ? "Studying" : studied > 0 ? "Paused" : "Ready when you are";
        TimerAction.Content = store.Running ? "Pause studying" : studied > 0 ? "Resume studying" : "Start studying";
        TimerAction.IsEnabled = true; // Pause must remain reachable while provider I/O is pending.
        Progress.Value = Math.Clamp(studied / target, 0, 1);
        TopicLabel.Text = store.State.Sessions.LastOrDefault(x => x.End is null)?.Topic ?? store.State.Preferences.Topic;
        FolderLabel.Text = store.State.Preferences.LinkedFolder is null ? "No folder linked. Manual transfer is available." : "Folder: " + store.State.Preferences.LinkedFolder;
        PhoneAsOf.Text = store.State.PhoneAsOf is DateTimeOffset date ? $"Includes phone sessions exported {date.LocalDateTime:g}. Newer phone time may not be here yet." : "Laptop sessions only until phone records are imported.";
        Sessions.ItemsSource = store.State.Sessions.OrderByDescending(x => x.Start).Select(x =>
            $"{x.Start.LocalDateTime:g} · {(x.End is null ? "Running" : StudyClock.Display((x.End.Value - x.Start).TotalSeconds))} · {(x.OriginID is null ? "Laptop" : "iPhone")}{(x.Topic.Length == 0 ? "" : " · " + x.Topic)}").ToArray();
        History.Header = $"Recorded sessions ({store.State.Sessions.Length})";
    }
    private async Task Work(Func<string> operation)
    {
        if (transferBusy) return;
        transferBusy = true; Render(); Notice.Text = "Checking files… Local study records remain saved.";
        try { Notice.Text = await Task.Run(operation); }
        catch (Exception ex) { Notice.Text = "Transfer not confirmed: " + ex.Message; }
        finally { transferBusy = false; Render(); }
    }
    private void ExportManual(object sender, RoutedEventArgs e)
    {
        var picker = new SaveFileDialog { Filter = "Study exchange (*.json)|*.json", FileName = $"study-laptop-{store.State.SourceID:D}.json" };
        if (picker.ShowDialog() == true) Run(() => { StudyStore.AtomicWrite(picker.FileName, Coding.Encode(store.Export(now()))); Notice.Text = "Finished laptop sessions exported. Move the file to your phone, then preview its import."; });
    }
    private async void ImportManual(object sender, RoutedEventArgs e)
    {
        var picker = new OpenFileDialog { Filter = "Study exchange (*.json)|*.json" };
        if (picker.ShowDialog() == true) await ImportFile(picker.FileName);
    }
    private async Task ImportFile(string path)
    {
        if (transferBusy) return;
        Exchange? data = null;
        await Work(() => { data = Coding.Decode<Exchange>(StudyStore.ReadBounded(path)); return "Phone file ready to review."; });
        if (data is null) return;
        Run(() =>
        {
            if (MessageBox.Show($"Review {data.Sessions.Length} finished phone sessions exported {data.ExportedAt.LocalDateTime:g}. Duplicate sessions add no time. Conflicts refuse the whole import. Continue?", "Import phone study", MessageBoxButton.OKCancel) != MessageBoxResult.OK) return;
            var added = store.Import(data, now()); Notice.Text = $"Imported {added} new phone sessions. No existing record was replaced.";
        });
    }
    private void ChooseFolder(object sender, RoutedEventArgs e)
    {
        var picker = new OpenFolderDialog { Title = "Choose a dedicated AkshatOS transfer folder" };
        if (picker.ShowDialog() == true) Run(() => { store.SetPreferences(CurrentPreferences() with { LinkedFolder = picker.FolderName }); Notice.Text = "Folder linked. Use Send / Check explicitly; arrival speed still needs testing."; });
    }
    private void UnlinkFolder(object sender, RoutedEventArgs e) => Run(() => { store.SetPreferences(CurrentPreferences() with { LinkedFolder = null }); Notice.Text = "Folder unlinked. Local records are unchanged."; });
    private async void SendLinked(object sender, RoutedEventArgs e)
    {
        if (store.State.Preferences.LinkedFolder is not string folder) { Notice.Text = "Choose a transfer folder first."; return; }
        // Capture immutable bytes before background I/O; the timer may continue locally.
        var data = Coding.Encode(store.Export(now())); var source = store.State.SourceID;
        await Work(() =>
        {
            if (!Directory.Exists(folder)) throw new IOException("The linked folder is unavailable.");
            var file = Path.Combine(folder, $"study-laptop-{source:D}.json");
            StudyStore.AtomicWrite(file, data);
            StudyStore.AtomicWrite(file + ".sha256", System.Text.Encoding.UTF8.GetBytes(Convert.ToHexStringLower(System.Security.Cryptography.SHA256.HashData(data))));
            return "Written to the linked folder. Delivery to the phone is not yet confirmed.";
        });
    }
    private async void ReadLinked(object sender, RoutedEventArgs e)
    {
        if (store.State.Preferences.LinkedFolder is not string folder) { Notice.Text = "Choose a transfer folder first."; return; }
        string[] files = [];
        await Work(() =>
        {
            files = Directory.GetFiles(folder, "study-iphone-*.json");
            if (files.Length > 8) throw new InvalidDataException("More than eight phone files. Select the intended export manually.");
            return files.Length == 0 ? "No phone exchange file arrived yet. Local history is unchanged." : $"Found {files.Length} phone file(s) to review.";
        });
        foreach (var file in files.Take(8)) await ImportFile(file);
    }
}
