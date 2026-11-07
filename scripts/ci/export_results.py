#!/usr/bin/env python3
"""Exports screenshots and a machine-readable test summary from an .xcresult bundle (Xcode 16+ xcresulttool).

Usage: export_results.py <bundle.xcresult> <out_dir>
Writes <out_dir>/screenshots/<attachment name>.png, <out_dir>/test-summary.json, <out_dir>/tests.json and prints
counts. Exit 1 if the bundle reports failures or no screenshots were exported.
"""
import json
import pathlib
import shutil
import subprocess
import sys

bundle = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[2])
raw = out / "attachments-raw"
shots = out / "screenshots"
for d in (raw, shots):
    if d.exists():
        shutil.rmtree(d)
    d.mkdir(parents=True)

subprocess.run(["xcrun", "xcresulttool", "export", "attachments", "--path", str(bundle), "--output-path", str(raw)], check=True)
manifest = json.loads((raw / "manifest.json").read_text())
count = 0
for test in manifest:
    for att in test.get("attachments", []):
        name = att.get("suggestedHumanReadableName") or att.get("exportedFileName")
        src = raw / att["exportedFileName"]
        if not src.suffix.lower() == ".png" and not str(name).lower().endswith(".png"):
            if src.suffix.lower() not in (".png", ".jpeg", ".jpg"):
                continue
        stem = str(name)
        for suffix in (".png", ".jpeg", ".jpg"):
            if stem.lower().endswith(suffix):
                stem = stem[: -len(suffix)]
        # xcresulttool appends "_<index>_<uuid>" to names; keep the readable part we assigned.
        readable = stem.split("_0_")[0] if "_0_" in stem else stem
        dest = shots / f"{readable}{src.suffix.lower() or '.png'}"
        if dest.exists():
            dest = shots / f"{readable}-{count}{src.suffix.lower() or '.png'}"
        shutil.copyfile(src, dest)
        count += 1

summary = subprocess.check_output(["xcrun", "xcresulttool", "get", "test-results", "summary", "--path", str(bundle), "--compact"])
(out / "test-summary.json").write_bytes(summary)
tests = subprocess.check_output(["xcrun", "xcresulttool", "get", "test-results", "tests", "--path", str(bundle), "--compact"])
(out / "tests.json").write_bytes(tests)
s = json.loads(summary)
print(json.dumps({k: s.get(k) for k in ("result", "totalTestCount", "passedTests", "failedTests", "skippedTests", "expectedFailures")}))
print(f"screenshots exported: {count}")
sys.exit(0 if s.get("result") == "Passed" and count > 0 else 1)
