#!/usr/bin/env python3
"""Picks an available iPhone simulator from the runner's inventory (newest iOS runtime, preferring a standard
6.1-inch iPhone). Prints shell assignments: SIM_UDID, SIM_NAME, SIM_RUNTIME."""
import json
import re
import subprocess
import sys

data = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"]))
candidates = []
for runtime, devices in data["devices"].items():
    m = re.search(r"iOS-(\d+)-(\d+)", runtime)
    if not m:
        continue
    version = (int(m.group(1)), int(m.group(2)))
    for d in devices:
        name = d["name"]
        if not name.startswith("iPhone") or not d.get("isAvailable", True):
            continue
        preferred = 0
        if re.fullmatch(r"iPhone \d+( Pro)?", name):
            preferred = 2 if "Pro" not in name else 1
        candidates.append((version, preferred, name, d["udid"], runtime))
if not candidates:
    sys.exit("no available iPhone simulator")
candidates.sort(key=lambda c: (c[0], c[1]), reverse=True)
version, _, name, udid, runtime = candidates[0]
print(f"SIM_UDID={udid}")
print(f"SIM_NAME='{name}'")
print(f"SIM_RUNTIME='iOS {version[0]}.{version[1]}'")
