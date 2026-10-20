using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace StudyDesk.Core;

public sealed record Session(Guid Id, DateTimeOffset Start, DateTimeOffset? End, string TimeZone,
    int TargetSeconds, string Topic = "", Guid? OriginID = null, int OriginRevision = 0);

public sealed record Exchange(string Format, int Version, Guid SourceID, string Device, int Revision,
    DateTimeOffset ExportedAt, Session[] Sessions);

public sealed record Preferences(double Width = 720, double Height = 650, double? Left = null,
    double? Top = null, double TimerSize = 92, bool Pinned = false, int TargetSeconds = 21600,
    string Topic = "", string? LinkedFolder = null);

public sealed record DeskState(int Version, Guid SourceID, int Revision, Session[] Sessions,
    Preferences Preferences, DateTimeOffset? Checkpoint = null, DateTimeOffset? PhoneAsOf = null)
{
    public static DeskState Empty() => new(1, Guid.NewGuid(), 0, [], new());
}

public static class StudyClock
{
    public static string SystemZone()
    {
        var id = TimeZoneInfo.Local.Id;
        return TimeZoneInfo.TryConvertWindowsIdToIanaId(id, out var mapped) ? mapped : id;
    }

    public static TimeZoneInfo Zone(string id)
    {
        if (string.IsNullOrWhiteSpace(id) || id.Length > 120) throw new InvalidDataException("Invalid time zone.");
        try { return TimeZoneInfo.FindSystemTimeZoneById(id); }
        catch (Exception ex) when (ex is TimeZoneNotFoundException or InvalidTimeZoneException)
        { throw new InvalidDataException("Unknown time zone.", ex); }
    }

    public static string Day(DateTimeOffset at, string zone)
    {
        var local = TimeZoneInfo.ConvertTime(at, Zone(zone));
        var day = local.Date.AddDays(local.Hour < 3 ? -1 : 0);
        return day.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
    }

    private static DateTimeOffset Boundary(DateTime date, TimeZoneInfo zone)
    {
        var local = DateTime.SpecifyKind(date.Date.AddHours(3), DateTimeKind.Unspecified);
        while (zone.IsInvalidTime(local)) local = local.AddMinutes(1);
        var offset = zone.IsAmbiguousTime(local) ? zone.GetAmbiguousTimeOffsets(local).Max() : zone.GetUtcOffset(local);
        return new DateTimeOffset(local, offset).ToUniversalTime();
    }

    public static double Seconds(Session session, string day, DateTimeOffset now)
    {
        var zone = Zone(session.TimeZone);
        var date = DateTime.ParseExact(day, "yyyy-MM-dd", CultureInfo.InvariantCulture);
        var begin = Boundary(date, zone); var end = Boundary(date.AddDays(1), zone);
        return Math.Max(0, (Min(session.End ?? now, end) - Max(session.Start, begin)).TotalSeconds);
    }

    public static DateTimeOffset Min(DateTimeOffset a, DateTimeOffset b) => a < b ? a : b;
    public static DateTimeOffset Max(DateTimeOffset a, DateTimeOffset b) => a > b ? a : b;
    public static string Display(double seconds)
    {
        var whole = (long)Math.Max(0, seconds);
        return $"{whole / 3600}:{whole / 60 % 60:00}:{whole % 60:00}";
    }

    public static Session[] Validate(IEnumerable<Session> input, DateTimeOffset? notAfter = null)
    {
        var sessions = input.OrderBy(x => x.Start).ToArray();
        if (sessions.Length > 10000 || sessions.Select(x => x.Id).Distinct().Count() != sessions.Length)
            throw new InvalidDataException("Too many sessions or duplicate session IDs.");
        foreach (var s in sessions)
        {
            _ = Zone(s.TimeZone);
            if (s.Id == Guid.Empty || s.TargetSeconds is < 1800 or > 86400 || s.Topic.Length > 200 ||
                s.Start < DateTimeOffset.UnixEpoch || s.End <= s.Start || s.OriginRevision < 0 ||
                (s.OriginID is not null && (s.OriginID == Guid.Empty || s.End is null)) ||
                (notAfter is not null && (s.Start > notAfter || s.End > notAfter)))
                throw new InvalidDataException("Invalid study session.");
        }
        for (var i = 1; i < sessions.Length; i++)
            if (sessions[i - 1].End is null || sessions[i - 1].End > sessions[i].Start)
                throw new InvalidDataException("Study sessions overlap. Pause the other timer and correct the conflicting times before importing.");
        return sessions;
    }
}

public static class Coding
{
    public static readonly JsonSerializerOptions Options = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        PropertyNameCaseInsensitive = false,
        WriteIndented = true,
        Converters = { new SecondsDateConverter() }
    };
    public static byte[] Encode<T>(T value) => JsonSerializer.SerializeToUtf8Bytes(value, Options);
    public static T Decode<T>(byte[] bytes)
    {
        if (bytes.Length > 25_000_000) throw new InvalidDataException("File exceeds the transfer size limit.");
        return JsonSerializer.Deserialize<T>(bytes, Options) ?? throw new InvalidDataException("Empty document.");
    }

    private sealed class SecondsDateConverter : JsonConverter<DateTimeOffset>
    {
        public override DateTimeOffset Read(ref Utf8JsonReader reader, Type type, JsonSerializerOptions options) => reader.GetDateTimeOffset();
        public override void Write(Utf8JsonWriter writer, DateTimeOffset value, JsonSerializerOptions options) =>
            writer.WriteStringValue(value.UtcDateTime.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'", CultureInfo.InvariantCulture));
    }
}
