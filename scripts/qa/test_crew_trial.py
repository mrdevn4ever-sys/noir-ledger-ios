import itertools
import unittest
from perf_gate import MODES, SCENES, crew_trial

BASE, CONTROL, NEW = (c * 40 for c in 'abc')


def rows(harbour, late):
    out = []
    for sha, r, scene, mode in itertools.product((BASE, CONTROL, NEW), (1, 2, 3), SCENES, MODES):
        p = (20, 30, 10)[r - 1]
        if sha == CONTROL:
            p = 5  # The intermediate build must not become the baseline.
        elif sha == NEW and mode == 'idle' and scene in ('harbour', 'late'):
            p = (harbour if scene == 'harbour' else late)[r - 1]
        out.append(f'[{sha} r{r}] PERF {scene} {mode}: perf fps=60 p95={p}ms worst=60ms hitch=10ms/s dropped=1 frames=60')
    return out


class CrewTrialTests(unittest.TestCase):
    def test_rounds_are_paired_and_equality_counts(self):
        good = rows((20, 30, 11), (21, 30, 10))
        self.assertTrue(crew_trial('\n'.join(good), BASE, CONTROL, NEW)[0])
        # Median 20 in both builds, but the candidate loses r1 and r3 in the harbour.
        bad = rows((21, 10, 20), (20, 30, 10))
        self.assertFalse(crew_trial('\n'.join(bad), BASE, CONTROL, NEW)[0])
        self.assertFalse(crew_trial('\n'.join(rows((20, 30, 10), (21, 10, 20))), BASE, CONTROL, NEW)[0])

    def test_incomplete_duplicate_unexpected_and_failed_runs_do_not_pass(self):
        clean = rows((20, 30, 10), (20, 30, 10))
        for invalid in (clean[:-1], clean + clean[-1:], clean + [clean[0].replace(BASE, 'd' * 40)],
                        clean + [f'test run {CONTROL} round 2 failed']):
            with self.subTest(last=invalid[-1]), self.assertRaises(ValueError):
                crew_trial('\n'.join(invalid), BASE, CONTROL, NEW)


if __name__ == '__main__':
    unittest.main()
