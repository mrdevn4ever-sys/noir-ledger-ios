#!/usr/bin/env python3
"""M1 paired CPU capture. Native entry point is restricted to a hosted Actions Mac."""
import argparse
import contextlib
import importlib.util
import json
import os
from pathlib import Path
import platform
import plistlib
import re
import shutil
import signal
import subprocess as sp
import sys
import tarfile
import time
from diagnostic_head import measured_source
from contracts import (BASE, BRANCH, CAND, CTRL, EXE, GAME, PATCH, REPO, ROOT, RUN, Stop,
                       bind, digest, dump, features, gate_result, metadata, need, plan, samples, validate_toc)

XC = ['xcrun', 'xctrace']
SIM = ['xcrun', 'simctl']


def kill(p):
    if os.name == 'posix':
        try: os.killpg(p.pid, signal.SIGKILL)
        except ProcessLookupError: pass
    elif p.poll() is None: p.kill()
    p.wait(timeout=8)


@contextlib.contextmanager
def child(cmd, stdout, cwd=None, stderr=sp.STDOUT):
    p = sp.Popen(cmd, stdin=sp.DEVNULL, stdout=stdout, stderr=stderr, cwd=cwd, start_new_session=os.name == 'posix')
    try: yield p
    finally:
        if p.poll() is None: kill(p)


def run(cmd, sec=30, *, cwd=None, log=None, optional=False):
    with (log.open('wb') if log else contextlib.nullcontext(sp.PIPE)) as output:
        with child(cmd, output, cwd) as p:
            try: data = p.communicate(timeout=sec)[0] or b''
            except sp.TimeoutExpired:
                kill(p)
                raise Stop(f'timeout after {sec}s: {cmd[0:3]}')
            text = data.decode('utf8', errors='replace').strip()
            if p.returncode and not optional: raise Stop(f'rc={p.returncode} {cmd[0:3]}: {log or text[-1000:]}')
            return ('' if p.returncode else text)


def load_gate(repo, dest):
    path = 'scripts/qa/perf_gate.py'
    obj = run(['git', '-C', repo, 'rev-parse', CAND + ':' + path]); need(obj == '85da57833e9cf59705c05185d60e3aa8ff0c4ac6', 'unexpected gate verifier')
    py = dest/'pinned_gate.py'; run(['git', '-C', repo, 'cat-file', 'blob', obj], log=py)
    spec = importlib.util.spec_from_file_location('pinned_gate', py)
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module); return module


def gate(repo, ev, attempt):
    api = ['gh', 'api', 'repos/' + REPO + '/']
    def check():
        m = json.loads(run(api[:2]+[api[2]+f'actions/runs/{RUN}']))
        head = run(api[:2]+[api[2]+'branches/rebuild%2Fvarnholm','--jq','.commit.sha'])
        metadata(m, attempt, measured_source(head)); return m
    m = check(); logfile = ev/'gate.log'
    run(['gh','run','view', str(RUN), '-R', REPO,'--attempt',str(attempt),'--log'], 120, log=logfile)
    rows = gate_result(load_gate(repo, ev), logfile.read_text(encoding='utf-8-sig')); check()
    dump(ev/'gate.json', dict(run=RUN, attempt=attempt, url=m['html_url'], base=BASE, control=CTRL,
                              candidate=CAND, verdict='PERF_GATE_REGRESSION', log_sha256=digest(logfile), rows=rows))


# Written immediately after the pinned QA scenario has actually been applied, not at launch request time.
APP_STAMP = '''
#if M1_FRAME_DIAGNOSTIC
            if let nonce = value("-m1-token") {
                let stamp: [String: Any] = ["sha": "__M1_SHA__", "scene": name, "chapter": store.state.chapter,
                    "nonce": nonce, "bundle": Bundle.main.bundleIdentifier ?? "", "quiet": has("-qa-quiet"),
                    "pid": ProcessInfo.processInfo.processIdentifier]
                do {
                    let dir = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask,
                                                          appropriateFor: nil, create: true)
                    try JSONSerialization.data(withJSONObject: stamp).write(to: dir.appendingPathComponent("m1-fixture.json"), options: .atomic)
                } catch { assertionFailure("M1 fixture stamp: \\(error)") }
            }
#endif'''


