"""Small release-contract regressions. ZIP fixtures stay in memory; no IPA files are created."""
from contextlib import contextmanager
import importlib.util
import io
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest
import warnings
import zipfile


def load(name, file):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).with_name(file))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


validator = load("ipa_validator", "validate-ipa.py")
variants = load("release_variant", "release-variant.py")
A, E = validator.APP, validator.EXTENSION


def fixture(live=False):
    metadata = dict(CFBundleIdentifier=validator.BUNDLE_ID, CFBundleExecutable="AkshatOS",
                    CFBundleShortVersionString="0.14.1", CFBundleVersion="39",
                    MinimumOSVersion="17.0", UIBackgroundModes=["audio"])
    files = {A + "/AkshatOS": b"synthetic executable"}
    if live:
        metadata["NSSupportsLiveActivities"] = True
        extension = dict(CFBundleIdentifier=validator.BUNDLE_ID + ".studyactivity",
                         CFBundleExecutable="StudyActivityExtension", CFBundleShortVersionString="0.14.1",
                         CFBundleVersion="39", MinimumOSVersion="17.0",
                         NSExtension={"NSExtensionPointIdentifier": "com.apple.widgetkit-extension"})
        files[E + "/Info.plist"] = plistlib.dumps(extension)
        files[E + "/StudyActivityExtension"] = b"synthetic extension"
    files[A + "/Info.plist"] = plistlib.dumps(metadata)
    return files


def edit(files, root, **changes):
    metadata = plistlib.loads(files[root + "/Info.plist"])
    metadata.update(changes)
    files[root + "/Info.plist"] = plistlib.dumps(metadata)


@contextmanager
def archive(files):
    stream = io.BytesIO()
    with zipfile.ZipFile(stream, "w") as result:
        with warnings.catch_warnings():
            warnings.simplefilter("ignore", UserWarning)
            for name, data in files.items() if isinstance(files, dict) else files:
                info = zipfile.ZipInfo("fixture")
                info.filename = info.orig_filename = name
                result.writestr(info, data)
    stream.seek(0)
    with zipfile.ZipFile(stream) as result:
        yield result


