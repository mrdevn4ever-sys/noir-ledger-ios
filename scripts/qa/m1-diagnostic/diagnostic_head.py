"""A diagnostic dispatch may point one commit past the measured game, but only a tooling-only commit."""
import os
from pathlib import Path
import subprocess as sp

CAND = '4900655f78735cfc7ce352dc912850f2a5c00cc1'
BRANCH = 'refs/heads/rebuild/varnholm'
WORKFLOW = '.github/workflows/compile.yml'
PREFIX = 'scripts/qa/m1-diagnostic/'
FILES = frozenset(PREFIX + n for n in ('diagnostic_head.py', 'contracts.py', 'runner.py', 'M1IdleTests.swift', 'trace-1d69565.patch', 'trace-4900655.patch')) | {WORKFLOW}

def validate(live, env, revision, parents, changed):
    if env.get('GITHUB_EVENT_NAME') != 'workflow_dispatch' or env.get('GITHUB_REF') != BRANCH:
        raise ValueError('not a manual work-branch diagnostic')
    if live != revision or env.get('GITHUB_SHA') != live or parents != [CAND]:
        raise ValueError('stale dispatch or unexpected parent')
    if len(changed) != len(FILES) or set(changed) != FILES:
        raise ValueError('the dispatch commit is not the isolated diagnostics change')
    return CAND

def measured_source(live):
    package_checkout = Path(os.environ['GITHUB_WORKSPACE']).resolve()
    def git(*args):return sp.check_output(['git','-C',str(package_checkout),*args])
    revision = git('rev-parse','HEAD').decode().strip()
    parents = git('show','-s','--format=%P',revision).decode().split()
    if parents != [CAND]: raise ValueError('not a direct child of measured game')
    changed = git('diff-tree','--no-renames','-r','--name-only','--no-commit-id','-z',CAND,revision).decode().split('\0')[:-1]
    return validate(live, os.environ, revision, parents, changed)
