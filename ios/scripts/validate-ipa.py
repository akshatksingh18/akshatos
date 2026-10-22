"""Validate an unsigned IPA or an already-built .app without creating an archive."""
import argparse
from pathlib import Path, PurePosixPath
import plistlib
import zipfile
from xml.parsers.expat import ExpatError

APP = "Payload/AkshatOS.app"
EXTENSION = APP + "/PlugIns/StudyActivityExtension.appex"
BUNDLE_ID = "com.akshatksingh18.akshatos"
VARIANTS = ("standard", "study-live-activity")


class ValidationError(ValueError):
    pass


def require(condition, message):
    # Do not use assert: release checks must still run under python -O.
    if not condition:
        raise ValidationError(message)


def validate_payload(names, read, size, variant="standard"):
    require(variant in VARIANTS, "Unknown build variant")
    require(len(names) == len(set(names)), "Duplicate archive path")
    for name in names:
        parts = PurePosixPath(name).parts
        require(name and "\\" not in name and ":" not in name
                and not name.startswith("/") and ".." not in parts
                and "." not in name.split("/") and "//" not in name,
                "Unsafe archive path")
        require(name.rstrip("/") in ("Payload", APP) or name.startswith(APP + "/"),
                "Unexpected payload root")
        require(not any(part.endswith(".xctest") for part in parts), "Unexpected test bundle")
        require(parts[-1] != "embedded.mobileprovision", "Unsigned payload contains a signing profile")
        require(not any(part.endswith(".app") and (index != 1 or part != "AkshatOS.app")
                        for index, part in enumerate(parts)),
                "Unexpected nested application")
        for index, part in enumerate(parts):
            if part.endswith(".appex"):
                require(variant == "study-live-activity" and "/".join(parts[:index + 1]) == EXTENSION,
                        "Unexpected app extension")
        if name.startswith(APP + "/PlugIns/") and name.rstrip("/") != APP + "/PlugIns":
            require(variant == "study-live-activity" and
                    (name.rstrip("/") == EXTENSION or name.startswith(EXTENSION + "/")),
                    "Unexpected PlugIns content")

    def metadata_at(root):
        try:
            metadata = plistlib.loads(read(root + "/Info.plist"))
        except (KeyError, OSError, plistlib.InvalidFileException, ValueError, ExpatError) as error:
            raise ValidationError("Missing or invalid bundle Info.plist") from error
        require(isinstance(metadata, dict), "Bundle Info.plist must be a dictionary")
        return metadata

    def executable_at(root, executable):
        name = root + "/" + executable
        require(name in names and size(name) > 0, "Missing or empty bundle executable")

    metadata = metadata_at(APP)
    require(metadata.get("CFBundleIdentifier") == BUNDLE_ID, "Wrong app bundle identity")
    require(metadata.get("CFBundleExecutable") == "AkshatOS", "Wrong app executable")
    executable_at(APP, "AkshatOS")
    for key in ("CFBundleShortVersionString", "CFBundleVersion", "MinimumOSVersion"):
        require(isinstance(metadata.get(key), str) and bool(metadata[key].strip()),
                "Missing app version/build/deployment metadata")
    # Preserve the default recovery build's privacy and background-mode restrictions.
    require("CFBundleDocumentTypes" not in metadata, "No document types are declared")
    require(not metadata.get("UIFileSharingEnabled"), "The app's Documents folder must stay private")
    require(metadata.get("UIBackgroundModes") == ["audio"], "Only the audio background mode is declared")
    if variant == "standard":
        require(not metadata.get("NSSupportsLiveActivities"), "Standard build must not enable Live Activities")
        require(not any(name.rstrip("/") == APP + "/PlugIns" for name in names),
                "Standard build must not contain PlugIns")
    else:
        require(metadata.get("NSSupportsLiveActivities") is True, "Live Activity host capability is missing")
        extension = metadata_at(EXTENSION)
        require(extension.get("CFBundleIdentifier") == BUNDLE_ID + ".studyactivity",
                "Wrong study extension identity")
        require(extension.get("CFBundleExecutable") == "StudyActivityExtension", "Wrong study extension executable")
        executable_at(EXTENSION, "StudyActivityExtension")
        for key in ("CFBundleShortVersionString", "CFBundleVersion", "MinimumOSVersion"):
            require(extension.get(key) == metadata[key], "Extension version/build/deployment must match its app")
        point = extension.get("NSExtension")
        require(isinstance(point, dict) and point.get("NSExtensionPointIdentifier") == "com.apple.widgetkit-extension",
                "Study extension must be a WidgetKit extension")
        require(not extension.get("UIBackgroundModes"), "Study extension must not declare background modes")
    return metadata


def validate_archive(archive, variant="standard"):
    require(all(info.orig_filename == info.filename for info in archive.infolist()),
            "Archive path was normalized or truncated")
    require(archive.testzip() is None, "Corrupt IPA archive")
    return validate_payload(archive.namelist(), archive.read,
                            lambda name: archive.getinfo(name).file_size, variant)


def validate_directory(path, variant="standard"):
    path = Path(path)
    require(path.is_dir() and path.name == "AkshatOS.app", "Expected an AkshatOS.app directory")
    entries = {APP + "/" + entry.relative_to(path).as_posix(): entry for entry in path.rglob("*")}
    return validate_payload(list(entries), lambda name: entries[name].read_bytes(),
                            lambda name: entries[name].stat().st_size, variant)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", type=Path, help="Unsigned IPA or built AkshatOS.app directory")
    parser.add_argument("--variant", choices=VARIANTS, default="standard")
    args = parser.parse_args()
    try:
        if args.path.is_dir():
            validate_directory(args.path, args.variant)
        else:
            with zipfile.ZipFile(args.path) as archive:
                validate_archive(archive, args.variant)
    except (ValidationError, OSError, zipfile.BadZipFile, RuntimeError) as error:
        parser.exit(1, f"Payload validation failed: {error}\n")
    print(f"{args.variant}: unsigned payload, identity, versions and extension checks passed.")


if __name__ == "__main__":
    main()