def stage(repo, sha, dest):
    need(sha in PATCH and run(['git','-C',repo,'rev-parse','--verify',sha+'^{commit}']) == sha, 'source pin mismatch')
    patch = ROOT/f'trace-{sha[:7]}.patch'; need(digest(patch) == PATCH[sha], 'patch pin mismatch')
    dest.mkdir(); tar = dest.parent/(sha+'.tar')
    run(['git','-C',repo,'archive','--format=tar','-o',tar,sha], 180)
    with tarfile.open(tar) as ar:
        need(ar.pax_headers.get('comment') == sha, 'archive commit mismatch')
        for m in ar:
            need((m.isfile() or m.isdir()) and (dest/m.name).resolve().is_relative_to(dest.resolve()), 'unexpected archive member')
            ar.extract(m, dest, filter='data')
    tar.unlink()
    for opts in (['--check'], []): run(['git','apply','--no-index',*opts,patch],cwd=dest)
    qa = dest/'App/QA/QAAccelerator.swift'; text = qa.read_text(encoding='utf8'); anchor = 's.lastWallClockMs = store.nowMs\n            store.replaceState(s)'
    need(text.count(anchor)==1, 'fixture anchor drift'); qa.write_text(text.replace(anchor, anchor+APP_STAMP.replace('__M1_SHA__',sha)),encoding='utf8')
    test = dest/'UITests/M1IdleTests.swift'; need(not test.exists(), 'test already exists')
    test.write_text((ROOT/test.name).read_text(encoding='utf8').replace('__M1_SHA__',sha),encoding='utf8')
    project = dest/'project.yml'; spec = project.read_text(encoding='utf8'); before='SWIFT_ACTIVE_COMPILATION_CONDITIONS: DEBUG NOIR_QA'; need(spec.count(before)==2, 'unexpected Debug conditions')
    project.write_text(spec.replace(before,before+' M1_FRAME_DIAGNOSTIC',1),encoding='utf8')
    return {str(p.relative_to(dest)):digest(p) for p in (qa,test,project,dest/'App/Model/LedgerStore.swift')}


def pick_sim():
    inventory=json.loads(run(SIM+['list','devices','available','-j']))['devices']; picks=[]
    sdk = tuple(map(int,run(['xcrun','--sdk','iphonesimulator','--show-sdk-version']).split('.')[:2]))
    for rt, devices in inventory.items():
        m=re.search(r'\.iOS-(\d+)-(\d+)',rt)
        if not m: continue
        ver=tuple(map(int,m.groups()))
        for d in devices:
            if d.get('isAvailable') and ver <= sdk and re.fullmatch(r'iPhone \d+( Pro)?',d['name']):
                picks.append((ver,' Pro' not in d['name'],d['name'],d['udid'],rt,d))
    need(picks,'no compatible standard iPhone simulator'); _,_,_,udid,rt,d=max(picks,key=lambda p:p[:5]); return udid,rt,d


def requirements(ev):
    run(['xcrun','--find','xctrace']); info={}
    for key, args in [('templates',['list','templates']),('record',['help','record']),('export',['help','export']),('instruments',['list','instruments']),('devices',['list','devices'])]:
        info[key]=run(XC+args,60,optional=key=='instruments'); (ev/(key+'.txt')).write_text(info[key],encoding='utf8')
    return features(info['templates'],info['record'],info['export'],info['instruments'])


def bundle_id(app): return plistlib.loads((app/'Info.plist').read_bytes())['CFBundleIdentifier']


