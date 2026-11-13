#!/usr/bin/env python3
"""Fresh, exact-revision acceptance of generic binary-weight arithmetic.

This focused proof gate changes no native status. --preflight exercises the same
proof checks on a working tree but can never set accepted=true.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import time
import tomllib


ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "tests/lean"
ALLOWED = {"propext", "Classical.choice", "Quot.sound"}
LEAN_PIN = "leanprover/lean4:v4.34.0-rc2"
LEAN_COMMIT = "6a10ac8c22beadecabdbb0919c2b50214762f91d"
MODULES = ["FiniteMathKernels.BinaryWeight", "FiniteMathKernels.BinaryWeightContracts",
           "BinaryWeightControls"]
MODEL_NAMES = ["binaryWeight_zero", "binaryWeight_one", "binaryWeight_two_mul",
               "binaryWeight_two_mul_add_one", "binaryWeight_succ_le", "binaryWeight_add_le",
               "binaryWeight_two_pow_mul", "binaryWeight_mul_two_pow",
               "binaryWeight_div_two_le", "binaryWeight_div_two_pow_le",
               "binaryWeight_two_pow_sub_one", "binaryWeight_sq_le"]
CONTRACT_NAMES = ["zero", "one", "lowZero", "lowOne", "successor", "addition",
                  "leftShift", "rightFactor", "dropBit", "dropBits", "lowOnes", "square"]
CONTROL_NAMES = ["weightZero", "weightEight", "weightFifteen", "carryRemovesOne",
                 "additionNotEquality", "divisionCanLoseBits", "divisionNotEquality",
                 "squareHasMoreBits", "squareBoundAttained", "strongerSquareBoundFalse",
                 "shiftedZero", "allOnesAtZero"]
SOURCE_PATHS = [
    "AGENTS.md", "tests/lean/lean-toolchain", "tests/lean/lakefile.toml",
    "tests/lean/lake-manifest.json", "tests/lean/FiniteMathKernels.lean",
    "tests/lean/FiniteMathKernels/BinaryWeight.lean",
    "tests/lean/FiniteMathKernels/BinaryWeightContracts.lean",
    "tests/lean/BinaryWeightControls.lean", "tools/verify_binary_weight.py",
    "docs/binary-weight.md", "docs/lean-verification.md", "policy/provenance.json",
]

NEGATIVES = {
    "wrong_weight": ("example : binaryWeight 8 = 8 := by decide\n", r"(?i)decide.*proved"),
    "addition_equality": (
        "example : binaryWeight (1 + 1) = binaryWeight 1 + binaryWeight 1 := by decide\n",
        r"(?i)decide.*proved"),
    "division_equality": (
        "example : binaryWeight (7 / 2 ^ 2) = binaryWeight 7 := by decide\n",
        r"(?i)decide.*proved"),
    "stronger_square": (
        "example : 2 * binaryWeight (5 ^ 2) ≤ binaryWeight 5 ^ 2 := by decide\n",
        r"(?i)decide.*proved"),
    "weakened_square_type": (
        "namespace Weakened\ntheorem square (n : ℕ) : binaryWeight n ≤ binaryWeight n := le_refl _\n"
        "end Weakened\nexample (n : ℕ) : 2 * binaryWeight (n ^ 2) ≤ "
        "binaryWeight n * (binaryWeight n + 1) := Weakened.square n\n",
        r"(?i)type mismatch"),
}


def now():
    return datetime.now(timezone.utc).isoformat()


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write_json(path, value):
    Path(path).write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")


def git(*args, cwd=ROOT):
    return subprocess.check_output(["git", *args], cwd=cwd, text=True).strip()


def source_hashes():
    return {path: digest(ROOT / path) for path in SOURCE_PATHS}


def dependency_paths(packages):
    manifest = json.loads((PROJECT / "lake-manifest.json").read_text())
    config = tomllib.loads((PROJECT / "lakefile.toml").read_text())
    expected_mathlib = next(p["rev"] for p in config["require"] if p["name"] == "mathlib")
    mathlib_entry = next(p for p in manifest["packages"] if p["name"] == "mathlib")
    if mathlib_entry["rev"] != expected_mathlib:
        raise RuntimeError("Lake configuration and manifest disagree on mathlib")
    paths, revisions = [], {}
    for package in manifest["packages"]:
        path = packages / package["name"]
        actual = git("rev-parse", "HEAD", cwd=path)
        if actual != package["rev"]:
            raise RuntimeError("dependency revision mismatch: " + package["name"])
        if git("status", "--porcelain", "--untracked-files=no", cwd=path):
            raise RuntimeError("modified dependency sources: " + package["name"])
        compiled = path / ".lake/build/lib/lean"
        if compiled.is_dir():
            paths.append(str(compiled))
        revisions[package["name"]] = actual
    if not (packages / "mathlib/.lake/build/lib/lean/Mathlib/Data/Nat/Digits/Lemmas.olean").is_file():
        raise RuntimeError("missing pinned mathlib digit-module cache")
    return paths, revisions


def audit_source(modules, print_contracts=False):
    """Inspect the actual module constant arrays, including generated helpers."""
    imports = "\n".join(f"import {module}" for module in modules)
    targets = ", ".join(f"`{module}" for module in modules)
    text = imports + f'''
import Lean.Elab.Command
import Lean.Util.CollectAxioms
open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let targets : Array Name := #[{targets}]
  let allowed := #[`propext, `Classical.choice, `Quot.sound]
  for moduleName in targets do
    let some idx := env.getModuleIdx? moduleName | throwError "Missing audited module"
    let data := env.header.moduleData[idx.toNat]!
    for info in data.constants do
      if info.isAxiom then throwError "Local audited axiom"
    let mut count := 0
    let mut proofs := 0
    for info in data.constants do
      let name := info.name
      let axs ← collectAxioms name
      for ax in axs do
        if !allowed.contains ax then throwError "Nonstandard transitive axiom"
      count := count + 1
      if info.isTheorem then proofs := proofs + 1
      let names := String.intercalate "," (axs.toList.map toString)
      liftIO <| IO.println s!"FMK_AXIOMS\t{{moduleName}}\t{{name}}\t{{info.isTheorem}}\t{{names}}"
    if proofs == 0 then throwError "Missing compiled proofs"
    liftIO <| IO.println s!"FMK_COMPLETE\t{{moduleName}}\t{{count}}\t{{proofs}}"
'''
    if print_contracts:
        for name in CONTRACT_NAMES:
            text += f"\n#check FiniteMathKernels.BinaryWeightContracts.{name}"
    return text + "\n"


def parse_audit(output, modules):
    declarations = {module: {} for module in modules}
    completed = {}
    for line in output.splitlines():
        if line.startswith("FMK_AXIOMS\t"):
            _, module, name, is_theorem, axes = line.split("\t")
            if module not in declarations or module in completed or name in declarations[module]:
                raise RuntimeError("duplicate or unexpected compiled declaration")
            if is_theorem not in {"true", "false"}:
                raise RuntimeError("malformed compiled declaration kind")
            axioms = set(filter(None, axes.split(",")))
            if axioms - ALLOWED:
                raise RuntimeError("unapproved assumption in compiled audit receipt")
            declarations[module][name] = {"theorem": is_theorem == "true", "axioms": sorted(axioms)}
        elif line.startswith("FMK_COMPLETE\t"):
            _, module, count, proofs = line.split("\t")
            if module not in declarations or module in completed:
                raise RuntimeError("duplicate or unexpected audit completion")
            if (int(count) != len(declarations[module]) or
                    int(proofs) != sum(x["theorem"] for x in declarations[module].values())):
                raise RuntimeError("incomplete compiled audit")
            completed[module] = {"declarations": int(count), "theorems": int(proofs)}
    if set(completed) != set(modules):
        raise RuntimeError("missing compiled module audit")
    required = [
        (MODULES[0], "FiniteMathKernels.", MODEL_NAMES),
        (MODULES[1], "FiniteMathKernels.BinaryWeightContracts.", CONTRACT_NAMES),
        (MODULES[2], "FiniteMathKernels.BinaryWeightControls.", CONTROL_NAMES),
    ]
    for module, prefix, names in required:
        for name in names:
            if not declarations[module].get(prefix + name, {}).get("theorem"):
                raise RuntimeError("missing compiled theorem: " + prefix + name)
    for name in CONTRACT_NAMES:
        if len(re.findall(r"(?m)^FiniteMathKernels\.BinaryWeightContracts\." + name + r"\b", output)) != 1:
            raise RuntimeError("missing or duplicate printed contract type: " + name)
    return completed, declarations


def run_gate(expected, destination, preflight=False):
    destination = destination.resolve()
    if destination.exists() and any(destination.iterdir()):
        raise RuntimeError("output directory must be empty")
    destination.mkdir(parents=True, exist_ok=True)
    report = {"schema": "finite-math-kernels-binary-weight-v1", "accepted": False,
              "checks_passed": False, "mode": "preflight" if preflight else "acceptance",
              "expected_revision": expected, "started_utc": now(),
              "python": {"executable": sys.executable, "version": sys.version},
              "platform": platform.platform(), "commands": []}
    write_json(destination / "report.json", report)
    try:
        if not re.fullmatch(r"[0-9a-f]{40}", expected):
            raise RuntimeError("a full expected source revision is required")
        revision = git("rev-parse", "HEAD")
        initial_status = git("status", "--porcelain")
        report.update(source_commit=revision, source_tree=git("rev-parse", "HEAD^{tree}"),
                      source_tree_dirty=bool(initial_status), source_sha256=source_hashes())
        if revision != expected or (initial_status and not preflight):
            raise RuntimeError("wrong revision or dirty acceptance checkout")
        if (PROJECT / "lean-toolchain").read_text().strip() != LEAN_PIN:
            raise RuntimeError("Lean toolchain pin changed")
        lean = os.environ.get("LEAN_BIN") or shutil.which("lean")
        if not lean or not Path(lean).is_file():
            raise RuntimeError("Lean executable unavailable; set LEAN_BIN")
        lean = str(Path(lean).resolve())
        packages = Path(os.environ.get("FMK_MATHLIB_PACKAGES", PROJECT / ".lake/packages")).resolve()
        paths, report["dependency_revisions"] = dependency_paths(packages)
        compiled = destination / "lib"
        compiled.mkdir()
        env = os.environ.copy()
        env["LEAN_PATH"] = os.pathsep.join([str(compiled), *paths])
        env["LEAN_NUM_THREADS"] = "1"
        report["lean"] = {"executable": lean, "sha256": digest(lean), "package_cache": str(packages),
                          "LEAN_PATH": env["LEAN_PATH"], "LD_PRELOAD": env.get("LD_PRELOAD", "")}

        def execute(label, command, expected_code=0):
            started = time.monotonic()
            record = {"label": label, "argv": list(map(str, command)), "cwd": str(ROOT),
                      "expected_returncode": expected_code, "timeout_seconds": 900}
            report["commands"].append(record)
            print(label, flush=True)
            try:
                result = subprocess.run(record["argv"], cwd=ROOT, env=env, text=True,
                                        capture_output=True, timeout=900)
                record.update(returncode=result.returncode, stdout=result.stdout, stderr=result.stderr)
            except subprocess.TimeoutExpired as error:
                record.update(error="timeout", stdout=str(error.stdout or ""), stderr=str(error.stderr or ""))
                raise RuntimeError(label + " timed out") from error
            finally:
                record["elapsed_seconds"] = time.monotonic() - started
                write_json(destination / (label + ".json"), record)
            if result.returncode != expected_code:
                raise RuntimeError(label + " returned " + str(result.returncode))
            return result

        version = execute("lean-version", [lean, "--version"])
        report["lean"]["version"] = version.stdout.strip()
        if (not version.stdout.startswith("Lean (version 4.34.0-rc2,") or
                LEAN_COMMIT not in version.stdout):
            raise RuntimeError("unexpected Lean executable version or compiler commit")

        def compile_file(source, name, expected_code=0, emit=True):
            source = Path(source)
            target = compiled / (name.replace(".", "/") + ".olean")
            target.parent.mkdir(parents=True, exist_ok=True)
            module_root = source.parents[len(name.split(".")) - 1]
            command = [lean, "-j1", "--root=" + str(module_root),
                       "-DautoImplicit=false", "-DwarningAsError=true"]
            if emit:
                command += ["-o", target]
            command.append(source)
            result = execute("lean-" + name, command, expected_code)
            if expected_code == 0 and emit and not target.is_file():
                raise RuntimeError("compiler emitted no module: " + name)
            return result

        for module in MODULES:
            source = PROJECT / (module.replace(".", "/") + ".lean")
            if re.search(r"\b(sorry|admit|native_decide|axiom)\b", source.read_text()):
                raise RuntimeError("proof escape in positive source: " + module)
            compile_file(source, module)
        audit = destination / "Audit.lean"
        audit.write_text(audit_source(MODULES, print_contracts=True))
        result = compile_file(audit, "Audit", emit=False)
        report["compiled_modules"], declarations = parse_audit(result.stdout, MODULES)
        write_json(destination / "declaration-axioms.json", declarations)
        report.update(permitted_axioms=sorted(ALLOWED), explicit_model_theorems=len(MODEL_NAMES),
                      explicit_type_wrappers=len(CONTRACT_NAMES), positive_controls=len(CONTROL_NAMES))
        report["negative_controls"] = {}

        def require_rejection(result, diagnostic, name):
            text = result.stdout + result.stderr
            if (len(re.findall(diagnostic, text)) != 1 or
                    len(re.findall(r"(?im)^.*\berror:", text)) != 1):
                raise RuntimeError("control failed for an unintended reason: " + name)
            report["negative_controls"][name] = "rejected"

        for name, (body, diagnostic) in NEGATIVES.items():
            source = destination / ("Reject_" + name + ".lean")
            source.write_text("import FiniteMathKernels.BinaryWeight\nopen FiniteMathKernels\n" + body)
            result = compile_file(source, "Reject_" + name, expected_code=1, emit=False)
            require_rejection(result, diagnostic, name)
        poison = destination / "UntrustedAxiom.lean"
        poison.write_text("axiom injectedAssumption : False\ntheorem injectedClaim : False := injectedAssumption\n")
        compile_file(poison, "UntrustedAxiom")
        local_audit = destination / "AuditUntrusted.lean"
        local_audit.write_text(audit_source(["UntrustedAxiom"]))
        result = compile_file(local_audit, "AuditUntrusted", expected_code=1, emit=False)
        require_rejection(result, "Local audited axiom", "local_axiom_injection")
        inherited = destination / "TransitiveAxiom.lean"
        inherited.write_text("import UntrustedAxiom\ntheorem inheritedPoison : False := injectedClaim\n")
        compile_file(inherited, "TransitiveAxiom")
        inherited_audit = destination / "AuditTransitive.lean"
        inherited_audit.write_text(audit_source(["TransitiveAxiom"]))
        result = compile_file(inherited_audit, "AuditTransitive", expected_code=1, emit=False)
        require_rejection(result, "Nonstandard transitive axiom", "transitive_axiom_injection")
        _, final_dependencies = dependency_paths(packages)
        if (source_hashes() != report["source_sha256"] or git("rev-parse", "HEAD") != revision or
                git("status", "--porcelain") != initial_status or
                final_dependencies != report["dependency_revisions"] or digest(lean) != report["lean"]["sha256"]):
            raise RuntimeError("source, revision, dependency, or compiler changed during verification")
        report["checks_passed"] = True
        report["accepted"] = not preflight
        report["scope"] = "universal natural-number binary-weight arithmetic; no native implementation refinement or normality claim"
    except Exception as error:
        report["error"] = str(error)
        raise
    finally:
        report["finished_utc"] = now()
        report["artifact_sha256"] = {
            str(path.relative_to(destination)): digest(path)
            for path in sorted(destination.rglob("*")) if path.is_file()
            and path.name != "report.json" and "lib" not in path.relative_to(destination).parts}
        write_json(destination / "report.json", report)
    print(json.dumps({"accepted": report["accepted"], "checks_passed": report["checks_passed"],
                      "report": str(destination / "report.json")}, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--expected-revision", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--preflight", action="store_true", help="allow a working tree; never records acceptance")
    args = parser.parse_args()
    run_gate(args.expected_revision, args.output, args.preflight)
