using System.Security.Cryptography;

namespace StudyDesk.Core;

public sealed class StudyStore
{
    private readonly string path;
    private readonly Action<byte[]> save;
    public DeskState State { get; private set; }
    public bool Running => State.Sessions.Any(x => x.End is null);
    public string? RecoveryMessage { get; private set; }

    public StudyStore(string path, Action<byte[]>? save = null)
    {
        this.path = path;
        this.save = save ?? (bytes => AtomicWrite(path, bytes));
        State = File.Exists(path) ? Coding.Decode<DeskState>(ReadBounded(path)) : DeskState.Empty();
        ValidateState(State);
    }

    private static void ValidateState(DeskState state)
    {
        if (state.Version != 1 || state.SourceID == Guid.Empty || state.Revision < 0 ||
            state.Preferences.TargetSeconds is < 1800 or > 86400 || state.Preferences.Topic.Length > 200 ||
            !double.IsFinite(state.Preferences.Width) || !double.IsFinite(state.Preferences.Height) ||
            !double.IsFinite(state.Preferences.TimerSize) || state.Preferences.Width is < 480 or > 10000 ||
            state.Preferences.Height is < 440 or > 10000 || state.Preferences.TimerSize is < 40 or > 180 ||
            (state.Preferences.Left is double left && !double.IsFinite(left)) ||
            (state.Preferences.Top is double top && !double.IsFinite(top)))
            throw new InvalidDataException("The saved Study Desk data is invalid. Keep it for recovery; do not reset it.");
        _ = StudyClock.Validate(state.Sessions);
    }

    private void Commit(DeskState state)
    {
        state = state with { Revision = checked(State.Revision + 1), Sessions = StudyClock.Validate(state.Sessions) };
        ValidateState(state);
        save(Coding.Encode(state)); // A failed write never changes the live state.
        State = state;
    }

    public void SetPreferences(Preferences preferences) => Commit(State with { Preferences = preferences });
    public void Start(DateTimeOffset now, string? zone = null)
    {
        if (Running) return;
        var p = State.Preferences;
        var target = Target(now, zone ?? StudyClock.SystemZone());
        Commit(State with { Sessions = [.. State.Sessions, new Session(Guid.NewGuid(), now, null,
            zone ?? StudyClock.SystemZone(), target, p.Topic.Trim())], Checkpoint = now });
    }
    public void Pause(DateTimeOffset now)
    {
        var running = State.Sessions.FirstOrDefault(x => x.End is null);
        if (running is null) return;
        var closed = running with { End = StudyClock.Max(running.Start, now) };
        var values = State.Sessions.Where(x => x.Id != running.Id).ToList();
        if ((closed.End!.Value - closed.Start).TotalSeconds >= 5) values.Add(closed);
        Commit(State with { Sessions = values.ToArray(), Checkpoint = null });
    }
    public void Checkpoint(DateTimeOffset now)
    {
        if (Running) Commit(State with { Checkpoint = now });
    }
    public void RecoverInterrupted()
    {
        if (!Running) return;
        var start = State.Sessions.Single(x => x.End is null).Start;
        Pause(StudyClock.Max(start, State.Checkpoint ?? start));
        RecoveryMessage = "Recovered paused at the last saved checkpoint. Time after that checkpoint was not counted.";
    }
    public double Studied(DateTimeOffset now, string? zone = null)
    {
        var day = StudyClock.Day(now, zone ?? StudyClock.SystemZone());
        return State.Sessions.Sum(x => StudyClock.Seconds(x, day, now));
    }
    public int Target(DateTimeOffset now, string? zone = null)
    {
        var day = StudyClock.Day(now, zone ?? StudyClock.SystemZone());
        return State.Sessions.OrderBy(x => x.Start).FirstOrDefault(x => StudyClock.Seconds(x, day, now) > 0)?.TargetSeconds
            ?? State.Preferences.TargetSeconds;
    }
    public Exchange Export(DateTimeOffset now) => new("akshatos-study-exchange", 1, State.SourceID, "laptop",
        State.Revision, now, State.Sessions.Where(x => x.OriginID is null && x.End is not null)
            .Select(x => x with { OriginRevision = 0 }).ToArray());

