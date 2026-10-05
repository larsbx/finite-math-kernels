#!/usr/bin/env python3
"""Evidence for the Mojo "use of uninitialized value" bug on associated-type fields.

Each case is `repro.mojo` with declared edits, or a witness taken from this
repository's kernel. Every case is compiled and run with the pinned toolchain,
and its outcome is compared with the declared expectation.

Usage (from the repository root):
    pixi run mojo-issue-evidence           run every case, write evidence.log and evidence.json
    pixi run mojo-issue-evidence --check   run every case, write nothing, exit 1 on any mismatch

A mismatch means the toolchain's behaviour changed: a fixed compiler shows up as
the bug cases compiling. Non-authoritative experiment; it decides no claim.
"""

from __future__ import annotations

import json
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import time
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
REPRO = HERE / "repro.mojo"
ERROR = re.compile(r"error: (?P<message>.*)")
NOISE = ("Crashpad",)


@dataclass(frozen=True)
class Case:
    name: str
    why: str
    expect: str                                   # "error: <message>" or the expected stdout
    edits: tuple[tuple[str, str], ...] = ()
    source: str | None = None                     # a full program instead of edits to repro.mojo
    kernel: bool = False                          # compile with -I kernel


@dataclass
class Outcome:
    name: str
    why: str
    expect: str
    observed: str
    agrees: bool
    exit_code: int
    seconds: float
    diagnostics: list[str] = field(default_factory=list)


CASES = (
    Case("repro", "the minimal program", "error: use of uninitialized value 's.x'"),
    # 1. the associated type is necessary
    Case(
        "plain-type-parameter",
        "S[T: Copyable & Deinitable] with x: Self.T instead of the associated type K.Element",
        "True",
        (
            ("struct S[K: Field](Copyable):\n    var x: Self.K.Element", "struct S[T: Copyable & Deinitable](Copyable):\n    var x: Self.T"),
            ("def __init__(out self, x: Self.K.Element):", "def __init__(out self, x: Self.T):"),
            ("S[VField](V(0))", "S[V](V(0))"),
        ),
    ),
    # 3. the named local is necessary
    Case("temporary-operand", "s.x == V(0): a temporary instead of the named local v", "True", (("print(s.x == v)", "print(s.x == V(0))"),)),
    # what does not matter
    Case("swapped-operands", "v == s.x", "error: use of uninitialized value 's.x'", (("print(s.x == v)", "print(v == s.x)"),)),
    Case(
        "copy-first",
        "var w = s.x.copy(); print(w == v): copying the field first is no workaround",
        "error: use of uninitialized value 's.x'",
        (("    print(s.x == v)", "    var w = s.x.copy()\n    print(w == v)"),),
    ),
    Case("int-subfield", "s.x.a == v.a: comparing Int subfields compiles", "True", (("print(s.x == v)", "print(s.x.a == v.a)"),)),
    Case(
        "second-struct-field",
        "S with a second field: the diagnostic names that field instead",
        "error: use of uninitialized value 's.flag'",
        (
            ("    var x: Self.K.Element\n", "    var x: Self.K.Element\n    var flag: Bool\n"),
            ("        self.x = x.copy()\n", "        self.x = x.copy()\n        self.flag = False\n"),
        ),
    ),
    Case(
        "movable-bounds",
        "Element: Copyable & Movable & Deinitable, and S also Movable",
        "error: use of uninitialized value 's.x'",
        (
            ("comptime Element: Copyable & Deinitable", "comptime Element: Copyable & Movable & Deinitable"),
            ("struct S[K: Field](Copyable):", "struct S[K: Field](Copyable, Movable):"),
        ),
    ),
    Case(
        "implicitly-copyable",
        "an ImplicitlyCopyable element",
        "error: use of uninitialized value 's.x'",
        (
            ("comptime Element: Copyable & Deinitable", "comptime Element: ImplicitlyCopyable & Deinitable"),
            ("struct V(Copyable):", "struct V(ImplicitlyCopyable):"),
        ),
    ),
    # the two places it was met in this repository's kernel
    Case(
        "kernel-rotor-over-fp",
        "projective_limits.rotor over F_13: the original occurrence in tests/projective_limits/test_rotor.mojo",
        "error: use of uninitialized value 'back.rejected'",
        source="""from finite_exact.fp import Fp, FpField
from projective_limits.rotor import circle_point, circle_rotor


def main():
    var fx = Fp[13](0)
    var fy = Fp[13](1)
    var t = circle_rotor[FpField[13]](fx, fy)
    var back = circle_point(t)
    print(back.x == fx and back.y == fy)
""",
        kernel=True,
    ),
    Case(
        "kernel-rotor-over-fp-temporaries",
        "the same comparison with temporaries in place of the named locals compiles",
        "True",
        source="""from finite_exact.fp import Fp, FpField
from projective_limits.line import p1_affine
from projective_limits.rotor import circle_point


def main():
    var back = circle_point(p1_affine[FpField[13]](Fp[13](0)))
    print(back.x == Fp[13](1) and back.y == Fp[13](0))
""",
        kernel=True,
    ),
    Case(
        "kernel-cyclotomic-rotor",
        "a rotor over Q(zeta_8): the original occurrence, in tests/cyclotomic/test_cyclotomic_field.mojo at 621202a",
        "error: use of uninitialized value 't.rejected'",
        source="""from finite_polynomial.cyclotomic_field import Cyc, CyclotomicField
from projective_limits.rotor import circle_rotor


def rotor_coordinate() -> Cyc[8]:
    var z = Cyc[8].zeta()
    var t = circle_rotor[CyclotomicField[8]](z, z)
    return t.x.copy()


def main():
    print(rotor_coordinate())
""",
        kernel=True,
    ),
)


