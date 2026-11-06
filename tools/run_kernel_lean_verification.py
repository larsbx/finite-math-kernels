#!/usr/bin/env python3
"""Exact-revision Lean gate and native finite conformance, never promotion."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

from kernel_lean_conformance import generate
from word_counter_oracle import check_transcript, lean_replay

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "tests/lean"
STANDARD = {"propext", "Classical.choice", "Quot.sound"}


def output(cmd, cwd=ROOT):
    return subprocess.check_output(cmd, cwd=cwd, text=True).strip()


def check_axiom_log(audit_log, names):
    for name in names:
        if audit_log.count("'" + name + "'") != 1:
            raise ValueError("incomplete or duplicate audit output: " + name)
    blocks = re.findall(r"depends on axioms:\s*\[([^\]]*)\]", audit_log, re.S)
    if len(blocks) != audit_log.count("depends on axioms:"):
        raise ValueError("malformed axiom report")
    for block in blocks:
        axioms = {a.strip() for a in block.split(",") if a.strip()}
        if axioms - STANDARD:
            raise ValueError("unapproved proof assumption: " + block)


def run_gate(expected, destination):
    destination = destination.resolve()
    destination.mkdir(parents=True, exist_ok=True)
    receipt = {"format": "finite-math-kernels-lean-v1", "expected_revision": expected,
               "status": "failed", "implementation_refinement": "open",
               "commands": [], "scope": "model proofs plus finite native conformance"}
    try:
        if not re.fullmatch(r"[0-9a-f]{40}", expected):
            raise ValueError("full reviewed revision required")
        revision = output(["git", "rev-parse", "HEAD"])
        if revision != expected or output(["git", "status", "--porcelain"]):
            raise ValueError("wrong revision or dirty starting checkout")
        receipt["revision"] = revision
        paths = output(["git", "ls-files"]).splitlines()
        inputs = [ROOT / p for p in paths if p.endswith((".lean", ".mojo"))
                  or p.startswith("tools/") and ("lean" in p or p == "tools/word_counter_oracle.py")
                  or p in ["tests/lean/lean-toolchain", "tests/lean/lakefile.toml",
                           "tests/lean/lake-manifest.json", "tests/lean/coverage.json", "pixi.toml"]]
        digest = lambda: {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
        receipt["source_sha256"] = digest()
        pin = (PROJECT / "lean-toolchain").read_text().strip()
        receipt["lean"] = output(["elan", "run", pin, "lean", "--version"], PROJECT)
        receipt["mojo"] = output(["pixi", "run", "mojo", "--version"])
        if not receipt["lean"].startswith("Lean (version 4.34.0-rc2,"):
            raise ValueError("unexpected Lean executable")
        if "1.1.0.dev2026090805" not in receipt["mojo"]:
            raise ValueError("unexpected Mojo compiler")
        manifest = json.loads((PROJECT / "lake-manifest.json").read_text())
        for package in manifest["packages"]:
            actual = output(["git", "rev-parse", "HEAD"], PROJECT / ".lake/packages" / package["name"])
            if actual != package["rev"]:
                raise ValueError("unpinned Lake dependency " + package["name"])

        def execute(label, cmd, cwd=ROOT, negative=False):
            receipt["commands"].append({"label": label, "argv": cmd, "negative": negative})
            log = destination / (label + ".log")
            with log.open("w") as stream:
                proc = subprocess.run(cmd, cwd=cwd, stdout=stream, stderr=subprocess.STDOUT)
            print(log.read_text(), end="", flush=True)
            if negative == (proc.returncode == 0):
                raise RuntimeError(label + " returned an unexpected exit code")
            return log.read_text()

        native_cmd = ["pixi", "run", "mojo", "run", "-I", "kernel", "tests/lean/native_transcript.mojo"]
        receipt["commands"].append({"label": "native", "argv": native_cmd, "negative": False})
        native_run = subprocess.run(native_cmd, cwd=ROOT, text=True, capture_output=True)
        (destination / "native.log").write_text(native_run.stdout)
        (destination / "native.stderr.log").write_text(native_run.stderr)
        print(native_run.stderr, end="", flush=True)
        if native_run.returncode:
            raise RuntimeError("native compiler/execution failed")
        native = native_run.stdout
        lean, cases = generate(native)
        (destination / "NativeReplay.lean").write_text(lean)
        receipt["finite_native_cases"] = cases
        receipt["native_transcript_sha256"] = hashlib.sha256(native.encode()).hexdigest()
        observed = execute("counter-boundaries", ["pixi", "run", "mojo", "run", "-I", "kernel", "tests/lean/word_counter_overflow.mojo"])
        counter_rows = check_transcript(observed)
        (destination / "CounterReplay.lean").write_text(lean_replay(counter_rows))
        receipt["native_counter_regressions"] = {
            "source": "kernel/substitution_dynamics/words.mojo", "operation": "n3",
            "cases": len(counter_rows),
            "transcript_sha256": hashlib.sha256(observed.encode()).hexdigest(),
            "historical_counterexample_revision": "4fea04f7c2f88707bca8642d01711331dbeac792",
            "classification": "checked refusal; exact on successful fitting intermediates; unbounded model is separate"}
        with tempfile.TemporaryDirectory(prefix="fmk-lean-") as temporary:
            work = Path(temporary)
            for p in PROJECT.iterdir():
                if p.is_file() and p.suffix in {".lean", ".toml", ".json"} or p.name == "lean-toolchain":
                    shutil.copy2(p, work / p.name)
            shutil.copytree(PROJECT / "FiniteMathKernels", work / "FiniteMathKernels")
            (work / ".lake").mkdir()
            (work / ".lake/packages").symlink_to((PROJECT / ".lake/packages").resolve(), target_is_directory=True)
            files = [work / "FiniteMathKernels.lean"] + sorted((work / "FiniteMathKernels").glob("*.lean"))
            names = []
            for p in files:
                source = p.read_text()
                if re.search(r"\b(sorry|admit|axiom|native_decide|unsafe)\b", source):
                    raise ValueError("proof escape in " + p.name)
                namespace = re.search(r"^namespace (\S+)$", source, re.M)
                declarations = re.findall(r"^(?:@\[[^\n]*\]\s*)?theorem\s+(\w+)", source, re.M)
                if declarations and namespace is None:
                    raise ValueError("proof declarations without an audited namespace")
                names += [namespace[1] + "." + n for n in declarations]
            coverage = json.loads((PROJECT / "coverage.json").read_text())
            bindings = {n for entry in coverage["modules"] for n in entry["model_declarations"]}
            if not bindings <= set(names):
                raise ValueError("coverage inventory binds a missing Lean declaration")
            execute("build", ["elan", "run", pin, "lake", "build"], work)
            execute("native-lean", ["elan", "run", pin, "lake", "env", "lean", str(destination / "NativeReplay.lean")], work)
            execute("counter-lean", ["elan", "run", pin, "lake", "env", "lean", str(destination / "CounterReplay.lean")], work)
            # Audit mathematical model declarations independently of the finite cases.
            audit = "import FiniteMathKernels\n" + "\n".join("#print axioms " + n for n in names) + "\n"
            (destination / "AxiomAudit.lean").write_text(audit)
            audit_log = execute("axioms", ["elan", "run", pin, "lake", "env", "lean", str(destination / "AxiomAudit.lean")], work)
            check_axiom_log(audit_log, names)
            for label, proposition in {
                "negative-word": "Conformance.parikhVector 2 [0] = [0,1]",
                "negative-overflow": "CheckedInt.accept64 (CheckedInt.upper64+1) = some CheckedInt.lower64",
                "negative-rejection": "AcceptedField.eqAccepted (none : Option (ZMod 7)) none = true",
                "negative-noncanonical": "(1 : ZMod 7) = (8 : ZMod 7) ∧ (8 : ℕ) < 7",
            }.items():
                bad = "import FiniteMathKernels\nopen FiniteMathKernels\nexample : " + proposition + " := by decide\n"
                bad_path = destination / (label + ".lean")
                bad_path.write_text(bad)
                execute(label, ["elan", "run", pin, "lake", "env", "lean", str(bad_path)], work, negative=True)
            for name in ["lean-toolchain", "lakefile.toml", "lake-manifest.json"]:
                if (work / name).read_bytes() != (PROJECT / name).read_bytes():
                    raise ValueError("Lake altered pinned configuration")
        if receipt["source_sha256"] != digest() or output(["git", "status", "--porcelain"]) or output(["git", "rev-parse", "HEAD"]) != revision:
            raise ValueError("source changed during verification")
        receipt.update(status="passed", model_proofs=len(names), audited_names=names,
                       permitted_axioms=sorted(STANDARD), negative_controls=4)
    except Exception as error:
        receipt["error"] = str(error)
        raise
    finally:
        (destination / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--expected-revision", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    run_gate(args.expected_revision, args.output)
