"""Every hub module must take part in the full backup.

A module is a folder under `ios/AkshatOS/features/`. It passes when some type declared in that folder
conforms to `HubBackupPart`, and `AppServices` (app/AkshatOSApp.swift) lists a property of that type
in `FullBackupService(parts: [...])`. Without this, a new module could ship with Back up everything
silently leaving its data behind. `hub-plan.md` § Full backup owns the contract.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1] / "AkshatOS"
APP_FILE = "app/AkshatOSApp.swift"
CONFORMANCE = re.compile(r"^(?:@\w+\s+)?(?:(?:final|private|public)\s+)*(?:extension|class|struct)\s+(\w+)\s*:[^{]*\bHubBackupPart\b",
                         re.MULTILINE)
PROPERTY = re.compile(r"\blet\s+(\w+)\s*:\s*(\w+)")
REGISTRY = re.compile(r"FullBackupService\(\s*parts:\s*\[([^\]]*)\]")


def check(sources):
    errors = []
    modules = sorted({path.split("/")[1] for path in sources if path.startswith("features/") and path.count("/") >= 2})
    app = sources.get(APP_FILE, "")
    registries = REGISTRY.findall(app)
    if len(registries) != 1:
        return [f"{APP_FILE}: expected exactly one FullBackupService(parts: [...]) registry"]
    listed = [name.strip() for name in registries[0].split(",") if name.strip()]
    types_by_property = dict(PROPERTY.findall(app))
    registered_types = {types_by_property.get(name) for name in listed}
    if None in registered_types:
        errors.append(f"{APP_FILE}: every backup part must be a typed AppServices property")
    if len(set(listed)) != len(listed):
        errors.append(f"{APP_FILE}: a backup part is listed twice")
    for module in modules:
        conforming = {name for path, source in sources.items()
                      if path.startswith(f"features/{module}/") for name in CONFORMANCE.findall(source)}
        if not conforming:
            errors.append(f"features/{module}: no HubBackupPart conformance; every module must join the "
                          "full backup (add <Feature>BackupPart.swift, see hub-plan.md § Full backup)")
        elif not conforming & registered_types:
            errors.append(f"features/{module}: {', '.join(sorted(conforming))} conforms to HubBackupPart but "
                          f"is not listed in FullBackupService(parts:) in {APP_FILE}")
    return errors


def self_test():
    app = ("let squats: SquatStore\nlet reels: ReelStore\n"
           "backup = FullBackupService(parts: [squats, reels])")
    base = {
        APP_FILE: app,
        "features/squats/SquatStore.swift": "final class SquatStore {}",
        "features/squats/SquatsBackupPart.swift": "extension SquatStore: HubBackupPart {}",
        "features/reels/ReelStore.swift": "@MainActor final class ReelStore: ObservableObject, HubBackupPart {}",
    }
    assert not check(base), check(base)
    missing = {k: v for k, v in base.items() if k != "features/squats/SquatsBackupPart.swift"}
    assert any("no HubBackupPart" in e for e in check(missing)), "A module without a conformance fails"
    unlisted = {**base, APP_FILE: app.replace("[squats, reels]", "[squats]")}
    assert any("not listed" in e for e in check(unlisted)), "A conforming module left out of the registry fails"
    twice = {**base, APP_FILE: app.replace("[squats, reels]", "[squats, reels, squats]")}
    assert any("twice" in e for e in check(twice)), "A module listed twice fails"
    no_registry = {**base, APP_FILE: "let squats: SquatStore"}
    assert check(no_registry), "An app without the registry fails"


if __name__ == "__main__":
    self_test()
    sources = {str(path.relative_to(ROOT)).replace("\\", "/"): path.read_text(encoding="utf-8")
               for path in ROOT.rglob("*.swift")}
    errors = check(sources)
    if errors:
        raise SystemExit("\n".join(errors))
    modules = sorted({p.split("/")[1] for p in sources if p.startswith("features/") and p.count("/") >= 2})
    print(f"Full backup covers every module: {', '.join(modules)}; 4 negative fixtures passed.")
