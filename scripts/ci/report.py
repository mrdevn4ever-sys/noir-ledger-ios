#!/usr/bin/env python3
"""Writes the provenance/acceptance report for one CI run (JSON + Markdown).

Usage: report.py <evidence dir>   (reads env: GITHUB_SHA, GITHUB_RUN_ID, GITHUB_RUN_ATTEMPT, GITHUB_REPOSITORY,
SIM_NAME, SIM_RUNTIME, SIM_UDID, RUNNER_OS, ImageOS, ImageVersion)
"""
import datetime
import json
import os
import pathlib
import subprocess
import sys

ev = pathlib.Path(sys.argv[1])


def sh(cmd):
    try:
        return subprocess.check_output(cmd, shell=True, text=True).strip()
    except subprocess.CalledProcessError:
        return ""


summary = json.loads((ev / "test-summary.json").read_text()) if (ev / "test-summary.json").exists() else {}
core = (ev / "core-tests.log").read_text(errors="replace") if (ev / "core-tests.log").exists() else ""
core_line = next((l for l in core.splitlines() if "Test run with" in l), "")
playthroughs = [l.strip() for l in core.splitlines() if l.startswith("seed=") or l.startswith("NG+ won")]
shots = sorted(p.name for p in (ev / "screenshots").glob("*.png")) if (ev / "screenshots").exists() else []
checks = {}
for name in ("l10n", "asset-parity", "release-exclusion", "scan"):
    f = ev / f"{name}.log"
    if f.exists():
        checks[name] = f.read_text(errors="replace").strip().splitlines()[-1]

run_url = f"https://github.com/{os.environ.get('GITHUB_REPOSITORY', '')}/actions/runs/{os.environ.get('GITHUB_RUN_ID', '')}"
report = {
    "sha": os.environ.get("GITHUB_SHA", sh("git rev-parse HEAD")),
    "run_id": os.environ.get("GITHUB_RUN_ID"),
    "run_attempt": os.environ.get("GITHUB_RUN_ATTEMPT"),
    "run_url": run_url,
    "generated_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
    "runner": {"os": os.environ.get("RUNNER_OS"), "image": os.environ.get("ImageOS"), "image_version": os.environ.get("ImageVersion"),
               "macos": sh("sw_vers -productVersion")},
    "xcode": sh("xcodebuild -version | tr '\\n' ' '"),
    "swift": sh("swift --version 2>&1 | head -1"),
    "simulator": {"name": os.environ.get("SIM_NAME"), "runtime": os.environ.get("SIM_RUNTIME"), "udid": os.environ.get("SIM_UDID")},
    "xcode_tests": {k: summary.get(k) for k in ("result", "totalTestCount", "passedTests", "failedTests", "skippedTests")},
    "core_tests": core_line,
    "playthroughs": playthroughs,
    "checks": checks,
    "screenshots": shots,
    "artifacts": sorted(p.name for p in ev.iterdir() if p.is_file()),
}
(ev / "acceptance-report.json").write_text(json.dumps(report, indent=2))
md = [f"# CI evidence — {report['sha']}", "", f"- Run: {run_url} (attempt {report['run_attempt']})",
      f"- Generated: {report['generated_utc']}", f"- Runner: {report['runner']}", f"- Xcode: {report['xcode']}",
      f"- Swift: {report['swift']}", f"- Simulator: {report['simulator']}", f"- Xcode tests: {report['xcode_tests']}",
      f"- Core tests: {core_line}", "- Playthroughs:"] + [f"  - {p}" for p in playthroughs] + \
     ["- Checks:"] + [f"  - {k}: {v}" for k, v in checks.items()] + [f"- Screenshots ({len(shots)}):"] + [f"  - {s}" for s in shots]
(ev / "acceptance-report.md").write_text("\n".join(md) + "\n")
print("\n".join(md[:12]))
