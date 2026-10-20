using System.Windows;

namespace StudyDesk.App;

public static class Program
{
    [STAThread]
    public static int Main(string[] args)
    {
        if (args.Length == 2 && args[0] == "--capture")
        { NativeEvidence.Capture(args[1]); return 0; }
        using var mutex = new Mutex(true, "Local\\AkshatOS-StudyDesk-" + Environment.UserName, out var first);
        if (!first) { MessageBox.Show("Study Desk is already open. Use its existing window.", "AkshatOS Study Desk"); return 0; }
        var app = new Application { ShutdownMode = ShutdownMode.OnMainWindowClose };
        try { app.Run(new MainWindow()); return 0; }
        catch (Exception ex)
        { MessageBox.Show("Study Desk could not open. Your saved files were not reset.\n\n" + ex.Message, "Study Desk recovery"); return 1; }
    }
}
