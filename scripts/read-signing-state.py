"""Read Sideloadly's own record of what it has installed, as JSON on stdout.

Split out from the PowerShell health check because Windows PowerShell has no SQLite reader. This
half only reads and reports; every decision about what is healthy lives in the PowerShell script.

Never reads or emits the signing material sitting beside this database (`key.pem`,
`cert-*.pem`, `sessions.json`). Only the columns named below are selected.
"""
import json
import os
import shutil
import sqlite3
import sys
import tempfile
from datetime import datetime, timedelta, timezone

DEFAULT_DB = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Sideloadly", "installations.db")

# Bundle IDs Sideloadly still has a row for but that are not on the phone any more. Sideloadly
# never deletes an installation row on uninstall, so a retired app's registration sits in this
# database forever, "expiring" every seven days like clockwork with nothing on the phone for it
# to affect. Without this list the health check raises a real CRITICAL alert for an app that does
# not exist, indefinitely — which is exactly what happened for the identity below.
#
# Matched as a prefix because Sideloadly appends the team suffix, e.g.
# "com.akshatksingh18.squatreminder.5564K8D4SV".
#
# Source of truth for each entry: cloud-build.md documents when and why it was retired.
RETIRED_BUNDLE_PREFIXES = [
    # The standalone Squat Reminder smoke app. Superseded by the AkshatOS hub (whose own bundle,
    # com.akshatksingh18.akshatos, carries the real Squats feature today) and removed from the
    # phone by Akshat. See cloud-build.md: "launched once through Sideloadly and was then removed".
    "com.akshatksingh18.squatreminder",
]


def is_retired(bundle_id):
    return bool(bundle_id) and any(bundle_id.startswith(prefix) for prefix in RETIRED_BUNDLE_PREFIXES)


def parse(stamp):
    """Sideloadly writes '2026-09-12 13:16:54.6299273-05:00', which fromisoformat rejects on
    older Pythons because of the sub-second precision. Trim to microseconds and retry."""
    if not stamp:
        return None
    text = str(stamp).strip()
    try:
        return datetime.fromisoformat(text)
    except ValueError:
        pass
    if "." in text:
        head, rest = text.split(".", 1)
        digits = ""
        for char in rest:
            if char.isdigit():
                digits += char
            else:
                break
        tail = rest[len(digits):]
        try:
            return datetime.fromisoformat(f"{head}.{digits[:6]}{tail}")
        except ValueError:
            return None
    return None


def main():
    source = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_DB
    if not os.path.isfile(source):
        print(json.dumps({"ok": False, "error": f"Sideloadly database not found at {source}"}))
        return 0

    # Copy first: the daemon holds this open, and a health check must never lock or alter it.
    handle, copy = tempfile.mkstemp(suffix=".db")
    os.close(handle)
    apps, error = [], None
    try:
        shutil.copy2(source, copy)
        conn = sqlite3.connect(f"file:{copy}?mode=ro", uri=True)
        conn.row_factory = sqlite3.Row
        rows = conn.execute(
            "SELECT name, final_bundle_id, version, last_updated, created_at, known_ttl,"
            " refresh_at_hours, last_error, failures_count, last_failure_at"
            " FROM installations WHERE deleted_at IS NULL"
        ).fetchall()
        conn.close()

        now = datetime.now(timezone.utc)
        raw_entries = []
        for row in rows:
            last_updated = parse(row["last_updated"])
            # Sideloadly writes its underlying zero-value timestamp (year 1) for a row whose
            # install never actually completed - confirmed 2026-09-13 from a cancelled WHOOP
            # reinstall that stalled mid-transfer: Sideloadly created a fresh row for the attempt
            # and never wrote a real last_updated into it, and cancelling in its own UI did not
            # delete the row. Read literally, that date computes an expiry hundreds of thousands
            # of days in the past. Treat it as "never completed", not as a real signing date.
            incomplete = last_updated is not None and last_updated.year <= 1
            signed = None if incomplete else last_updated
            created = parse(row["created_at"])
            if signed is None:
                signed = created
            ttl = row["known_ttl"] or 7
            entry = {
                "name": row["name"],
                "bundleID": row["final_bundle_id"],
                "version": row["version"],
                "lastSigned": signed.isoformat() if signed else None,
                "ttlDays": ttl,
                "refreshAtHours": row["refresh_at_hours"],
                "lastError": (row["last_error"] or "").strip(),
                "failures": row["failures_count"] or 0,
                "retired": is_retired(row["final_bundle_id"]),
                "incompleteAttempt": incomplete,
            }
            if signed and not incomplete:
                if signed.tzinfo is None:
                    signed = signed.replace(tzinfo=timezone.utc)
                expires = signed + timedelta(days=ttl)
                entry["expires"] = expires.isoformat()
                entry["daysLeft"] = round((expires - now).total_seconds() / 86400, 2)
                # Never refreshed: Sideloadly has not touched it since the original install.
                if created is not None:
                    if created.tzinfo is None:
                        created = created.replace(tzinfo=timezone.utc)
                    entry["everRefreshed"] = (signed - created).total_seconds() > 120
            raw_entries.append(entry)

        # Sideloadly writes a fresh row per install attempt rather than updating one in place,
        # and does not clean up a row whose attempt never completed - so the same bundle ID can
        # have several rows at once, only one of which is the app's real current state. Keep one
        # entry per bundle ID: the most recently completed row if any exists in the group, else
        # (every row for that bundle is an incomplete attempt) the most recently created one, with
        # its own expiry/daysLeft left absent so the health check reports "no usable install date"
        # rather than a fabricated one. Every other row in the group is folded into that entry's
        # staleAttempts instead of being reported as a second app.
        by_bundle = {}
        for entry in raw_entries:
            by_bundle.setdefault(entry["bundleID"], []).append(entry)

        for bundle_id, group in by_bundle.items():
            if len(group) == 1:
                apps.append(group[0])
                continue
            completed = [e for e in group if not e["incompleteAttempt"]]
            pool = completed if completed else group
            primary = max(pool, key=lambda e: e["lastSigned"] or "")
            stale = [e for e in group if e is not primary]
            primary["staleAttempts"] = [
                {"lastSigned": e["lastSigned"], "incompleteAttempt": e["incompleteAttempt"]}
                for e in stale
            ]
            apps.append(primary)
    except Exception as exc:  # reported, never swallowed — a silent check is the failure mode
        error = f"{type(exc).__name__}: {exc}"
    finally:
        try:
            os.remove(copy)
        except OSError:
            pass

    print(json.dumps({"ok": error is None, "error": error, "database": source, "apps": apps}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
