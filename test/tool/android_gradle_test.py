from pathlib import Path
import re
import unittest


class AndroidGradleTest(unittest.TestCase):
    def test_kotlin_plugin_is_applied_between_android_and_flutter(self):
        repository = Path(__file__).resolve().parents[2]
        build_script = (repository / "android/app/build.gradle.kts").read_text()
        plugins_block = re.search(r"(?ms)^plugins \{(.*?)^\}", build_script)
        self.assertIsNotNone(plugins_block)
        plugins = re.findall(
            r'^\s*id\("([^\"]+)"\)\s*$', plugins_block.group(1), re.MULTILINE
        )
        android_plugin = "com.android.application"
        kotlin_plugin = "org.jetbrains.kotlin.android"
        flutter_plugin = "dev.flutter.flutter-gradle-plugin"
        for plugin in (android_plugin, kotlin_plugin, flutter_plugin):
            self.assertIn(plugin, plugins)
        self.assertLess(plugins.index(android_plugin), plugins.index(kotlin_plugin))
        self.assertLess(plugins.index(kotlin_plugin), plugins.index(flutter_plugin))