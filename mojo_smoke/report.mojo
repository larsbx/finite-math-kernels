# report.mojo
#
# Named reporting for a Mojo smoke suite.
#
# The suite used to be one chain of `if not case(): return False`, so a
# failure reported a single bare FAIL: which of the fifty checks broke, and
# whether anything after it also broke, were invisible. A named case fixes
# both. `SmokeReport.record` runs every case, prints `[PASS] name` or
# `[FAIL] name` as it goes, and keeps counting after a failure, so one run
# names every broken contract rather than only the first.
#
# The report is a value, not a global: a driver makes one, records into it,
# and asks it whether everything passed. Recording is the only way to change
# it, so a case cannot be counted without being named, and the printed lines
# and the verdict cannot disagree.
#
# This is test scaffolding. It computes nothing mathematical and certifies
# nothing; it only reports what the cases it is handed returned.


struct SmokeCase(ImplicitlyCopyable, Copyable, Movable):
    """One named check and the verdict it returned."""

    var name: String
    var passed: Bool

    def __init__(out self, name: String, passed: Bool):
        self.name = name
        self.passed = passed


struct SmokeReport(Copyable, Movable):
    """Every case run so far, in order, with a running failure count."""

    var cases: List[SmokeCase]
    var failures: Int
    var echo: Bool

    def __init__(out self, echo: Bool = True):
        """`echo` prints each verdict as it is recorded. The reporter's own
        self-test records a deliberate failure, so it keeps a silent report:
        a printed `[FAIL]` should only ever mean a real one."""
        self.cases = List[SmokeCase]()
        self.failures = 0
        self.echo = echo

    def record(mut self, name: String, passed: Bool) -> Bool:
        """Name a case, print its verdict, and keep it. Returns the verdict so
        a caller can branch, but the suite is expected to run every case."""
        self.cases.append(SmokeCase(name, passed))
        if not passed:
            self.failures += 1
        if self.echo:
            print("[PASS]" if passed else "[FAIL]", name)
        return passed

    def total(self) -> Int:
        return len(self.cases)

    def all_passed(self) -> Bool:
        return self.failures == 0

    def failed_names(self) -> String:
        var out = String("")
        for i in range(len(self.cases)):
            if not self.cases[i].passed:
                out += ("" if out.byte_length() == 0 else ", ") + self.cases[i].name
        return out

    def print_summary(self, label: String):
        print("")
        if self.all_passed():
            print(label + ":", self.total(), "cases, all passed.")
            return
        print(label + ":", self.failures, "of", self.total(), "cases FAILED")
        print("  failed:", self.failed_names())


def smoke_report_smoke() -> Bool:
    """The reporter itself: a recorded failure is counted and named, and a
    report with no failures passes."""
    var report = SmokeReport(echo=False)
    if report.total() != 0 or not report.all_passed():
        return False
    if not report.record("reporter accepts a passing case", True):
        return False
    if report.record("reporter counts a failing case", False):
        return False
    if report.total() != 2 or report.all_passed() or report.failures != 1:
        return False
    return report.failed_names() == "reporter counts a failing case"
