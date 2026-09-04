"""Require each implemented feature to register domain, persistence/service and UI tests."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def validate(registry, features):
    if set(registry) != set(features):
        raise ValueError("Implemented feature folders and test registry must match")
    for feature, suite in registry.items():
        paths = suite["domain_sources"] + [suite["domain_test"]] + suite["integration_tests"] + suite["ui_tests"]
        if not suite["domain_sources"] or not suite["integration_tests"] or not suite["ui_tests"]:
            raise ValueError(f"{feature}: domain, integration and UI coverage are required")
        for relative in paths:
            path = (ROOT / relative).resolve()
            if not path.is_relative_to(ROOT) or not path.is_file():
                raise ValueError(f"Missing or unsafe registered test/source: {relative}")


if __name__ == "__main__":
    registry = json.loads((ROOT / "tests/feature-tests.json").read_text())
    features = [p.name for p in (ROOT / "AkshatOS/features").iterdir() if p.is_dir()]
    validate(registry, features)
    try:
        validate(registry, features + ["unregistered-feature"])
    except ValueError:
        pass
    else:
        raise AssertionError("Missing-feature fixture was not rejected")
    print(f"Registered feature test suites: {', '.join(sorted(registry))}")
    if "--run" in sys.argv:
        with tempfile.TemporaryDirectory(prefix="akshatos-domain-tests-") as temporary:
            for feature, suite in registry.items():
                executable = str(Path(temporary) / feature)
                subprocess.run(["swiftc", *[str(ROOT / p) for p in suite["domain_sources"]],
                                str(ROOT / suite["domain_test"]), "-o", executable], check=True)
                subprocess.run([executable], check=True)
