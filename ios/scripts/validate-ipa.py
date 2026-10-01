"""Validate the unsigned app payload before publishing a downloadable build."""
import plistlib
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1]) as archive:
    assert archive.testzip() is None, "Corrupt IPA archive"
    names = archive.namelist()
    assert all(name.startswith("Payload/AkshatOS.app/") or name == "Payload/" for name in names)
    assert not any(".." in name.split("/") for name in names), "Unsafe archive path"
    assert not any(".appex/" in name or ".xctest/" in name or name.endswith("embedded.mobileprovision")
                   for name in names), "Unexpected extension, test runner or signing profile"
    metadata = plistlib.loads(archive.read("Payload/AkshatOS.app/Info.plist"))
    assert metadata["CFBundleIdentifier"] == "com.akshatksingh18.akshatos"
    assert metadata["CFBundleExecutable"] == "AkshatOS"
    assert archive.getinfo("Payload/AkshatOS.app/AkshatOS").file_size > 0
    assert metadata["CFBundleShortVersionString"] and metadata["CFBundleVersion"]
    # Open in AkshatOS was removed at Akshat's request after Build 28: the app opens no document
    # types, and its Documents folder stays private.
    assert "CFBundleDocumentTypes" not in metadata, "No document types are declared"
    assert not metadata.get("UIFileSharingEnabled"), "The app's Documents folder must stay private"
    # PageVault read-aloud keeps speaking with the screen locked; no other background mode is used.
    assert metadata.get("UIBackgroundModes") == ["audio"], "Only the audio background mode is declared"
    print("IPA structure, identity, metadata and payload checks passed.")