def build(repo, work, ev, sha, udid):
    src=work/sha; hashes=stage(repo,sha,src); dd=work/('dd-'+sha)
    run(['xcodegen','generate','--quiet'],120,cwd=src,log=ev/(sha+'-generate.log'))
    xc=['xcodebuild','-project',str(src/'NoirLedger.xcodeproj'),'-scheme','NoirLedger','-configuration','Debug','-destination','id='+udid,'-derivedDataPath',str(dd),'-parallel-testing-enabled','NO','CODE_SIGNING_ALLOWED=NO']
    run(xc+['build-for-testing'],1200,cwd=src,log=ev/(sha+'-build.log'))
    products=dd/'Build/Products/Debug-iphonesimulator'; app=products/'NoirLedger.app'; runners=list(products.glob('*UITests-Runner.app'))
    need(bundle_id(app)==GAME and len(runners)==1,'unexpected build products')
    exe=app/EXE; ident=run(['xcrun','dwarfdump','--uuid',exe]).splitlines(); need(ident,'no built Mach-O UUID')
    resolved=list(src.glob('*.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved')); need(len(resolved)==1,'cannot bind SPM resolution')
    deps=json.loads(resolved[0].read_bytes())['pins']; dump(ev/(sha+'-build.json'),dict(source=sha,patch=PATCH[sha],overlay=hashes,uuid=ident,dependencies=deps))
    return xc, bundle_id(runners[0]), exe, deps


def container(udid,bundle,kind,optional=False):
    path=run(SIM+['get_app_container',udid,bundle,kind],8,optional=optional)
    if not path and optional:return None
    need(Path(path).is_absolute() and Path(path).is_dir(),'bad simulator container');return Path(path)


def wait_ready(p, udid, runner, start, sec=75):
    until=time.monotonic()+sec
    while time.monotonic()<until:
        need(p.poll() is None,'UI test exited before idle handshake'); d=container(udid,runner,'data',True)
        if d:
            path=d/'Documents/m1-ready.json'
            if path.is_file() and path.stat().st_mtime_ns >= start:return path.parent,json.loads(path.read_bytes())
        time.sleep(0.4)
    raise Stop('timeout waiting for fresh idle handshake')


def identity(pid, expected):
    comm=run(['ps','-ww','-p',str(pid),'-o','comm=']); need(Path(comm).resolve()==expected.resolve(),'PID is not installed simulator executable')
    start=run(['ps','-p',str(pid),'-o','lstart=']);need(start,'missing process birth time'); return start


def trial(dest,xc,runner,built,opts,udid,sha,scene):
    dest.mkdir(); start=time.time_ns(); case='M1IdleTests/test'+scene.capitalize()
    with (dest/'test.log').open('wb') as log, child(xc+['test-without-building','-only-testing:NoirLedgerUITests/'+case,'-resultBundlePath',str(dest/'idle.xcresult')],log) as p:
        docs, ready=wait_ready(p,udid,runner,start)
        marker=container(udid,GAME,'data')/'Documents/m1-fixture.json'; need(marker.stat().st_mtime_ns>=start,'stale fixture stamp'); app=json.loads(marker.read_bytes()); pid=bind(ready,app,sha,scene)
        exe=container(udid,GAME,'app')/EXE
        def uuids(file): return sorted(re.findall(r'^UUID: ([A-Fa-f0-9-]{36}) ',run(['xcrun','dwarfdump','--uuid',file]),re.M))
        built_ids=uuids(built);need(built_ids and built_ids==uuids(exe),'installed binary differs from pinned build')
        birth=identity(pid,exe);trace=dest/'idle.trace';begin=time.time_ns()
        dump(dest/'binding.json',dict(ready=ready,fixture=app,udid=udid,birth=birth,installed=str(exe),uuid=built_ids,
             fixture_ns=marker.stat().st_mtime_ns,idle_ready_ns=(docs/'m1-ready.json').stat().st_mtime_ns,record_request_ns=begin))
        run(XC+['record','--no-prompt','--template','Time Profiler',*opts,'--attach',str(pid),'--time-limit','8s','--output',trace],65,log=dest/'record.log')
        end=time.time_ns();need(identity(pid,exe)==birth and json.loads(marker.read_bytes())==app and p.poll() is None,'game or fixture changed while recording')
        (docs/('m1-stop-'+ready['nonce'])).touch(exist_ok=False)
        try: rc=p.wait(timeout=60)
        except sp.TimeoutExpired: raise Stop('timeout finishing UI test')
        need(rc==0 and json.loads((docs/'m1-done.json').read_bytes())==ready,'idle end not confirmed by passing UI test')
    need(trace.is_dir() and any(f.is_file() and f.stat().st_size>0 for f in trace.rglob('*')), 'empty trace bundle')
    def export(args,out):run(XC+['export','--input',trace,*args,'--output',dest/out],90,log=dest/(out+'.log'))
    export(['--toc'],'toc.xml'); schemas=validate_toc(dest/'toc.xml',pid)
    export(['--xpath','/trace-toc/run[@number="1"]/data/table[@schema="time-profile"]'],'samples.xml')
    result=samples(dest/'samples.xml',pid);result.update(sha=sha,scene=scene,udid=udid,pid=pid,nonce=ready['nonce'],
        record_return_ns=end,schemas=schemas,template='Time Profiler',extra_instrument=opts,samples_sha256=digest(dest/'samples.xml'))
    # No optional table can make a bad CPU capture pass. Export known interval
    # schemas only if advertised. Rows are leads for inspection, not attribution.
    result['signposts']='not verified'
    for schema in ('os-signpost-interval', 'os-signpost-intervals'):
        if schemas.count(schema)==1:
            try:
                export(['--xpath',f'/trace-toc/run[@number="1"]/data/table[@schema="{schema}"]'],'intervals.xml')
                result['signposts']='interval table exported; check PID, subsystem and timestamps before use'
            except Stop as e: result['signposts']='interval export unavailable: '+str(e)
            break
    dump(dest/'validated.json',result);return result


