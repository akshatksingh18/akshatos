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
    # "Open in AkshatOS" for PDFs: a viewer that never claims to be the default, receiving a copy
    # rather than the sharing app's own file, and no Documents folder exposed to Files or iTunes.
    document_types = metadata.get("CFBundleDocumentTypes", [])
    assert [t.get("LSItemContentTypes") for t in document_types] == [["com.adobe.pdf"]], document_types
    assert document_types[0].get("CFBundleTypeRole") == "Viewer"
    assert document_types[0].get("LSHandlerRank") == "Alternate"
    assert metadata.get("LSSupportsOpeningDocumentsInPlace") is False
    assert not metadata.get("UIFileSharingEnabled"), "The app's Documents folder must stay private"
    print("IPA structure, identity, metadata, document-type and payload checks passed.")
