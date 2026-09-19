"""The reporter's own self-test, run as a driver.

Run with `pixi run test-mojo-smoke`
(`mojo run -I . tests/mojo_smoke/test_report.mojo`).
"""

from mojo_smoke.report import SmokeReport, smoke_report_smoke


def test_a_silent_report_counts_and_names_a_failure() -> Bool:
    var report = SmokeReport(echo=False)
    _ = report.record("passing", True)
    _ = report.record("failing", False)
    return report.total() == 2 and not report.all_passed() and report.failed_names() == "failing"


def main() raises:
    if not smoke_report_smoke():
        raise Error("smoke reporter self-test failed")
    if not test_a_silent_report_counts_and_names_a_failure():
        raise Error("smoke reporter miscounts")
    print("mojo_smoke reporter checks passed.")
