"""Regression coverage for a lookup timeout during first simulator installation."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch

import diagnostic_head as h
import runner as r


class ReadyTests(unittest.TestCase):
    def setUp(self):
        self.process = Mock()
        self.process.poll.return_value = None

    def test_slow_install_then_fresh_handshake(self):
        with tempfile.TemporaryDirectory() as root:
            d = Path(root) / 'Documents'
            d.mkdir()
            (d / 'm1-ready.json').write_text(json.dumps({'nonce': 'fixture'}))
            with patch.object(r, 'container', side_effect=[r.CommandTimeout('installing'), None, d.parent]), patch.object(r.time, 'sleep'):
                self.assertEqual(r.wait_ready(self.process, 'udid', 'runner', 0), (d, {'nonce': 'fixture'}))

    def test_repeated_timeout_is_bounded(self):
        with patch.object(r, 'container', side_effect=r.CommandTimeout('installing')) as lookup, patch.object(r.time, 'monotonic', side_effect=[0, 1, 4, 6]), patch.object(r.time, 'sleep'):
            with self.assertRaisesRegex(r.Stop, '1 lookup timeouts'):
                r.wait_ready(self.process, 'udid', 'runner', 0, sec=5)
            self.assertEqual(lookup.call_args.kwargs['timeout'], 4)

    def test_exit_during_retry_fails(self):
        self.process.poll.side_effect = [None, 1]
        with patch.object(r, 'container', side_effect=r.CommandTimeout('installing')), patch.object(r.time, 'sleep'), self.assertRaisesRegex(r.Stop, 'exited before'):
            r.wait_ready(self.process, 'udid', 'runner', 0)

    def test_bad_container_is_not_retryable(self):
        with patch.object(r, 'container', side_effect=r.Stop('bad simulator container')), self.assertRaisesRegex(r.Stop, 'bad simulator container'):
            r.wait_ready(self.process, 'udid', 'runner', 0)

    def test_dispatch_contract(self):
        env = {'GITHUB_EVENT_NAME': 'workflow_dispatch', 'GITHUB_REF': h.BRANCH, 'GITHUB_SHA': 'tip'}
        args = ['tip', env, 'tip', [h.PARENT], list(h.FILES)]
        self.assertEqual(h.validate(*args), r.CAND)
        for pos, bad in ((0, 'stale'), (1, {**env, 'GITHUB_REF': 'refs/heads/main'}), (3, [r.CAND]), (4, [*h.FILES, 'App/Scene/BuildingScene.swift'])):
            altered = args.copy()
            altered[pos] = bad
            with self.subTest(pos=pos), self.assertRaises(ValueError):
                h.validate(*altered)


if __name__ == '__main__':
    unittest.main()
