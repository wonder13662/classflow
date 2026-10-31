from pathlib import Path
import shutil
import subprocess
import tempfile
import textwrap
import unittest


class AndroidGradleScriptTest(unittest.TestCase):
    def setUp(self):
        self.workspace = tempfile.TemporaryDirectory()
        self.addCleanup(self.workspace.cleanup)
        self.root = Path(self.workspace.name)
        repository = Path(__file__).resolve().parents[2]
        shutil.copytree(repository / "tool", self.root / "tool")
        self.tests = self.root / "test/tool"
        self.tests.mkdir(parents=True)

    def run_script(self, source):
        (self.tests / "android_gradle_test.py").write_text(textwrap.dedent(source))
        return subprocess.run(
            ["bash", str(self.root / "tool/test_android_gradle.sh")],
            cwd=self.tests,
            text=True,
            capture_output=True,
        )

    def test_success_reports_count_ratio_and_duration(self):
        result = self.run_script("""
            import unittest
            class ExampleTest(unittest.TestCase):
                def test_first(self):
                    self.assertTrue(True)
                def test_second(self):
                    self.assertEqual(1, 1)
        """)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Passed: 2/2 (100.00%)", result.stdout)
        self.assertRegex(result.stdout, r"Duration: \d{2}:\d{2}:\d{2}\.\d{3}")

    def test_failures_errors_and_skips_are_not_counted_as_successes(self):
        result = self.run_script("""
            import unittest
            class ExampleTest(unittest.TestCase):
                def test_success(self):
                    pass
                def test_failure(self):
                    self.fail('expected failure')
                def test_error(self):
                    raise RuntimeError('expected error')
                @unittest.skip('not available')
                def test_skip(self):
                    pass
        """)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("Passed: 1/4 (25.00%)", result.stdout)
        self.assertIn("Failures: 1", result.stdout)
        self.assertIn("Errors: 1", result.stdout)
        self.assertIn("Skipped: 1", result.stdout)
        self.assertIn("expected error", result.stderr)

    def test_multiple_failed_subtests_do_not_make_success_count_negative(self):
        result = self.run_script("""
            import unittest
            class ExampleTest(unittest.TestCase):
                def test_subtests(self):
                    for value in (1, 2):
                        with self.subTest(value=value):
                            self.assertEqual(value, 0)
        """)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("Passed: 0/1 (0.00%)", result.stdout)

    def test_expected_and_unexpected_failures_are_reported_separately(self):
        result = self.run_script("""
            import unittest
            class ExampleTest(unittest.TestCase):
                @unittest.expectedFailure
                def test_expected_failure(self):
                    self.fail('known failure')
                @unittest.expectedFailure
                def test_unexpected_success(self):
                    pass
        """)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("Passed: 0/2 (0.00%)", result.stdout)
        self.assertIn("Expected failures: 1", result.stdout)
        self.assertIn("Unexpected successes: 1", result.stdout)

    def test_empty_suite_fails_without_dividing_by_zero(self):
        result = self.run_script("import unittest\n")
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("Passed: 0/0 (0.00%)", result.stdout)
        self.assertIn("No tests found", result.stderr)

    def test_import_error_is_reported_as_a_failed_run(self):
        result = self.run_script("raise RuntimeError('cannot import tests')\n")
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("Errors: 1", result.stdout)
        self.assertIn("cannot import tests", result.stderr)


if __name__ == "__main__":
    unittest.main()
