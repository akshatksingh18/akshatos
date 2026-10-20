using System.Text;
using StudyDesk.Core;

var root = Path.Combine(Path.GetTempPath(), "study-desk-tests-" + Guid.NewGuid()); Directory.CreateDirectory(root);
var at = new DateTimeOffset(2026, 10, 20, 18, 0, 0, TimeSpan.Zero);
var count = 0;
void Check(bool value, string message) { if (!value) throw new Exception(message); count++; }
void Refuses(Action action, string message) { var refused = false; try { action(); } catch (Exception) { refused = true; } Check(refused, message); }
StudyStore Store() => new(Path.Combine(root, Guid.NewGuid() + ".json"));
Session Block(int offset, int minutes, Guid? id = null) => new(id ?? Guid.NewGuid(), at.AddMinutes(offset), at.AddMinutes(offset + minutes), "Etc/UTC", 21600);
Exchange Phone(params Session[] blocks) => new("akshatos-study-exchange", 1, Guid.NewGuid(), "iphone", 1, at, blocks);

var timer = Store(); timer.Start(at, "Etc/UTC"); timer.Start(at, "Etc/UTC");
Check(timer.State.Sessions.Length == 1, "Double Start created another block");
timer.Pause(at.AddMinutes(2)); timer.Pause(at.AddMinutes(3)); timer.Start(at.AddMinutes(3), "Etc/UTC"); timer.Pause(at.AddMinutes(4));
Check(timer.Studied(at.AddMinutes(5), "Etc/UTC") == 180, "A paused break was counted");
var shortTap = Store(); shortTap.Start(at, "Etc/UTC"); shortTap.Pause(at.AddSeconds(2));
Check(shortTap.State.Sessions.Length == 0, "Accidental tap retained");

var path = Path.Combine(root, "durable.json"); var saved = new StudyStore(path);
saved.Start(at, "Etc/UTC"); saved.Checkpoint(at.AddMinutes(2));
var crash = new StudyStore(path); crash.RecoverInterrupted();
Check(!crash.Running && crash.Studied(at.AddDays(1), "Etc/UTC") == 0, "Crash counted an absent day");
Check(crash.State.Sessions.Single().End == at.AddMinutes(2), "Crash counted the unsaved gap");
Check(new StudyStore(path).State.Sessions.Single().End == at.AddMinutes(2), "Recovery did not persist");
var failed = new StudyStore(Path.Combine(root, "not-saved.json"), _ => throw new IOException("synthetic full disk"));
Refuses(() => failed.Start(at, "Etc/UTC"), "Failed save accepted"); Check(!failed.Running, "Failed save changed live state");

var source = Phone(Block(-120, 30)); var imported = Store();
Check(imported.Import(source, at) == 1, "Import not added"); Check(imported.Import(source, at) == 0, "Replay duplicated hours");
Check(imported.Studied(at, "Etc/UTC") == 1800, "Imported total is wrong");
Check(imported.Export(at).Sessions.Length == 0, "Imported phone time was re-exported as laptop time");
var before = Coding.Encode(imported.State);
Refuses(() => imported.Import(source with { Revision = 0 }, at), "Older revision accepted");
Check(before.SequenceEqual(Coding.Encode(imported.State)), "Stale import mutated state");
Refuses(() => imported.Import(source with { Sessions = [source.Sessions[0] with { End = at.AddMinutes(-80) }] }, at), "Changed session silently replaced");
Check(before.SequenceEqual(Coding.Encode(imported.State)), "Changed session mutated state");
Refuses(() => imported.Import(Phone(Block(-110, 5), Block(-20, 5)), at), "Overlapping batch accepted");
Check(before.SequenceEqual(Coding.Encode(imported.State)), "Rejected batch partly imported");
Refuses(() => imported.Import(source with { Device = "laptop" }, at), "Wrong direction accepted");
Refuses(() => imported.Import(Phone(Block(2, 5)), at), "Future record accepted");
Refuses(() => imported.Import(source with { Sessions = [source.Sessions[0], source.Sessions[0]] }, at), "Duplicate IDs accepted");
var current = Store(); current.Start(at.AddMinutes(-10), "Etc/UTC");
Refuses(() => current.Import(Phone(Block(-5, 1)), at), "Import overlapped a running laptop session");
Check(current.Running && current.State.Sessions.Length == 1, "Rejected import changed running timer");

