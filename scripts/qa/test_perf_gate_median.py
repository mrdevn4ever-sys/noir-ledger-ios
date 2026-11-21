import contextlib
import io
import itertools
import unittest
from fractions import Fraction as F
from unittest.mock import patch

import perf_gate_means as historical
import perf_gate as gate
from test_perf_gate_means import BASE, NEW, CONTROL, CELLS, log_for


class MedianGateTests(unittest.TestCase):
    def test_median_is_not_mean_or_worst(self):
        # Opposite historical and future verdicts in both directions.
        for counts, ok in [((100, 20, 20), True), ((0, 24, 24), False)]:
            with self.subTest(counts=counts):
                log = log_for(change=lambda s, r, *_: {'dropped': counts[r-1]} if s == NEW else {})
                self.assertEqual(gate.check(log, BASE, NEW, 3)[0], ok)
                self.assertNotEqual(historical.check(log, BASE, NEW, 3)[0], ok)

    def test_even_n_is_midpoint_for_both_metrics_in_each_revision(self):
        # Middle-two midpoint is neither observed value. Different round orders per metric.
        def change(s, r, *_):
            delta = int(s == NEW)
            return dict(dropped=(8, 4, 7, 1)[r-1] + delta,
                        hitch=('1', '2.52', '2.53', '99')[r-1] if s == NEW else ('2.56', '1', '8', '2.55')[r-1])
        rows = gate.comparisons(log_for(4, change=change), BASE, NEW, 4)
        self.assertEqual({(v.metric, v.base, v.candidate) for v in rows},
                         {('dropped', F('5.5'), F('6.5')), ('hitch', F('2.555'), F('2.525'))})

    def test_even_integer_median_exact_beyond_float_precision(self):
        k = 2**53
        log = log_for(4, change=lambda s, r, *_: dict(dropped=k+r, frames=2*k))
        self.assertEqual(gate.comparisons(log, BASE, NEW, 4)[0].base, F(2*k+5, 2))

    def test_all_rounds_including_beyond_three_change_verdict(self):
        def change(s, r, *_):
            return {'dropped': (20, 40, 20, 40, 40)[r-1]} if s == NEW else {}
        self.assertTrue(gate.check(log_for(3, change=change), BASE, NEW, 3)[0])
        for n in (4, 5):
            log = log_for(n, change=change)
            with self.subTest(n=n):
                self.assertFalse(gate.check(log, BASE, NEW, n)[0])
                with self.assertRaises(ValueError):
                    gate.check(log, BASE, NEW, 3)

    def test_each_metric_has_its_own_inclusive_exact_limit(self):
        for d, h, expected in ((23, '2.3', True), (24, '2.3', False), (23, '2.300000000000000000000000000001', False)):
            with self.subTest(d=d, h=h):
                log = log_for(4, change=lambda s, *_: dict(dropped=d, hitch=h) if s == NEW else {})
                self.assertEqual(gate.check(log, BASE, NEW, 4)[0], expected)

    def test_zero_applies_to_median_not_every_round(self):
        for ds, hs, ok in [((0, 9, 0), ('6', '0', '0'), True),
                           ((1, 0, 1), ('0',)*3, False), ((0,)*3, ('0', '0.00001', '1'), False)]:
            with self.subTest(ds=ds, hs=hs):
                log = log_for(change=lambda s, r, *_: dict(dropped=ds[r-1], hitch=hs[r-1]) if s == NEW
                              else dict(dropped=0, hitch=0))
                self.assertEqual(gate.check(log, BASE, NEW, 3)[0], ok)

    def test_not_round_ratios_not_frame_weighted_and_not_p95(self):
        def change(s, r, *_):
            n = ((1, 10, 100) if s == BASE else (10, 100, 1))[r-1]
            return dict(dropped=n, hitch=n, frames=2000 if s == NEW and r == 2 else 150,
                        p95=20 if s == BASE else 80)
        rows = gate.comparisons(log_for(change=change), BASE, NEW, 3)
        self.assertTrue(all(v.base == v.candidate == 10 and v.passed for v in rows))

    def test_all_twelve_decisions_independent_with_and_without_control(self):
        for (sc, mo), metric, ctl in itertools.product(CELLS, ('dropped', 'hitch'), (False, True)):
            def change(s, r, scene, mode):
                if s == CONTROL:
                    return dict(dropped=150, hitch=900)
                if (s, scene, mode) == (NEW, sc, mo):
                    return {metric: 80}
            with self.subTest(sc=sc, mo=mo, metric=metric, ctl=ctl):
                ok, report = gate.check(log_for(control=ctl, change=change), BASE, NEW, 3, CONTROL if ctl else None)
                self.assertFalse(ok)
                self.assertEqual(len(report), 13)
                self.assertEqual([x.split(':')[0] for x in report if 'FAIL' in x], [f'{sc} {mo} {metric}'])
                self.assertEqual(sum('PASS' in x for x in report), 11)

    def test_entire_declared_trial_required(self):
        log = log_for(control=True)
        ctl = next(line for line in log.splitlines() if CONTROL in line)
        for replacement in ('', ctl+'\n'+ctl, ctl.replace('r1]', 'r4]'), ctl.replace('idle:', 'pan:'),
                            ctl.replace('2.0ms/s', 'nanms/s'), ctl.replace('frames=150', 'frames=10'),
                            ctl+f'\ntest run {CONTROL} round 2 failed'):
            with self.subTest(replacement=replacement), self.assertRaises(ValueError):
                gate.check(log.replace(ctl, replacement, 1), BASE, NEW, 3, CONTROL)
        for header in ('ROUNDS: 4', f'COMMITS: {BASE} {NEW}'):
            with self.subTest(header=header), self.assertRaises(ValueError):
                gate.check(header+'\n'+log, BASE, NEW, 3, CONTROL)
        for args in ((log_for(2), BASE, NEW, 2), (log, CONTROL, NEW, 3, BASE), (log, BASE, NEW, 3),
                     (log, BASE, NEW[:7], 3, CONTROL), (log, BASE, NEW, 3, NEW)):
            with self.assertRaises(ValueError):
                gate.check(*args)

    def test_cli_decides_on_medians_or_reports_invalid_input(self):
        for ctl, n, code in itertools.product((False, True), (3, 4), (0, 1, 2)):
            def change(s, r, *_):
                if s == NEW:
                    return dict(hitch=(10 if code == 1 or r == 1 else 2))
                if s == CONTROL:
                    return dict(hitch=0)
            log = log_for(n, ctl, change)
            if code == 2:
                log = log[:log.rfind('\n')]
            argv = ['input.log', BASE, NEW, str(n)] + (['--crew-control', CONTROL] if ctl else [])
            out = io.StringIO()
            with self.subTest(ctl=ctl, n=n, code=code), patch.object(gate.Path, 'read_text', return_value=log), contextlib.redirect_stdout(out):
                if code == 2:
                    with contextlib.redirect_stderr(out), self.assertRaises(SystemExit) as err:
                        gate.main(argv)
                    self.assertEqual(err.exception.code, 2)
                else:
                    self.assertEqual(gate.main(argv), code)
                    self.assertIn('PERF_MEDIAN_GATE_REGRESSION' if code else 'PERF_MEDIAN_GATE_OK', out.getvalue())
                    self.assertEqual('control=' in out.getvalue(), ctl)


if __name__ == '__main__':
    unittest.main()
