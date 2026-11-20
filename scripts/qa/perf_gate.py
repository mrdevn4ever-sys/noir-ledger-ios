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


def matrix(log, revisions, rounds):
    if len(set(revisions)) != len(revisions) or rounds < 1 or not all(re.fullmatch('[0-9a-f]{40}', s) for s in revisions):
        raise ValueError('distinct full revisions and a positive round count are required')
    if re.search(r'test run [0-9a-f]{40} round \d+ failed', log):
        raise ValueError('a measurement test failed')
    expected = set(itertools.product(revisions, range(1, rounds + 1), SCENES, MODES))
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
    return samples


def check(log, base, candidate, rounds):
    samples = matrix(log, (base, candidate), rounds)
    report = []
    ok = True
    for scene, mode in itertools.product(SCENES, MODES):
        lines = [[median(samples[sha, r, scene, mode][k] for r in range(1, rounds + 1)) for k in range(2)] for sha in (base, candidate)]
        a, b = lines
        passed = all(after <= before for before, after in zip(a, b))
        report.append(f'{scene:7} {mode:6} p95 {a[0]:.2f} -> {b[0]:.2f} ms; hitch {a[1]:.2f} -> {b[1]:.2f} ms/s: {"pass" if passed else "regression"}')
        ok &= passed
    return ok, report


def crew_trial(log, base, control, candidate):
    """Paired p95 within the same round, not a comparison of independently sorted medians."""
    revs = (base, control, candidate)
    samples = matrix(log, revs, 3)
    passed, report = True, ['round values: base / control / candidate']
    for scene, mode in itertools.product(SCENES, MODES):
        hits = 0
        for r in (1, 2, 3):
            p95, hitch = zip(*(samples[s, r, scene, mode] for s in revs))
            hits += p95[2] <= p95[0]
            report.append(f'{scene} {mode} r{r}: p95 {p95} ms; hitch {hitch} ms/s')
        if mode == 'idle' and scene in ('harbour', 'late'):
            report.append(f'{scene} idle paired p95: {hits}/3')
            passed &= hits >= 2
    return passed, report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log', type=Path)
    parser.add_argument('base')
    parser.add_argument('candidate')
    parser.add_argument('rounds', type=int)
    parser.add_argument('--crew-control', help='Run the three-round M1 paired idle trial with this intermediate revision')
    args = parser.parse_args()
    log = args.log.read_text(encoding='utf-8-sig')
    if args.crew_control:
        if args.rounds != 3:
            parser.error('the crew trial requires exactly three rounds')
        success, rows = crew_trial(log, args.base, args.crew_control, args.candidate)
    else:
        success, rows = check(log, args.base, args.candidate, args.rounds)
    print('\n'.join(rows))
    print('PERF_GATE_OK' if success else 'PERF_GATE_REGRESSION')
    raise SystemExit(0 if success else 1)
