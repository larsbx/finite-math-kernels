#!/usr/bin/env python3
"""Execute the literal Pixi task graph without environment activation hooks."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time
import tomllib

ROOT = Path(__file__).resolve().parents[1]
MOJO = Path('/workspace/scratch/gnr-next.qHyoM1/golden-ratio-normality-research/kernel/.pixi/envs/default/bin/mojo')
PYTHON = Path(sys.executable).resolve()
GATES = ['test', 'test-audit', 'test-provenance', 'references', 'property', 'test-polyglot']


def utc():
    return datetime.now(timezone.utc).isoformat()


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()


def main(expected, destination):
    destination = destination.resolve()
    destination.mkdir(parents=True, exist_ok=False)
    shutil.copy2(__file__, destination / 'run_repository_gates.py')
    config = tomllib.loads((ROOT / 'pixi.toml').read_text())
    tasks = config['tasks'] | config['feature']['polyglot']['tasks']
    env = dict(os.environ)
    env['PATH'] = str(MOJO.parent) + os.pathsep + os.environ.get('PATH', '')
    env['MODULAR_TELEMETRY_ENABLED'] = 'false'
    env['MODULAR_CRASH_REPORTING_ENABLED'] = 'false'
    env['MODULAR_HOME'] = str(MOJO.parent.parent / 'share/max')
    env['PIXI_PROJECT_ROOT'] = str(ROOT)
    env['ELIXIR_ERL_OPTIONS'] = '+fnu'
    env['FRONTIER_REQUIRE'] = 'mojo,rust,bend,julia'
    scratch = ROOT.parent / 'fmk-binary-weight-task-tmp'
    scratch.mkdir(exist_ok=True)
    status = git('status', '--porcelain')
    if git('rev-parse', 'HEAD') != expected or status:
        raise RuntimeError('exact clean revision required')
    report = {'schema': 'fmk-binary-weight-repository-gates-v1', 'source_commit': expected,
              'source_tree': git('rev-parse', 'HEAD^{tree}'), 'started_utc': utc(),
              'source_tree_dirty': False, 'python': str(PYTHON), 'python_version': sys.version,
              'mojo': str(MOJO), 'mojo_sha256': hashlib.sha256(MOJO.read_bytes()).hexdigest(),
              'telemetry': {k: env[k] for k in ['MODULAR_TELEMETRY_ENABLED', 'MODULAR_CRASH_REPORTING_ENABLED']},
              'MODULAR_HOME': env['MODULAR_HOME'], 'FRONTIER_REQUIRE': env['FRONTIER_REQUIRE'],
              'modular_cfg_sha256': hashlib.sha256((Path(env['MODULAR_HOME']) / 'modular.cfg').read_bytes()).hexdigest(),
              'mojo_version': subprocess.check_output([str(MOJO), '--version'], env=env, text=True).strip(),
              'temporary_directory_parent': str(scratch),
              'unavailable_tools': [x for x in ['bend', 'mix', 'elixir'] if not shutil.which(x, path=env['PATH'])],
              'TLA_TOOLS': env.get('TLA_TOOLS', ''),
              'task_graph_sha256': hashlib.sha256((ROOT / 'pixi.toml').read_bytes()).hexdigest(),
              'equivalence': 'Execute each declared task command once after dependencies, directly under explicit environment; replace only python/mojo executable names with shown absolute paths. No Pixi activation hooks or pixi run/shell. Run independent tasks despite other failures; blocked dependents and optional test skips retain their observed status.',
              'tasks': {}, 'gates': {}}

    def save():
        (destination / 'report.json').write_text(json.dumps(report, indent=2) + '\n')

    def run(name):
        if name in report['tasks']:
            return report['tasks'][name]['status'] == 'passed'
        task = tasks[name]
        if isinstance(task, str):
            task = {'cmd': task}
        dependencies = task.get('depends-on', [])
        results = [run(dep) for dep in dependencies]
        record = {'task': name, 'depends_on': dependencies, 'original_command': task.get('cmd'),
                  'cwd': str(ROOT / task.get('cwd', ''))}
        if not all(results):
            record.update(status='blocked', failed_dependencies=[d for d, passed in zip(dependencies, results) if not passed])
        elif 'cmd' not in task:
            record.update(status='passed', aggregate=True)
        else:
            command = re.sub(r'(?<![\w/-])python(?=\s)', str(PYTHON), task['cmd'])
            command = re.sub(r'(?<![\w/-])mojo(?=\s)', str(MOJO), command)
            record['executed_command'] = command
            record['timeout_seconds'] = 1800
            record['started_utc'] = utc()
            started = time.monotonic()
            print(name + ': running', flush=True)
            try:
                with tempfile.TemporaryDirectory(prefix='tmp-', dir=scratch) as tmp:
                    task_env = dict(env, TMPDIR=tmp)
                    with (destination / (name + '.log')).open('w') as log:
                        result = subprocess.run(['/bin/bash', '-c', command], cwd=record['cwd'],
                                                env=task_env, stdout=log, stderr=subprocess.STDOUT,
                                                timeout=1800)
                record['returncode'] = result.returncode
                record['status'] = 'passed' if result.returncode == 0 else 'failed'
            except subprocess.TimeoutExpired:
                record['status'] = 'failed'
                record['error'] = 'timeout'
            record['elapsed_seconds'] = time.monotonic() - started
            record['finished_utc'] = utc()
            print(name + ': ' + record['status'], flush=True)
        report['tasks'][name] = record
        save()
        return record['status'] == 'passed'

    try:
        for gate in GATES:
            report['gates'][gate] = 'passed' if run(gate) else 'failed'
            save()
        report['extra_provenance_check'] = subprocess.run([str(PYTHON), 'tools/provenance.py', '--check'], cwd=ROOT,
                                                         env=env, capture_output=True, text=True).__dict__
        report['source_unchanged'] = (git('rev-parse', 'HEAD') == expected and not git('status', '--porcelain'))
        report['all_repository_gates_passed'] = all(v == 'passed' for v in report['gates'].values()) and report['source_unchanged']
    finally:
        report['finished_utc'] = utc()
        report['artifact_sha256'] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                                     for p in sorted(destination.iterdir()) if p.suffix in {'.log', '.py'}}
        save()
    print(json.dumps({'gates': report['gates'], 'source_unchanged': report.get('source_unchanged'),
                      'report': str(destination / 'report.json')}, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--expected-revision', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    main(args.expected_revision, args.output)
