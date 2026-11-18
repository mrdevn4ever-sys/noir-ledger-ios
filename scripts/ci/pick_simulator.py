#!/usr/bin/env python3
"""Pick a real iPhone on iOS 27 compatible with the selected Xcode SDK."""
import json
import re
import subprocess
import sys


def choose(data: dict, sdk_version: str) -> tuple[str, str, str]:
    match = re.fullmatch(r"(\d+)\.(\d+)(?:\.\d+)?", sdk_version)
    if not match or int(match[1]) != 27:
        raise ValueError(f"Expected an iOS 27 simulator SDK, got {sdk_version!r}")
    sdk = (int(match[1]), int(match[2]))
    candidates = []
    for runtime, devices in data.get("devices", {}).items():
        version_match = re.search(r"iOS-(\d+)-(\d+)$", runtime)
        if not version_match or not isinstance(devices, list):
            continue
        version = (int(version_match[1]), int(version_match[2]))
        if version[0] != 27 or version > sdk:
            continue
        for device in devices:
            if not isinstance(device, dict) or device.get("isAvailable") is False:
                continue
            name = device.get("name", "")
            udid = device.get("udid", "")
            if not name.startswith("iPhone ") or "Duo" in name:
                continue
            if not re.fullmatch(r"[0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}", udid):
                continue
            preferred = 2 if re.fullmatch(r"iPhone \d+", name) else 1
            candidates.append((version, preferred, name, udid))
    if not candidates:
        raise ValueError(f"No available standard iPhone on iOS 27 supported by selected Xcode SDK {sdk_version}")
    version, _, name, udid = max(candidates)
    return udid, name, f"iOS {version[0]}.{version[1]}"


if __name__ == "__main__":
    try:
        sdk = subprocess.check_output(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"], text=True).strip()
        data = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"]))
        udid, name, runtime = choose(data, sdk)
        print(f"SIM_UDID={udid}")
        print(f"SIM_NAME='{name}'")
        print(f"SIM_RUNTIME='{runtime}'")
    except (ValueError, json.JSONDecodeError) as error:
        sys.exit(f"::error::{error}")
