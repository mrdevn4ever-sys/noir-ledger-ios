#!/usr/bin/env python3
"""Check every idle/scroll comparison in a complete same-runner pacing log.

Usage: python scripts/qa/perf_gate.py LOG BASE_SHA CANDIDATE_SHA ROUNDS
Exit 0 only if each candidate median p95 and median hitch is no worse than base.
"""
import argparse
import itertools
import math
import re
from pathlib import Path
from statistics import median

SCENES = ('harbour', 'late', 'hot')
MODES = ('idle', 'scroll')
ROW = re.compile(r'\[([0-9a-f]{40}) r(\d+)\] PERF (\w+) (\w+): perf fps=([\d.]+) p95=([\d.]+)ms worst=([\d.]+)ms hitch=([\d.]+)ms/s dropped=(\d+) frames=(\d+)\s*$')


def check(log, base, candidate, rounds):
    if base == candidate or rounds < 1 or not all(re.fullmatch('[0-9a-f]{40}', sha) for sha in (base, candidate)):
        raise ValueError('two distinct full revisions and a positive round count are required')
    expected = set(itertools.product((base, candidate), range(1, rounds + 1), SCENES, MODES))
    samples = {}
    for line in log.splitlines():
        if not re.search(r'\[[0-9a-f]+ r\d+\] PERF ', line):
            continue
        match = ROW.search(line)
        if match is None:
            raise ValueError('unreadable PERF row: ' + line)
        sha, r, scene, mode, fps, p95, worst, hitch, dropped, frames = match.groups()
        key = (sha, int(r), scene, mode)
        if key in samples or key not in expected:
            raise ValueError(f'duplicate or unexpected PERF row: {key}')
        values = list(map(float, (fps, p95, worst, hitch)))
        if not all(math.isfinite(x) for x in values) or min(values[:3]) <= 0 or float(worst) < float(p95) or int(frames) < 11 or int(dropped) > int(frames):
            raise ValueError(f'invalid counters: {key}')
        samples[key] = (float(p95), float(hitch))
    if samples.keys() != expected:
        raise ValueError(f'missing PERF rows: {sorted(expected - samples.keys())}')
    report = []
    ok = True
    for scene, mode in itertools.product(SCENES, MODES):
        lines = [[median(samples[sha, r, scene, mode][k] for r in range(1, rounds + 1)) for k in range(2)] for sha in (base, candidate)]
        a, b = lines
        passed = all(after <= before for before, after in zip(a, b))
        report.append(f'{scene:7} {mode:6} p95 {a[0]:.2f} -> {b[0]:.2f} ms; hitch {a[1]:.2f} -> {b[1]:.2f} ms/s: {"pass" if passed else "regression"}')
        ok &= passed
    return ok, report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log', type=Path)
    parser.add_argument('base')
    parser.add_argument('candidate')
    parser.add_argument('rounds', type=int)
    args = parser.parse_args()
    success, rows = check(args.log.read_text(encoding='utf-8-sig'), args.base, args.candidate, args.rounds)
    print('\n'.join(rows))
    print('PERF_GATE_OK' if success else 'PERF_GATE_REGRESSION')
    raise SystemExit(0 if success else 1)
