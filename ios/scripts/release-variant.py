"""Resolve a fixed release variant to build/output paths; never builds or packages anything."""
import argparse
from pathlib import Path


def resolve(variant, runner_temp, run_number):
    if variant not in ("standard", "study-live-activity"):
        raise ValueError("Unknown build variant")
    root = Path(runner_temp)
    if not root.is_absolute() or any(char in str(root) for char in "\r\n"):
        raise ValueError("Runner temp must be an absolute, single-line path")
    if not isinstance(run_number, int) or isinstance(run_number, bool) or run_number < 1:
        raise ValueError("Run number must be positive")
    live = variant == "study-live-activity"
    return {
        "BUILD_VARIANT": variant,
        "DEVICE_DERIVED_DATA": str(root / ("DerivedData-activity-device" if live else "DerivedData-device")),
        "IPA_FILENAME": "AkshatOS-study-live-activity-unsigned.ipa" if live else "AkshatOS-unsigned.ipa",
        "IPA_ARTIFACT_NAME": f"akshatos-ios-{run_number}" + ("-study-live-activity" if live else ""),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--variant", choices=("standard", "study-live-activity"), default="standard")
    parser.add_argument("--runner-temp", required=True)
    parser.add_argument("--run-number", type=int, required=True)
    args = parser.parse_args()
    try:
        values = resolve(args.variant, args.runner_temp, args.run_number)
    except ValueError as error:
        parser.error(str(error))
    for key, value in values.items():
        print(f"{key}={value}")


if __name__ == "__main__":
    main()
