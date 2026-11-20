#!/usr/bin/env python3
"""Resolve a real SE-sized simulator on the primary runtime; verify the compact purchase evidence."""
import json
from pathlib import Path
import struct
import subprocess
import sys

MODEL = 'iPhone SE (3rd generation)'
SIZE = (750, 1334)
VIEWS = ('19_large_estate', '20_large_heirlooms', '21_large_van_offer', '21b_large_street_prices',
         '22_large_van_confirm', '23_large_van_bought')


def sim(*args):
    return subprocess.check_output(['xcrun', 'simctl', *args], text=True).strip()


def compact_device(primary):
    devices = json.loads(sim('list', 'devices', 'available', '-j'))['devices']
    runtime, = [r for r, ds in devices.items() if any(d['udid'] == primary for d in ds)]
    models = json.loads(sim('list', 'devicetypes', '-j'))['devicetypes']
    device_type, = [t['identifier'] for t in models if t['name'] == MODEL]
    # Device names alone are not authoritative: custom names can be assigned to any type.
    ids = [d['udid'] for d in devices[runtime] if d.get('deviceTypeIdentifier') == device_type]
    return ids[0] if ids else sim('create', MODEL, device_type, runtime)


def verify(out):
    summary = json.loads((out / 'test-summary.json').read_text())
    if not (summary.get('result') == 'Passed' and summary.get('passedTests') == 2
            and summary.get('failedTests') == 0 and summary.get('skippedTests') == 0):
        raise ValueError('compact DE/EN XCTest results incomplete')
    names = [d['device']['modelName'] for d in summary['devicesAndConfigurations']]
    if names != [MODEL]:
        raise ValueError(f'incorrect compact device: {names}')
    for locale in ('de', 'en'):
        for view in VIEWS:
            p = out / 'screenshots' / f'{locale}_tour_{view}.png'
            with p.open('rb') as f:
                header = f.read(24)
            if header[:8] != b'\x89PNG\r\n\x1a\n' or header[12:16] != b'IHDR' or struct.unpack('>II', header[16:24]) != SIZE:
                raise ValueError(f'incorrect capture: {p.name}')
    print(f'COMPACT_CAPTURE_OK {MODEL} {SIZE[0]}x{SIZE[1]} DE/EN; visual review still required')


if __name__ == '__main__':
    if len(sys.argv) != 3 or sys.argv[1] not in ('device', 'verify'):
        sys.exit('usage: compact_street.py device PRIMARY_UDID | verify EVIDENCE_DIR')
    if sys.argv[1] == 'device':
        print(compact_device(sys.argv[2]))
    else:
        verify(Path(sys.argv[2]))