def layout(element_fields: int, s_fields: int) -> str:
    """The repro with an element of `element_fields` Int fields (0: the element is Int itself)
    and a struct S of `s_fields` fields: the field-count interaction of necessary condition 3."""
    names = ["a", "b", "c", "d"][:element_fields]
    element = (
        "struct V(Copyable):\n" + "".join(f"    var {n}: Int\n" for n in names)
        + "\n    def __init__(out self, a: Int):\n"
        + "".join(f"        self.{n} = {'a' if n == 'a' else 0}\n" for n in names)
        + "\n    def __eq__(self, other: Self) -> Bool:\n        return self.a == other.a\n\n\n"
        if names else ""
    )
    extra = [f"f{i}" for i in range(s_fields - 1)]
    return (
        "trait Field:\n    comptime Element: Copyable & Deinitable\n\n\n" + element
        + f"struct EField(Field):\n    comptime Element = {'V' if names else 'Int'}\n\n\n"
        + "struct S[K: Field](Copyable):\n    var x: Self.K.Element\n" + "".join(f"    var {e}: Bool\n" for e in extra)
        + "\n    def __init__(out self, x: Self.K.Element):\n        self.x = x.copy()\n"
        + "".join(f"        self.{e} = False\n" for e in extra)
        + f"\n\ndef main():\n    var v = {'V(0)' if names else '0'}\n    var s = S[EField]({'V(0)' if names else '0'})\n    print(s.x == v)\n"
    )


#: Observed outcome per (element fields, S fields); 0 element fields means an Int element.
#: An entry is the uninitialized field S reports, or None for "compiles and prints True".
LAYOUTS = {
    (0, 1): None, (0, 2): None, (0, 3): None,
    (1, 1): "s.x", (1, 2): None, (1, 3): None,
    (2, 1): "s.x", (2, 2): "s.f0", (2, 3): None,
    (3, 1): "s.x", (3, 2): "s.f0", (3, 3): "s.f1",
}