var crossover = new Session(Guid.NewGuid(), new DateTimeOffset(2026, 10, 20, 2, 30, 0, TimeSpan.Zero),
    new DateTimeOffset(2026, 10, 20, 3, 30, 0, TimeSpan.Zero), "Etc/UTC", 21600);
Check(StudyClock.Seconds(crossover, "2026-10-19", at) == 1800 && StudyClock.Seconds(crossover, "2026-10-20", at) == 1800, "03:00 split wrong");
var dst = new Session(Guid.NewGuid(), new DateTimeOffset(2026, 11, 1, 5, 30, 0, TimeSpan.Zero),
    new DateTimeOffset(2026, 11, 1, 7, 30, 0, TimeSpan.Zero), "America/New_York", 21600);
Check(StudyClock.Seconds(dst, "2026-10-31", dst.End!.Value) == 7200, "DST repeated hour lost");
Check(StudyClock.Day(crossover.Start, "Etc/UTC") == "2026-10-19", "Early session attributed to wrong day");
Check(StudyClock.Display(21600) == "6:00:00", "Countdown format wrong");
var settings = Store(); settings.Start(at.AddHours(-1), "Etc/UTC"); settings.Pause(at);
settings.SetPreferences(settings.State.Preferences with { TargetSeconds = 14400 });
Check(settings.Target(at, "Etc/UTC") == 21600, "Target change rewrote the existing day");
Check(settings.Target(at.AddDays(1), "Etc/UTC") == 14400, "Future target not applied");

var exportedPath = settings.ExportTo(root, at); var bytes = StudyStore.ReadBounded(exportedPath);
Check(Coding.Decode<Exchange>(bytes).Sessions.Length == 1, "Exchange failed round trip");
File.WriteAllText(exportedPath + ".sha256", new string('0', 64));
Refuses(() => StudyStore.ReadBounded(exportedPath), "Checksum mismatch accepted");
var corruptPath = Path.Combine(root, "corrupt.json"); File.WriteAllText(corruptPath, "{broken");
Refuses(() => new StudyStore(corruptPath), "Corrupt storage silently reset");
Check(File.ReadAllText(corruptPath) == "{broken", "Corrupt file overwritten");

var fixtureSource = Guid.Parse("11111111-1111-4111-8111-111111111111");
var wire = new Exchange("akshatos-study-exchange", 1, fixtureSource, "laptop", 1, at,
    [Block(-120, 30, Guid.Parse("22222222-2222-4222-8222-222222222222"))]);
if (args.Length == 2 && args[0] == "--write-wire")
{ Directory.CreateDirectory(args[1]); File.WriteAllBytes(Path.Combine(args[1], "laptop-wire.json"), Coding.Encode(wire)); }
Check(!Encoding.UTF8.GetString(Coding.Encode(wire)).Contains(".000"), "Wire dates are incompatible with ISO8601 phone decoder");
var golden = Coding.Decode<Exchange>(File.ReadAllBytes("tests/fixtures/laptop-wire.json"));
Check(wire.SourceID == golden.SourceID && wire.Sessions.SequenceEqual(golden.Sessions), "Windows writer drifted from the shared phone fixture");
var phoneGolden = Coding.Decode<Exchange>(File.ReadAllBytes("tests/fixtures/phone-wire.json"));
Check(Store().Import(phoneGolden, at) == 1, "Phone fixture is incompatible with Windows");
Check(Store().Import(phoneGolden with { Sessions = [phoneGolden.Sessions[0] with { TargetSeconds = 60 }] }, at) == 1,
    "A legacy recorded target must not be clamped or lost during import");
Console.WriteLine($"PASS: {count} study clock, persistence and exchange assertions");
