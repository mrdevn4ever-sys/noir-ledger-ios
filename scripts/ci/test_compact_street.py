import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch

import compact_street as compact


class CompactStreetTests(unittest.TestCase):
    def test_exact_type_on_primary_runtime(self):
        devices = {'devices': {'ios-test': [{'udid': 'main', 'deviceTypeIdentifier': 'standard'},
                                            {'udid': 'wrong', 'name': compact.MODEL, 'deviceTypeIdentifier': 'standard'},
                                            {'udid': 'correct', 'deviceTypeIdentifier': 'compact'}]}}
        models = {'devicetypes': [{'name': compact.MODEL, 'identifier': 'compact'}]}
        with patch.object(compact, 'sim', side_effect=[json.dumps(devices), json.dumps(models)]):
            self.assertEqual(compact.compact_device('main'), 'correct')

    def test_capture_matrix_checks_both_languages_and_device(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / 'screenshots').mkdir()
            summary = {'result': 'Passed', 'passedTests': 2, 'failedTests': 0, 'skippedTests': 0,
                       'devicesAndConfigurations': [{'device': {'modelName': compact.MODEL}}]}
            (root / 'test-summary.json').write_text(json.dumps(summary))
            # Just the fields inspected by the header gate, not simulated app evidence.
            header = b'\x89PNG\r\n\x1a\n' + struct.pack('>I', 13) + b'IHDR' + struct.pack('>II', *compact.SIZE)
            for lang in ('de', 'en'):
                for state in compact.VIEWS:
                    p = root / 'screenshots' / f'{lang}_tour_{state}.png'
                    p.write_bytes(header)
            compact.verify(root)
            p.write_bytes(header[:16] + struct.pack('>II', 1206, 2622))
            with self.assertRaises(ValueError):
                compact.verify(root)
            p.unlink()
            with self.assertRaises(FileNotFoundError):
                compact.verify(root)
            p.write_bytes(header)
            summary['devicesAndConfigurations'][0]['device']['modelName'] = 'iPhone 17'
            (root / 'test-summary.json').write_text(json.dumps(summary))
            with self.assertRaises(ValueError):
                compact.verify(root)


if __name__ == '__main__':
    unittest.main()
