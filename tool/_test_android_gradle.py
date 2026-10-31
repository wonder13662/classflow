from pathlib import Path
import sys
import time
import unittest


class CountingTestResult(unittest.TextTestResult):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.success_count = 0

    def addSuccess(self, test):
        super().addSuccess(test)
        self.success_count += 1


def main():
    started = time.perf_counter()
    repository = Path(__file__).resolve().parents[1]
    suite = unittest.defaultTestLoader.discover(
        str(repository / "test/tool"), pattern="android_gradle_test.py"
    )
    result = unittest.TextTestRunner(
        verbosity=2, resultclass=CountingTestResult
    ).run(suite)
    elapsed_ms = int((time.perf_counter() - started) * 1000)
    elapsed_seconds, milliseconds = divmod(elapsed_ms, 1000)
    hours, remaining_seconds = divmod(elapsed_seconds, 3600)
    minutes, seconds = divmod(remaining_seconds, 60)
    total = result.testsRun
    ratio = result.success_count / total * 100 if total else 0
    print(
        f"[Summary] Duration: {hours:02}:{minutes:02}:{seconds:02}.{milliseconds:03}"
    )
    print(f"[Summary] Total tests: {total}")
    print(f"[Summary] Passed: {result.success_count}/{total} ({ratio:.2f}%)")
    print(
        f"[Summary] Failures: {len(result.failures)}, "
        f"Errors: {len(result.errors)}, Skipped: {len(result.skipped)}"
    )
    print(
        f"[Summary] Expected failures: {len(result.expectedFailures)}, "
        f"Unexpected successes: {len(result.unexpectedSuccesses)}"
    )
    if not total:
        print("[Failed] No tests found", file=sys.stderr)
        return 1
    if result.wasSuccessful():
        print("[Done] Android Gradle tests passed")
        return 0
    print("[Failed] Android Gradle tests failed", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