CASES += tuple(
    Case(
        f"layout-element{e}-s{n}",
        f"element {'Int' if e == 0 else f'V with {e} field(s)'}, S with {n} field(s)",
        "True" if err is None else f"error: use of uninitialized value '{err}'",
        source=layout(e, n),
    )
    for (e, n), err in LAYOUTS.items()
)


def program(case: Case, base: str) -> str:
    if case.source is not None:
        return case.source
    text = base
    for old, new in case.edits:
        if text.count(old) != 1:
            raise ValueError(f"{case.name}: edit target must occur exactly once: {old!r}")
        text = text.replace(old, new)
    return text


def run(case: Case, mojo: str, base: str, workdir: Path) -> Outcome:
    path = workdir / f"{case.name}.mojo"
    path.write_text(program(case, base))
    command = [mojo, "run"] + (["-I", str(ROOT / "kernel")] if case.kernel else []) + [str(path)]
    start = time.monotonic()
    done = subprocess.run(command, capture_output=True, text=True, cwd=ROOT)
    seconds = time.monotonic() - start
    lines = [ln for ln in (done.stdout + done.stderr).splitlines() if ln.strip() and not any(n in ln for n in NOISE)]
    errors = [m.group("message") for m in map(ERROR.search, lines) if m]
    source_errors = [e for e in errors if not e.startswith("failed to")]
    observed = f"error: {source_errors[0]}" if done.returncode and source_errors else done.stdout.strip()
    local = lambda ln: ln.replace(str(workdir) + "/", "").replace(str(ROOT) + "/", "")
    diagnostics = [local(ln) for ln in lines] if done.returncode else []
    return Outcome(case.name, case.why, case.expect, observed, observed == case.expect, done.returncode, round(seconds, 2), diagnostics)


def environment(mojo: str) -> dict:
    git = lambda *args: subprocess.run(["git", *args], capture_output=True, text=True, cwd=ROOT).stdout.strip()
    return {
        "date_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "mojo": subprocess.run([mojo, "--version"], capture_output=True, text=True).stdout.strip(),
        "platform": platform.platform(),
        "python": platform.python_version(),
        "repository_commit": git("rev-parse", "HEAD"),
        "working_tree_clean": git("status", "--porcelain", "--", "kernel", str(HERE.relative_to(ROOT))) == "",
    }


def render_log(env: dict, outcomes: list[Outcome]) -> str:
    out = ["Mojo issue evidence: use of uninitialized value on associated-type fields", ""]
    out += [f"{k:20} {v}" for k, v in env.items()]
    out += ["", f"{'case':34} {'agrees':7} {'exit':5} {'seconds':8} observed"]
    out += [f"{o.name:34} {('yes' if o.agrees else 'NO'):7} {o.exit_code:<5} {o.seconds:<8} {o.observed}" for o in outcomes]
    for o in outcomes:
        out += ["", f"--- {o.name}: {o.why}", f"expect:   {o.expect}", f"observed: {o.observed}"]
        out += [f"  | {line}" for line in o.diagnostics]
    disagree = [o.name for o in outcomes if not o.agrees]
    out += ["", f"{len(outcomes) - len(disagree)} of {len(outcomes)} cases agree with their declared expectation."]
    if disagree:
        out += ["Disagreeing: " + ", ".join(disagree)]
    return "\n".join(out) + "\n"


def main(argv: list[str]) -> int:
    mojo = shutil.which("mojo")
    if mojo is None:
        print("mojo is not on PATH; run through `pixi run`", file=sys.stderr)
        return 2
    base = REPRO.read_text()
    with tempfile.TemporaryDirectory() as tmp:
        outcomes = [run(case, mojo, base, Path(tmp)) for case in CASES]
    env = environment(mojo)
    log = render_log(env, outcomes)
    print(log, end="")
    if "--check" not in argv:
        (HERE / "evidence.log").write_text(log)
        (HERE / "evidence.json").write_text(json.dumps({"environment": env, "cases": [asdict(o) for o in outcomes]}, indent=2) + "\n")
    return 0 if all(o.agrees for o in outcomes) else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
