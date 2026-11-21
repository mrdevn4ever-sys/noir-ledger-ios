#!/usr/bin/env python3
"""Check every idle/scroll comparison in a complete same-runner pacing log.

Usage: python scripts/qa/perf_gate.py LOG BASE_SHA CANDIDATE_SHA ROUNDS [--crew-control SHA]
Use full revisions and at least three complete rounds. Each candidate mean
(dropped frames, hitch ms/s) must be <= 115% of the same-run 1d69565 mean.
An optional third revision is validated and reported but never sets the limit.
"""
import argparse
import itertools
import re
from collections import namedtuple
from decimal import Decimal
from fractions import Fraction
from pathlib import Path

BASELINE = '1d695653c3929c236c74b9d6bd192593d338ef52'
SCENES = ('harbour', 'late', 'hot')
MODES = ('idle', 'scroll')
NUMBER = r'(\d+(?:\.\d+)?)'
ROW = re.compile(r'\[([0-9a-f]{40}) r(\d+)\] PERF (\w+) (\w+): perf '
                 rf'fps={NUMBER} p95={NUMBER}ms worst={NUMBER}ms hitch={NUMBER}ms/s '
                 r'dropped=(\d+) frames=(\d+)\s*$')
ROW_MARKER = re.compile(r'\]\s*PERF\b|\bPERF\s+\w+\s+\w+:\s*perf\b')
Sample = namedtuple('Sample', 'p95 hitch dropped')


def _measurements(log, revisions, rounds):
    if len(set(revisions)) != len(revisions) or rounds < 1 or not all(re.fullmatch('[0-9a-f]{40}', s) for s in revisions):
        raise ValueError('distinct full revisions and a positive round count are required')
    if re.search(r'test run [0-9a-f]{40} round \d+ failed', log):
        raise ValueError('a measurement test failed')
    # Row-only logs are supported. If the workflow declares its matrix,
    # do not accept a truncated log as a smaller, seemingly complete trial.
    for count in re.findall(r'\bROUNDS:\s*(\d+)\s*$', log, re.MULTILINE):
        if int(count) != rounds:
            raise ValueError('round count disagrees with the workflow log')
    for commits in re.findall(r'\bCOMMITS:[ \t]*([^\r\n]*)\r?$', log, re.MULTILINE):
        if sorted(commits.split()) != sorted(revisions):
            raise ValueError('revisions disagree with the workflow log')
    expected = set(itertools.product(revisions, range(1, rounds + 1), SCENES, MODES))
    samples = {}
    for line in log.splitlines():
        if not ROW_MARKER.search(line):
            continue
        match = ROW.search(line)
        if match is None:
            raise ValueError('unreadable PERF row: ' + line)
        sha, r, scene, mode, fps, p95, worst, hitch, dropped, frames = match.groups()
        key = (sha, int(r), scene, mode)
        if key in samples or key not in expected:
            raise ValueError(f'duplicate or unexpected PERF row: {key}')
        fps, p95, worst, hitch = map(Fraction, (fps, p95, worst, hitch))
        dropped, frames = int(dropped), int(frames)
        if fps <= 0 or p95 <= 0 or worst < p95 or frames < 11 or dropped > frames:
            raise ValueError(f'invalid counters: {key}')
        samples[key] = Sample(p95, hitch, dropped)
    if samples.keys() != expected:
        raise ValueError(f'missing PERF rows: {sorted(expected - samples.keys())}')
    return samples


def matrix(log, revisions, rounds):
    """Historical (p95, hitch) view used by crew_trial."""
    return {key: (float(sample.p95), float(sample.hitch))
            for key, sample in _measurements(log, revisions, rounds).items()}


def _display(value):
    return f'{Decimal(value.numerator) / Decimal(value.denominator):.2f}'


def check(log, base, candidate, rounds, control=None):
    if base != BASELINE:
        raise ValueError(f'the required same-run baseline is {BASELINE}')
    if rounds < 3:
        raise ValueError('the mean gate requires at least three complete rounds')
    revisions = (base, candidate) if control is None else (base, candidate, control)
    samples = _measurements(log, revisions, rounds)
    report = [f'{len(samples)} validated measurements; {rounds} rounds; '
              'mean dropped (frames) and mean hitch (ms/s), limit 115% of baseline']
    ok = True
    for scene, mode, metric in itertools.product(SCENES, MODES, ('dropped', 'hitch')):
        means = {sha: Fraction(sum(getattr(samples[sha, r, scene, mode], metric)
                                   for r in range(1, rounds + 1)), rounds) for sha in revisions}
        before, after = means[base], means[candidate]
        # No rounding or division by the baseline: 0 -> 0 passes; 0 -> positive fails.
        passed = 100 * after <= 115 * before
        ratio = f'{_display(100 * after / before)}% of base' if before else 'ratio n/a: zero baseline'
        info = '' if control is None else f'; control={_display(means[control])} (info only)'
        report.append(f'{scene} {mode} {metric}: base={_display(before)} candidate={_display(after)} '
                      f'({ratio}) {"PASS" if passed else "FAIL"}{info}')
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


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log', type=Path)
    parser.add_argument('base')
    parser.add_argument('candidate')
    parser.add_argument('rounds', type=int)
    parser.add_argument('--crew-control', metavar='SHA', help='Include this non-deciding control revision')
    args = parser.parse_args(argv)
    try:
        log = args.log.read_text(encoding='utf-8-sig')
        success, rows = check(log, args.base, args.candidate, args.rounds, args.crew_control)
    except (OSError, ValueError) as exc:
        parser.error(str(exc))
    print('\n'.join(rows))
    print('PERF_GATE_OK' if success else 'PERF_GATE_REGRESSION')
    return 0 if success else 1


if __name__ == '__main__':
    raise SystemExit(main())
