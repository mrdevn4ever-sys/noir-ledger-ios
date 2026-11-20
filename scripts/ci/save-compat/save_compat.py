"""Cross-version save check. CI must have the pinned commit and a Swift 6 compiler.

Reads only the checkout. Builds two independent executables into a temp dir:
old code writes genuine schema-one saves; candidate loads and resaves them.
Never use user saves or a real wall clock. Use --check-local on a non-Mac to
check provenance, both source inventories and the comparator (not migration).
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tarfile
import tempfile

BASE = '1d695653c3929c236c74b9d6bd192593d338ef52'
SRC = 'Packages/NoirCore/Sources/NoirCore'
CASES = ('unopened', 'working', 'unattended')


def unchanged(old, new, path='state'):
    if isinstance(old, dict):
        if not isinstance(new, dict):
            raise ValueError(f'{path}: not an object')
        for key, val in old.items():
            if (path, key) == ('state', 'version'):
                continue
            if key not in new:
                raise ValueError(f'{path}.{key}: missing')
            unchanged(val, new[key], f'{path}.{key}')
    elif isinstance(old, list):
        if not isinstance(new, list) or len(old) != len(new):
            raise ValueError(f'{path}: list changed length or type')
        for i, (a, b) in enumerate(zip(old, new)):
            unchanged(a, b, f'{path}[{i}]')
    elif old != new or isinstance(old, bool) != isinstance(new, bool):
        raise ValueError(f'{path}: {old!r} became {new!r}')


def verify(case, before, after):
    old, new = json.loads(before), json.loads(after)
    assert old['schema'] == old['state']['version'] == 1
    assert old['savedAt'] == new['savedAt']
    assert new['schema'] == new['state']['version'] >= 1
    unchanged(old['state'], new['state'])
    if new['schema'] >= 2:
        assert new['state']['estate'] == ('WAITING' if case == 'unopened' else 'NOT_OFFERED'), case
    if case != 'unopened':
        s = old['state']
        assert s['meta']['favors'] == 73 and s['meta']['premium'] and s['meta']['noAds']
        assert s['ledger'] and s['dispatcher'] and s['workshops']['WEED']['lead']
        if case == 'working':
            assert s['trip'] and s['orders']
        if case == 'unattended':
            assert s['welcome']['credited'] > 0


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--repo', type=Path, default=Path.cwd())
    ap.add_argument('--check-local', action='store_true')
    args = ap.parse_args()
    repo = args.repo.resolve()
    def git(*argv):
        return subprocess.check_output(['git', '-C', str(repo), *argv])
    assert git('rev-parse', BASE + '^{commit}').decode().strip() == BASE
    data = git('archive', '--format=tar', BASE, SRC)
    probe = Path(__file__).with_name('SchemaOneProbe.swift')
    with tempfile.TemporaryDirectory(prefix='noir-cross-version-') as td:
        root = Path(td)
        old = root / 'old-source'
        with tarfile.open(fileobj=io.BytesIO(data), mode='r:') as tf:
            for m in tf:
                if m.isfile() and m.name.startswith(SRC + '/') and m.name.endswith('.swift'):
                    dest = old / Path(m.name).relative_to(SRC)
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    dest.write_bytes(tf.extractfile(m).read())
        trees = (sorted(old.rglob('*.swift')), sorted((repo / SRC).rglob('*.swift')))
        assert all(trees) and probe.is_file()
        print(f'SAVE_SOURCES old={BASE} candidate={git("rev-parse", "HEAD").decode().strip()} files={[len(t) for t in trees]}')
        if args.check_local:
            for key in ('favors', 'stock', 'deadline'):
                try:
                    unchanged({key: 77}, {key: 0})
                except ValueError:
                    pass
                else:
                    raise AssertionError(f'comparator missed {key} loss')
            print('SAVE_PREFLIGHT_OK (no Swift executed)')
            return
        originals = {}
        for phase, files in zip(('produce', 'consume'), trees):
            exe = root / phase
            subprocess.run(['swiftc', '-swift-version', '6', '-parse-as-library', '-module-name', 'NoirCore', *map(str, files), str(probe), '-o', str(exe)], check=True)
            subprocess.run([str(exe), phase, str(root / 'saves')], check=True)
            for case in CASES:
                folder = root / 'saves' / case
                raw = (folder / 'noir_flow.save').read_bytes()
                if phase == 'produce':
                    originals[case] = raw
                else:
                    verify(case, originals[case], raw)
                    if json.loads(raw)['schema'] > 1:
                        assert (folder / 'noir_flow.save.pre-migration').read_bytes() == originals[case]
                    print(f'SAVE_COMPAT_OK {case} original_sha256={hashlib.sha256(originals[case]).hexdigest()}')


if __name__ == '__main__':
    main()
