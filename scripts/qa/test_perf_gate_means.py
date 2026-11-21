import contextlib
import io
import itertools
import unittest
from unittest.mock import patch

import perf_gate_means as gate

BASE = '1d695653c3929c236c74b9d6bd192593d338ef52'
NEW, CONTROL = 'b' * 40, 'c' * 40
CELLS = tuple(itertools.product(('harbour', 'late', 'hot'), ('idle', 'scroll')))


def log_for(rounds=3, control=False, change=None):
    lines = []
    for r in range(1, rounds + 1):
        for sha in ((BASE, CONTROL, NEW) if control else (BASE, NEW)):
            for scene, mode in CELLS:
                fields = dict(fps=60, p95=20, worst=80, hitch='2.0', dropped=20, frames=150)
                if change:
                    fields.update(change(sha, r, scene, mode) or {})
                lines.append(f'[{sha} r{r}] PERF {scene} {mode}: perf ' +
                             'fps={fps} p95={p95}ms worst={worst}ms hitch={hitch}ms/s '
                             'dropped={dropped} frames={frames}'.format(**fields))
    return '\n'.join(lines)


class MeanGateTests(unittest.TestCase):
    def test_exact_boundary_and_just_over_for_each_metric(self):
        # 2.3 is exactly 115% of 2.0; do not first round to a display value or float.
        for dropped, hitch, expected in ((23, '2.3', True), (24, '2.3', False),
                                         (23, '2.30000000000000000000000000001', False)):
            with self.subTest(dropped=dropped, hitch=hitch):
                log = log_for(change=lambda s, *_: dict(dropped=dropped, hitch=hitch) if s == NEW else {})
                self.assertEqual(gate.check(log, BASE, NEW, 3)[0], expected)

    def test_zero_baseline_only_allows_zero_for_that_metric(self):
        for d, h, expected in ((0, '0', True), (1, '0', False), (0, '0.00000001', False)):
            with self.subTest(dropped=d, hitch=h):
                log = log_for(change=lambda s, r, *_: dict(dropped=d, hitch=h) if (s, r) == (NEW, 3)
                              else dict(dropped=0, hitch='0'))
                self.assertEqual(gate.check(log, BASE, NEW, 3)[0], expected)

    def test_every_cell_and_metric_decides_and_report_does_not_short_circuit(self):
        for cell, field in itertools.product(CELLS, ('dropped', 'hitch')):
            with self.subTest(cell=cell, field=field):
                log = log_for(change=lambda s, r, sc, m: {field: 80} if (sc, m) == cell and s == NEW else {})
                ok, rows = gate.check(log, BASE, NEW, 3)
                self.assertFalse(ok)
                failures = [line for line in rows if 'FAIL' in line]
                self.assertEqual(len(failures), 1)
                self.assertIn(' '.join((*cell, field)), failures[0])
                self.assertEqual(sum('PASS' in line for line in rows), 11)

    def test_all_rounds_including_outliers_count_in_the_arithmetic_mean(self):
        # Median, 3-of-4 wins, truncation to three rounds, and p95 would all pass.
        log = log_for(4, change=lambda s, r, *_: dict(dropped=40) if (s, r) == (NEW, 4) else {})
        self.assertFalse(gate.check(log, BASE, NEW, 4)[0])

    def test_ratio_of_means_not_mean_of_paired_ratios_or_frame_weighting(self):
        # The same three counts in a different order must tie; base r1 is zero.
        def change(s, r, *_):
            n = ((0, 10, 90) if s == BASE else (90, 10, 0))[r-1]
            return dict(dropped=n, hitch=n, frames=1000 if (s, r) == (NEW, 1) else 150)
        self.assertTrue(gate.check(log_for(change=change), BASE, NEW, 3)[0])

    def test_rejects_wrong_baseline_aliased_revisions_and_under_three_rounds(self):
        log = log_for(control=True)
        for b, c, ctrl in ((CONTROL, NEW, BASE), (BASE, BASE, CONTROL), (BASE, NEW, NEW),
                           (BASE[:7], NEW, CONTROL), (BASE, NEW[:7], CONTROL)):
            with self.subTest(b=b, c=c, ctrl=ctrl), self.assertRaises(ValueError):
                gate.check(log, b, c, 3, ctrl)
        with self.assertRaises(ValueError):
            gate.check(log_for(2), BASE, NEW, 2)

    def test_validates_the_entire_declared_matrix_including_control(self):
        log = log_for(control=True)
        ctl = next(line for line in log.splitlines() if CONTROL in line)
        for bad in ('', ctl + '\n' + ctl, ctl.replace('harbour', 'other'), ctl.replace('idle', 'pan'),
                    ctl.replace('r1]', 'r4]'), ctl.replace(CONTROL, 'd' * 40),
                    ctl.replace('frames=150', 'frames=10'), ctl.replace('dropped=20', 'dropped=151'),
                    ctl.replace('fps=60', 'fps=0'), ctl.replace('p95=20', 'p95=0'),
                    ctl.replace('worst=80', 'worst=19'), ctl.replace('hitch=2.0', 'hitch=-0.1'),
                    ctl.replace('hitch=2.0', 'hitch=NaN'), ctl.replace('dropped=20', 'dropped=2.5'),
                    ctl + f'\ntest run {CONTROL} round 1 failed', ctl + '\n' + ctl.replace(CONTROL, 'bad-sha')):
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                gate.check(log.replace(ctl, bad, 1), BASE, NEW, 3, CONTROL)
        with self.assertRaises(ValueError):  # Cannot silently drop the third revision.
            gate.check(log, BASE, NEW, 3)
        with self.assertRaises(ValueError):
            gate.check(log_for(), BASE, NEW, 3, CONTROL)

    def test_declared_rounds_and_commits_cannot_be_truncated_away(self):
        log = log_for().replace('\n', '\r\n')
        for header in ('ROUNDS: 4', f'COMMITS: {BASE} {CONTROL} {NEW}'):
            with self.subTest(header=header), self.assertRaises(ValueError):
                gate.check(header + '\r\n' + log, BASE, NEW, 3)

    def test_cli_uses_means_with_and_without_control(self):
        for rounds, control, regression in itertools.product((3, 4), (False, True), (False, True)):
            def change(s, r, scene, mode):
                if s == CONTROL:
                    return dict(dropped=0, hitch='0') if not regression else dict(dropped=150, hitch=900)
                if s == NEW:
                    # Old p95 rule gives the opposite verdict to the means in both trials.
                    return dict(p95=10 if regression else 40,
                                hitch=10 if regression and (scene, mode) == ('hot', 'scroll') else 2)
            log = log_for(rounds, control, change)
            argv = ['input.log', BASE, NEW, str(rounds)] + (['--crew-control', CONTROL] if control else [])
            out = io.StringIO()
            with self.subTest(control=control, regression=regression), patch.object(gate.Path, 'read_text', return_value=log), contextlib.redirect_stdout(out):
                self.assertEqual(gate.main(argv), int(regression))
                self.assertIn('PERF_GATE_REGRESSION' if regression else 'PERF_GATE_OK', out.getvalue())
                self.assertEqual('control=' in out.getvalue(), control)


if __name__ == '__main__':
    unittest.main()