class PayloadTests(unittest.TestCase):
    def valid(self, files, variant="standard"):
        with archive(files) as zipped:
            return validator.validate_archive(zipped, variant)

    def invalid(self, files, variant="standard"):
        with self.assertRaises(validator.ValidationError):
            self.valid(files, variant)

    def test_standard_recovery_and_live_activity_are_explicit(self):
        self.valid(fixture())
        self.valid(fixture(True), "study-live-activity")
        self.invalid(fixture(True))
        self.invalid(fixture(), "study-live-activity")
        self.invalid(fixture(), "typo")

    def test_only_one_exact_extension_is_allowed(self):
        for path in (A + "/PlugIns/Other.appex/Info.plist", E + "/PlugIns/Nested.appex/Info.plist",
                     A + "/Other.appex/Info.plist", A + "/PlugIns/stray-file"):
            with self.subTest(path=path):
                files = fixture(True); files[path] = b"unexpected"
                self.invalid(files, "study-live-activity")

    def test_empty_plugins_directory_is_not_a_standard_build(self):
        files = fixture(); files[A + "/PlugIns/"] = b""
        self.invalid(files)

    def test_host_capability_must_be_boolean_true_for_live_variant(self):
        for value in (False, "YES", 1):
            files = fixture(True); edit(files, A, NSSupportsLiveActivities=value)
            self.invalid(files, "study-live-activity")
        files = fixture(); edit(files, A, NSSupportsLiveActivities=True)
        self.invalid(files)

    def test_wrong_host_and_extension_identity_or_executable(self):
        for root, key in ((A, "CFBundleIdentifier"), (A, "CFBundleExecutable"),
                          (E, "CFBundleIdentifier"), (E, "CFBundleExecutable")):
            with self.subTest(root=root, key=key):
                files = fixture(True); edit(files, root, **{key: "wrong"})
                self.invalid(files, "study-live-activity")

    def test_missing_or_empty_executables(self):
        for key in (A + "/AkshatOS", E + "/StudyActivityExtension"):
            for missing in (True, False):
                files = fixture(True)
                if missing: del files[key]
                else: files[key] = b""
                self.invalid(files, "study-live-activity")

    def test_matching_version_build_and_deployment(self):
        for key in ("CFBundleShortVersionString", "CFBundleVersion", "MinimumOSVersion"):
            files = fixture(True); edit(files, E, **{key: "different"})
            self.invalid(files, "study-live-activity")
            files = fixture(); edit(files, A, **{key: ""})
            self.invalid(files)

    def test_widgetkit_extension_point_required(self):
        for value in ({}, {"NSExtensionPointIdentifier": "wrong"}, "wrong"):
            files = fixture(True); edit(files, E, NSExtension=value)
            self.invalid(files, "study-live-activity")

    def test_existing_privacy_and_background_restrictions_remain(self):
        for values in ({"CFBundleDocumentTypes": []}, {"UIFileSharingEnabled": True},
                       {"UIBackgroundModes": ["audio", "location"]}, {"UIBackgroundModes": []}):
            for live in (False, True):
                files = fixture(live); edit(files, A, **values)
                self.invalid(files, "study-live-activity" if live else "standard")
        files = fixture(True); edit(files, E, UIBackgroundModes=["audio"])
        self.invalid(files, "study-live-activity")

    def test_profiles_tests_and_nested_apps_rejected_in_either_variant(self):
        for live in (False, True):
            for path in (A + "/embedded.mobileprovision", E + "/embedded.mobileprovision",
                         A + "/Tests.xctest/test", A + "/Runner.app/Info.plist",
                         A + "/AkshatOS.app/Info.plist"):
                files = fixture(live); files[path] = b"unexpected"
                self.invalid(files, "study-live-activity" if live else "standard")

    def test_unsafe_or_foreign_archive_paths_and_duplicates(self):
        for path in ("../escape", A + "/../escape", "/" + A + "/file", A + "/./file",
                     A + "//file", A + "\\file", "C:/file", "Other/file", ""):
            with self.subTest(path=path):
                files = fixture(); files[path] = b"unexpected"
                self.invalid(files)
        files = list(fixture().items()); files.append(files[0])
        self.invalid(files)

    def test_missing_and_malformed_info_plists(self):
        for root in (A, E):
            for data in (None, b"not a plist", b'<?xml version="1.0"?><plist><dict>',
                         plistlib.dumps(["not a dictionary"])):
                files = fixture(True)
                if data is None: del files[root + "/Info.plist"]
                else: files[root + "/Info.plist"] = data
                self.invalid(files, "study-live-activity")

    def test_corrupt_archive_content_fails_crc(self):
        stream = io.BytesIO()
        with zipfile.ZipFile(stream, "w") as zipped:
            for name, data in fixture().items(): zipped.writestr(name, data)
        data = bytearray(stream.getvalue())
        # The first stored entry is the synthetic executable, after its local header/name.
        offset = 30 + len((A + "/AkshatOS").encode())
        data[offset] ^= 1
        with zipfile.ZipFile(io.BytesIO(data)) as zipped:
            with self.assertRaisesRegex(validator.ValidationError, "Corrupt"):
                validator.validate_archive(zipped)

    def test_built_app_directory_uses_same_contract_without_packaging(self):
        with tempfile.TemporaryDirectory() as temporary:
            for live in (False, True):
                path = Path(temporary) / str(live) / "AkshatOS.app"
                for name, data in fixture(live).items():
                    destination = path / name.removeprefix(A + "/")
                    destination.parent.mkdir(parents=True, exist_ok=True); destination.write_bytes(data)
                validator.validate_directory(path, "study-live-activity" if live else "standard")
                if live:
                    with self.assertRaises(validator.ValidationError):
                        validator.validate_directory(path)

    def test_optimized_python_cannot_bypass_validation(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "AkshatOS.app"
            path.mkdir()
            files = fixture(); edit(files, A, CFBundleIdentifier="wrong")
            for name, data in files.items():
                (path / name.removeprefix(A + "/")).write_bytes(data)
            result = subprocess.run([sys.executable, "-O", str(Path(__file__).with_name("validate-ipa.py")),
                                     str(path)], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Wrong app bundle identity", result.stderr)


class VariantTests(unittest.TestCase):
    def test_defaults_preserve_recovery_output_names(self):
        result = variants.resolve("standard", tempfile.gettempdir(), 123)
        self.assertEqual(result["IPA_FILENAME"], "AkshatOS-unsigned.ipa")
        self.assertEqual(result["IPA_ARTIFACT_NAME"], "akshatos-ios-123")
        self.assertTrue(result["DEVICE_DERIVED_DATA"].endswith("DerivedData-device"))

    def test_live_output_is_distinct_and_uses_live_device_build(self):
        result = variants.resolve("study-live-activity", tempfile.gettempdir(), 123)
        self.assertEqual(result["BUILD_VARIANT"], "study-live-activity")
        self.assertEqual(result["IPA_FILENAME"], "AkshatOS-study-live-activity-unsigned.ipa")
        self.assertEqual(result["IPA_ARTIFACT_NAME"], "akshatos-ios-123-study-live-activity")
        self.assertTrue(result["DEVICE_DERIVED_DATA"].endswith("DerivedData-activity-device"))

    def test_unknown_variants_and_unsafe_environment_values_fail(self):
        for variant, root, number in (("other", tempfile.gettempdir(), 1), ("standard", "relative", 1),
                                      ("standard", tempfile.gettempdir() + "\nINJECTED=yes", 1),
                                      ("standard", tempfile.gettempdir(), 0)):
            with self.assertRaises(ValueError): variants.resolve(variant, root, number)


if __name__ == "__main__":
    unittest.main()
