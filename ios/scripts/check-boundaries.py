"""Lightweight source-boundary guard, not a Swift parser or compiler isolation."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1] / "AkshatOS"
DECLARATION = re.compile(
    r"^(?:@\w+\s+)?(?:(?:final|private|public)\s+)*"
    r"(?:class|struct|enum|protocol|typealias)\s+(\w+)", re.MULTILINE
)


def layer(path):
    parts = path.split("/")
    return "/".join(parts[:2]) if parts[0] == "features" else parts[0]


def check(sources):
    owners = {}
    errors = []
    for path, source in sources.items():
        for symbol in DECLARATION.findall(source):
            owners[symbol] = layer(path)
    for path, source in sources.items():
        own = layer(path)
        if own not in {"app", "shared"} and not own.startswith("features/"):
            errors.append(f"{path}: Swift source must belong to app, shared or a feature")
        for symbol in set(re.findall(r"\b[A-Za-z_]\w*\b", source)):
            other = owners.get(symbol)
            if not other or other == own:
                continue
            if own == "shared" or (own.startswith("features/") and other != "shared"):
                errors.append(f"{path}: forbidden dependency on {symbol} ({other})")
            if path.startswith("app/hub/") and other.startswith("features/"):
                errors.append(f"{path}: hub presentation depends on feature type {symbol}")
        if re.search(r"\.delegate\s*=", source) and path != "app/AppNotificationCoordinator.swift":
            errors.append(f"{path}: process-wide delegate belongs to the app coordinator")
        if own == "shared" or path.startswith("app/hub/"):
            if re.search(r"\b(SwiftData|UserNotifications|UserDefaults|CoreLocation)\b", source):
                errors.append(f"{path}: presentation layer must not own persistence or OS services")
        if "/domain/" in path:
            imports = re.findall(r"^import (\w+)", source, re.MULTILINE)
            if any(module != "Foundation" for module in imports):
                errors.append(f"{path}: domain logic must remain Foundation-only")
    return errors


def self_test():
    base = {"app/App.swift": "struct AppRoot {}", "features/squats/Store.swift": "class SquatStore {}",
            "shared/Style.swift": "enum Palette {}", "features/reels/Reels.swift": "class ReelStore {}"}
    assert not check(base)
    for path, violation in [
        ("shared/Bad.swift", "let value: SquatStore"),
        ("features/reels/Bad.swift", "let value: SquatStore"),
        ("features/squats/Bad.swift", "let value: AppRoot"),
        ("app/hub/Bad.swift", "let value: SquatStore"),
        ("features/squats/Bad.swift", "center.delegate = self"),
        ("features/squats/domain/Bad.swift", "import SwiftUI"),
    ]:
        assert check({**base, path: violation}), path


if __name__ == "__main__":
    self_test()
    sources = {str(path.relative_to(ROOT)).replace("\\", "/"): path.read_text(encoding="utf-8")
               for path in ROOT.rglob("*.swift")}
    assert sources, "No Swift sources found"
    errors = check(sources)
    if errors:
        raise SystemExit("\n".join(errors))
    print(f"Boundary checks passed for {len(sources)} Swift files; 6 negative fixtures passed.")
