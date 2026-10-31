import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class RunScriptTest(unittest.TestCase):
    def setUp(self):
        self.workspace = tempfile.TemporaryDirectory()
        self.addCleanup(self.workspace.cleanup)
        self.root = Path(self.workspace.name)
        repository = Path(__file__).resolve().parents[2]
        shutil.copytree(repository / "tool", self.root / "tool")
        binary = self.root / "bin"
        binary.mkdir()
        flutter = binary / "flutter"
        flutter.write_text(
            '#!/bin/bash\n'
            'if [[ "$1" == "devices" ]]; then\n'
            '  printf "%s\\n" "${FLUTTER_DEVICES:-[]}"\n'
            '  exit 0\n'
            'fi\n'
            'printf "%s\\n" "$@" > "$FLUTTER_ARGS"\n'
            'exit "${FLUTTER_EXIT_CODE:-0}"\n'
        )
        flutter.chmod(0o755)
        self.arguments_file = self.root / "flutter-args"
        self.environment = dict(
            os.environ,
            PATH=f"{binary}:{os.environ['PATH']}",
            FLUTTER_ARGS=str(self.arguments_file),
        )

    def run_script(self, *arguments):
        return subprocess.run(
            ["bash", str(self.root / "tool/run.sh"), *arguments],
            env=self.environment,
            text=True,
            capture_output=True,
        )

    def write_config(self, relative_path, values):
        destination = self.root / relative_path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(json.dumps(values))
        return destination

    def firebase_config(self):
        return self.write_config("config/firebase/development/ios.json", {
            "FIREBASE_API_KEY": "test-api-key",
            "FIREBASE_APP_ID": "test-app-id",
            "FIREBASE_MESSAGING_SENDER_ID": "123456789",
            "FIREBASE_PROJECT_ID": "test-project",
        })

    def test_debug_runs_without_service_configuration(self):
        result = self.run_script("dev", "ios", "--device-id=test-ios")
        self.assertEqual(result.returncode, 0, result.stderr)
        arguments = self.arguments_file.read_text().splitlines()
        self.assertIn("--dart-define=CLASSFLOW_ENV=development", arguments)
        self.assertIn("test-ios", arguments)
        self.assertFalse(any("--dart-define-from-file=" in value for value in arguments))

    def test_existing_configs_are_validated_and_forwarded(self):
        firebase = self.firebase_config()
        revenuecat = self.write_config("config/revenuecat/development.json", {
            "REVENUECAT_API_KEY": "test-revenuecat-key",
        })
        result = self.run_script("dev", "ios", "--device-id=test-ios")
        self.assertEqual(result.returncode, 0, result.stderr)
        arguments = self.arguments_file.read_text().splitlines()
        for config in (firebase, revenuecat):
            self.assertIn(f"--dart-define-from-file={config}", arguments)

    def test_firebase_can_be_added_without_revenuecat(self):
        firebase = self.firebase_config()
        result = self.run_script("dev", "ios", "--device-id=test-ios")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(f"--dart-define-from-file={firebase}", self.arguments_file.read_text())

    def test_invalid_existing_configuration_blocks_flutter(self):
        for path, values in (
            ("config/firebase/development/ios.json", {}),
            ("config/revenuecat/development.json", {"REVENUECAT_API_KEY": "replace_me"}),
        ):
            with self.subTest(path=path):
                config = self.write_config(path, values)
                result = self.run_script("dev", "ios", "--device-id=test-ios")
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(self.arguments_file.exists())
                config.unlink()

    def test_release_requires_both_configurations(self):
        for firebase_present in (False, True):
            with self.subTest(firebase_present=firebase_present):
                if firebase_present:
                    self.firebase_config()
                result = self.run_script("dev", "ios", "--release", "--device-id=test-ios")
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(self.arguments_file.exists())

    def test_web_uses_chrome_without_configuration(self):
        result = self.run_script("dev", "web")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("chrome", self.arguments_file.read_text().splitlines())

    def test_single_ios_device_is_selected_without_configuration(self):
        self.environment["FLUTTER_DEVICES"] = json.dumps([
            {"id": "test-ios", "targetPlatform": "ios"},
            {"id": "test-android", "targetPlatform": "android-arm64"},
        ])
        result = self.run_script("dev", "ios")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("test-ios", self.arguments_file.read_text().splitlines())

    def test_device_discovery_requires_supported_matching_device(self):
        for devices in ([], [
            {"id": "unsupported-ios", "targetPlatform": "ios", "isSupported": False},
            {"id": "android", "targetPlatform": "android-arm64"},
        ]):
            with self.subTest(devices=devices):
                self.environment["FLUTTER_DEVICES"] = json.dumps(devices)
                result = self.run_script("dev", "ios")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("기기", result.stderr)
                self.assertFalse(self.arguments_file.exists())

    def test_defaults_and_automatic_device_selection(self):
        self.environment["FLUTTER_DEVICES"] = json.dumps([
            {"id": "unsupported-ios", "targetPlatform": "ios", "isSupported": False},
            {"id": "first-ios", "name": "iPhone Simulator", "targetPlatform": "ios", "isSupported": True},
            {"id": "second-ios", "name": "Other iPhone", "targetPlatform": "ios", "isSupported": True},
        ])
        for arguments, environment in (
            ((), "development"),
            (("dev",), "development"),
            (("stage",), "stage"),
            (("--debug",), "development"),
        ):
            with self.subTest(arguments=arguments):
                result = self.run_script(*arguments)
                self.assertEqual(result.returncode, 0, result.stderr)
                forwarded = self.arguments_file.read_text().splitlines()
                self.assertIn(f"--dart-define=CLASSFLOW_ENV={environment}", forwarded)
                self.assertEqual(forwarded[-2:], ["-d", "first-ios"])
                self.assertIn("first-ios", result.stdout)
                self.assertIn("iPhone Simulator", result.stdout)

    def test_explicit_device_overrides_automatic_selection(self):
        result = self.run_script("--device-id=chosen-ios")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.arguments_file.read_text().splitlines()[-2:], ["-d", "chosen-ios"])

    def test_vscode_selected_device_is_used_before_automatic_selection(self):
        self.environment["CLASSFLOW_DEVICE_ID"] = "selected-ios"
        self.environment["FLUTTER_DEVICES"] = json.dumps([
            {"id": "first-ios", "name": "First iPhone", "targetPlatform": "ios"},
            {"id": "selected-ios", "name": "Selected iPhone", "targetPlatform": "ios"},
        ])
        result = self.run_script("dev", "ios")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.arguments_file.read_text().splitlines()[-2:], ["-d", "selected-ios"])
        self.assertIn("selected-ios (Selected iPhone)", result.stdout)

    def test_vscode_task_device_argument_is_used_before_automatic_selection(self):
        self.environment["FLUTTER_DEVICES"] = json.dumps([
            {"id": "first-ios", "name": "First iPhone", "targetPlatform": "ios"},
            {"id": "selected-ios", "name": "Selected iPhone", "targetPlatform": "ios"},
        ])
        result = self.run_script("--vscode-device-id=selected-ios")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.arguments_file.read_text().splitlines()[-2:], ["-d", "selected-ios"])
        self.assertIn("VS Code 선택: selected-ios (Selected iPhone)", result.stdout)

    def test_explicit_device_overrides_vscode_selected_device(self):
        self.environment["CLASSFLOW_DEVICE_ID"] = "vscode-ios"
        result = self.run_script(
            "--device-id=chosen-ios",
            "--vscode-device-id=task-ios",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.arguments_file.read_text().splitlines()[-2:], ["-d", "chosen-ios"])

    def test_help_works_without_positional_arguments(self):
        result = self.run_script("--help")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.arguments_file.exists())

    def test_extra_defines_are_forwarded(self):
        result = self.run_script(
            "dev", "web", "--dart-define=TEST_VALUE=hello world",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(
            "--dart-define=TEST_VALUE=hello world",
            self.arguments_file.read_text().splitlines(),
        )

    def test_flutter_failure_is_preserved(self):
        self.environment["FLUTTER_EXIT_CODE"] = "7"
        result = self.run_script("dev", "ios", "--device-id=test-ios")
        self.assertEqual(result.returncode, 7, result.stderr)


if __name__ == "__main__":
    unittest.main()