def collect(repo,stage_root,attempt):
    ev=stage_root/'evidence';ev.mkdir(parents=True,exist_ok=False);work=stage_root/'work';work.mkdir()
    try:
        gate(repo,ev,attempt)  # nothing native before verified regression
        os.environ.pop('GH_TOKEN',None);os.environ.pop('GITHUB_TOKEN',None)
        opts=requirements(ev);udid,rt,d=pick_sim();dump(ev/'host.json',dict(platform=platform.platform(),xcode=run(['xcodebuild','-version']),developer_dir=os.getenv('DEVELOPER_DIR'),simulator=d,runtime=rt,extra_instrument=opts,plan=plan(),package_commit=os.getenv('GITHUB_SHA')))
        if not shutil.which('xcodegen'):run(['brew','install','xcodegen'],600,log=ev/'xcodegen-install.log')
        if d['state']!='Booted':run(SIM+['boot',udid],90)
        run(SIM+['bootstatus',udid,'-b'],180)
        builds={s:build(repo,work,ev,s,udid) for s in PATCH};need(builds[BASE][3]==builds[CAND][3],'SPM revisions differ')
        rows=[]
        for r,scene,sha in plan():
            xc,runner,built,_=builds[sha]; rows.append(trial(ev/f'r{r}-{scene}-{sha}',xc,runner,built,opts,udid,sha,scene))
        dump(ev/'paired.json',dict(status='complete_cpu_only',rows=rows,frame_attribution='unknown',release_gate=False))
    except Exception as e:
        dump(ev/'stopped.json',dict(status='inconclusive',reason=str(e),release_gate=False));raise


def main():
    a=argparse.ArgumentParser(description=__doc__);a.add_argument('--confirm',required=True,choices=['M1_GATE_FAILED']);a.add_argument('--attempt',required=True,type=int);args=a.parse_args()
    need(args.attempt>0,'invalid attempt');need(platform.system()=='Darwin' and os.getenv('GITHUB_ACTIONS')=='true' and os.getenv('M1_RUNNER_ENVIRONMENT')=='github-hosted' and os.getenv('GITHUB_REPOSITORY')==REPO and os.getenv('GITHUB_EVENT_NAME')=='workflow_dispatch','only manual GitHub-hosted macOS in source repository')
    repo=Path(os.environ['GITHUB_WORKSPACE']).resolve(); temp=Path(os.environ['RUNNER_TEMP']).resolve();need(not temp.is_relative_to(repo),'refuse output in checkout');collect(repo/'pinned-game',temp/'m1-trace',args.attempt)


if __name__=='__main__':
    try: main()
    except Exception as e: print('M1_STOP:',e,file=sys.stderr);sys.exit(2)