    public int Import(Exchange payload, DateTimeOffset now)
    {
        if (payload.Format != "akshatos-study-exchange" || payload.Version != 1 || payload.Device != "iphone" ||
            payload.SourceID == Guid.Empty || payload.SourceID == State.SourceID || payload.Revision < 0 ||
            payload.ExportedAt > now.AddMinutes(2) || payload.Sessions.Any(x => x.End is null || x.OriginID is not null))
            throw new InvalidDataException("Choose an AkshatOS finished-session exchange file.");
        _ = StudyClock.Validate(payload.Sessions, now);
        var previous = State.Sessions.Where(x => x.OriginID == payload.SourceID).ToArray();
        if (previous.Length > 0 && payload.Revision < previous.Max(x => x.OriginRevision))
            throw new InvalidDataException("This phone file is older than an import already saved.");
        var values = State.Sessions.ToList(); var added = 0;
        foreach (var item in payload.Sessions)
        {
            var existing = values.FirstOrDefault(x => x.Id == item.Id);
            if (existing is not null)
            {
                if (existing.OriginID != payload.SourceID || existing.Start != item.Start || existing.End != item.End ||
                    existing.TimeZone != item.TimeZone || existing.TargetSeconds != item.TargetSeconds || existing.Topic != item.Topic)
                    throw new InvalidDataException("An existing session differs. Resolve the correction on its source device before importing; nothing was changed.");
            }
            else { values.Add(item with { OriginID = payload.SourceID, OriginRevision = payload.Revision }); added++; }
        }
        values = values.Select(x => x.OriginID == payload.SourceID ? x with { OriginRevision = payload.Revision } : x).ToList();
        Commit(State with { Sessions = StudyClock.Validate(values), PhoneAsOf = payload.ExportedAt });
        return added;
    }

    public string ExportTo(string folder, DateTimeOffset now)
    {
        if (!Directory.Exists(folder)) throw new IOException("The selected folder is unavailable. Local sessions are still saved.");
        var file = Path.Combine(folder, $"study-laptop-{State.SourceID:D}.json");
        var bytes = Coding.Encode(Export(now)); AtomicWrite(file, bytes);
        AtomicWrite(file + ".sha256", System.Text.Encoding.UTF8.GetBytes(Convert.ToHexStringLower(SHA256.HashData(bytes))));
        return file;
    }
    public static byte[] ReadBounded(string path)
    {
        var info = new FileInfo(path);
        // Cloud Files placeholders can be reparse points even when pinned. Reject actual links,
        // not the provider's ordinary hydrated files.
        if (info.Length > 25_000_000 || info.LinkTarget is not null)
            throw new InvalidDataException("Select a regular JSON file smaller than 25 MB.");
        var bytes = File.ReadAllBytes(path);
        var digest = path + ".sha256";
        if (File.Exists(digest))
        {
            var d = new FileInfo(digest);
            if (d.Length > 128 || d.LinkTarget is not null ||
                File.ReadAllText(digest).Trim() != Convert.ToHexStringLower(SHA256.HashData(bytes)))
                throw new InvalidDataException("The file/checksum are incomplete or disagree. Wait for folder delivery, then retry.");
        }
        return bytes;
    }
    public static void AtomicWrite(string path, byte[] bytes)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(path))!);
        var temp = path + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try
        {
            using (var stream = new FileStream(temp, FileMode.CreateNew, FileAccess.Write, FileShare.None, 4096, FileOptions.WriteThrough))
            { stream.Write(bytes); stream.Flush(true); }
            if (File.Exists(path)) File.Copy(path, path + ".previous", true);
            File.Move(temp, path, true);
        }
        finally { if (File.Exists(temp)) File.Delete(temp); }
    }
}
