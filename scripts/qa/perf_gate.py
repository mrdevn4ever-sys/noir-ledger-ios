#!/usr/bin/env python3
"""Median pacing gate. Supply ONE full same-run job log and its total round count.

For a historical arithmetic-mean report, use perf_gate_means.py instead.
"""
import argparse
from dataclasses import dataclass
from decimal import Decimal, localcontext
from fractions import Fraction
from itertools import product
from pathlib import Path
from statistics import median

import perf_gate_means as historical
from perf_gate_means import MODES, SCENES, crew_trial  # Historical replay API.

LIMIT = Fraction(23, 20)
METRICS = ('dropped', 'hitch')


@dataclass(frozen=True)
class Comparison:
    scene: str
    mode: str
    metric: str
    base: Fraction
    candidate: Fraction
    control: Fraction | None

    @property
    def passed(self):
        # No division by the baseline (including zero); no rounding.
        return self.candidate <= LIMIT * self.base


def comparisons(log, base, candidate, rounds, control=None):
    if base != historical.BASELINE:
        raise ValueError(f'the required same-run baseline is {historical.BASELINE}')
    if rounds < 3:
        raise ValueError('the median gate requires at least three complete rounds')
    revisions = (base, candidate) if control is None else (base, candidate, control)
    # Validate the entire log, including an optional non-deciding control, first.
    samples = historical._measurements(log, revisions, rounds)
    rows = []
    for scene, mode, metric in product(historical.SCENES, historical.MODES, METRICS):
        def middle(sha):
            # Cast integer counts too: statistics.median of two ints uses float.
            return median(Fraction(getattr(samples[sha, r, scene, mode], metric))
                          for r in range(1, rounds + 1))
        rows.append(Comparison(scene, mode, metric, middle(base), middle(candidate),
                               None if control is None else middle(control)))
    return rows


def exact(value):
    """Exact decimal for terminating fractions from logged decimals and half-sums."""
    with localcontext() as ctx:
        # For denominator 2^a * 5^b, the decimal scale is at most its bit length.
        ctx.prec = len(str(abs(value.numerator))) + value.denominator.bit_length()
        return format(Decimal(value.numerator) / Decimal(value.denominator), 'f')


def check(log, base, candidate, rounds, control=None):
    rows = comparisons(log, base, candidate, rounds, control)
    count = rounds * len(historical.SCENES) * len(historical.MODES) * (2 + (control is not None))
    report = [f'{count} validated measurements; {rounds} rounds; median dropped (frames) '
              'and median hitch (ms/s), limit 115% of same-run baseline']
    for v in rows:
        info = '' if v.control is None else f'; control={exact(v.control)} (info only)'
        report.append(f'{v.scene} {v.mode} {v.metric}: base={exact(v.base)} '
                      f'candidate={exact(v.candidate)} limit={exact(LIMIT * v.base)} '
                      f'{"PASS" if v.passed else "FAIL"}{info}')
    return all(v.passed for v in rows), report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log', type=Path)
    parser.add_argument('base')
    parser.add_argument('candidate')
    parser.add_argument('rounds', type=int, help='total rounds in the run, not a subset')
    parser.add_argument('--crew-control', metavar='SHA', help='validate and report this control; never use it as baseline')
    args = parser.parse_args(argv)
    try:
        ok, report = check(args.log.read_text(encoding='utf-8-sig'), args.base, args.candidate,
                           args.rounds, args.crew_control)
    except (ValueError, OSError) as exc:
        parser.error(str(exc))
    print('\n'.join(report))
    print('PERF_MEDIAN_GATE_OK' if ok else 'PERF_MEDIAN_GATE_REGRESSION')
    return 0 if ok else 1


if __name__ == '__main__':
    raise SystemExit(main())
