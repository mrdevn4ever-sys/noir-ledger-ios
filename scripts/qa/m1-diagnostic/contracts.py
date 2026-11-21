"""Fail-closed contracts shared by the native collector and portable tests."""
import collections
import hashlib
import json
import re
import uuid
import xml.etree.ElementTree as ET
from pathlib import Path

BASE = '1d695653c3929c236c74b9d6bd192593d338ef52'
CAND = '4900655f78735cfc7ce352dc912850f2a5c00cc1'
CTRL = 'd37d69cd9dd67d910a999964ab5a85e8190dcb32'
RUN = 44848812779
BRANCH = 'rebuild/varnholm'
REPO = 'mrdevn4ever-sys/noir-ledger-ios'
GAME = 'io.puredevn.noirledger'
EXE = 'NoirLedger'
PATCH = {BASE: '66c98e5f05c44f2cc35a8173e363a40204e651aa81a3cd62af0e45a5960e5fac',
         CAND: '9d271f6932774df70fc6f9251ef4fce4f9a04197ae167a981e90571700552b7b'}
ROOT = Path(__file__).resolve().parent


class Stop(RuntimeError):
    pass


def need(ok, why):
    if not ok:
        raise Stop(why)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def dump(path, obj):
    path.write_text(json.dumps(obj, indent=2, sort_keys=True) + '\n', encoding='utf8')


def metadata(m, attempt, head):
    expected = dict(id=RUN, head_sha=CAND, head_branch=BRANCH, status='completed', conclusion='success',
                    path='.github/workflows/perf.yml', event='workflow_dispatch', run_attempt=attempt)
    need(head == CAND and m.get('head_repository', {}).get('full_name') == REPO and
         all(m.get(k) == v for k, v in expected.items()), 'stale, incomplete or wrong gate run/attempt/head')


def gate_result(parser, log):
    # Use the original gate, not its process exit code (invalid input also exits nonzero).
    ok, rows = parser.crew_trial(log, BASE, CTRL, CAND)
    need(not ok, 'M1 passed; diagnostic forbidden')
    return rows


def features(templates, record, export, instruments):
    need('Time Profiler' in templates.splitlines(), 'Time Profiler template unavailable')
    for option in ('--template', '--attach', '--time-limit', '--output', '--no-prompt'):
        need(option in record, 'record lacks ' + option)
    for option in ('--toc', '--xpath', '--output'):
        need(option in export, 'export lacks ' + option)
    return ['--instrument', 'Points of Interest'] if '--instrument' in record and 'Points of Interest' in instruments.splitlines() else []


def plan():
    return [(r, scene, sha) for r, order in enumerate(((BASE, CAND), (CAND, BASE)), 1)
            for scene in ('late', 'harbour') for sha in order]


def bind(ready, app, sha, scene):
    nonce = ready.get('nonce', '')
    need(isinstance(nonce, str) and re.fullmatch(r'[0-9a-fA-F-]{36}', nonce) and
         str(uuid.UUID(nonce)).lower() == nonce.lower(), 'invalid idle nonce')
    need(ready == {'sha': sha, 'scene': scene, 'nonce': nonce}, 'wrong UI test ready stamp')
    need(all(app.get(k) == v for k, v in {**ready, 'bundle': GAME, 'quiet': True,
         'chapter': {'late': 6, 'harbour': 3}[scene]}.items()), 'wrong game build/fixture/nonce')
    need(type(app.get('pid')) is int and app['pid'] > 1, 'invalid game PID')
    return app['pid']


def validate_toc(path, pid):
    root = ET.parse(path).getroot()
    runs = root.findall('run')
    need(root.tag == 'trace-toc' and len(runs) == 1 and runs[0].get('number') == '1', 'not a fresh single-run trace')
    targets = runs[0].findall('./info/target/process')
    if targets:
        need(any(t.get('pid') == str(pid) and t.get('name') == EXE for t in targets), 'wrong trace target')
    schemas = [e.get('schema') for e in runs[0].findall('./data/table')]
    need(schemas.count('time-profile') == 1, 'missing or ambiguous CPU sample table')
    return schemas


def samples(path, pid):
    need(0 < path.stat().st_size <= 128 * 1024**2, 'empty or oversize CPU export')
    root = ET.parse(path).getroot()
    nodes = root.findall('node')
    need(root.tag == 'trace-query-result' and len(nodes) == 1 and
         nodes[0].find('schema') is not None and nodes[0].find('schema').get('name') == 'time-profile', 'wrong export schema')
    ids = {}
    for e in nodes[0].iter():
        if 'id' in e.attrib:
            key = e.get('id'); need(key not in ids, 'duplicate XML id'); ids[key] = e

    def resolve(e):
        if e is not None and 'ref' in e.attrib:
            r = ids.get(e.get('ref')); need(r is not None and r.tag == e.tag and 'ref' not in r.attrib, 'bad XML reference'); return r
        return e

    def child(e, key):
        return resolve(e.find(key)) if e is not None else None

    def number(e):
        return int(e.text) if e is not None and (e.text or '').isdigit() else -1

    times, leaves = [], collections.Counter()
    for row in nodes[0].findall('row'):
        process = child(row, 'process')
        if number(child(process, 'pid')) != pid:
            continue  # never credit another process's stack
        need(process.get('fmt') == f'{EXE} ({pid})', 'PID/name mismatch in sample')
        stack = child(row, 'backtrace')
        if stack is None: continue
        frames = [resolve(f) for f in stack.findall('frame')]
        names = [f.get('name', '') for f in frames if f is not None]
        t = number(child(row, 'sample-time'))
        if t >= 0 and any(n and not re.fullmatch(r'(?:0x[0-9a-fA-F]+|\?+|<unknown>|Unknown)', n) for n in names):
            times.append(t); leaves[names[0]] += 1
    need(len(times) >= 10 and max(times) - min(times) >= 4_000_000_000, 'insufficient time-spanning, symbolized target stacks')
    return dict(target_samples=len(times), span_ns=max(times)-min(times), top_leaf_sample_counts=leaves.most_common(12),
                interpretation='CPU samples only; frame attribution unknown; GPU not measured')
