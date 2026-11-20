#!/usr/bin/env python3
"""Require measured UI results, not just successful compilation of the focused tests."""
import json
import math
import re
import sys
from pathlib import Path

STARTS = {"CASHBOX", "ADDRESS_BOOK", "TOOLS"}
ROW = re.compile(r"\bOPENING start=(\w+) reward_s=([0-9.]+) confirmed_upgrade_s=([0-9.]+)\b")


def passed_cases(nodes):
    for node in nodes:
        if node.get("nodeType") == "Test Case" and node.get("result") == "Passed":
            yield node.get("nodeIdentifier", "")
        yield from passed_cases(node.get("children", []))


def evaluate(log, summary, tests):
    rows = {}
    for start, reward, upgrade in ROW.findall(log):
        if start in rows:
            raise ValueError(f"duplicate result for {start}; inspect retries")
        rows[start] = (float(reward), float(upgrade))
    for start, (reward, upgrade) in sorted(rows.items()):
        print(f"{start}: visible receipt {reward:.2f}s; confirmed upgrade {upgrade:.2f}s")
    if set(rows) != STARTS:
        raise ValueError(f"expected {sorted(STARTS)}, got {sorted(rows)}")
    for start, (reward, upgrade) in rows.items():
        if not (math.isfinite(upgrade) and 0 < reward <= 5 and reward <= upgrade <= 20):
            raise ValueError(f"{start}: timing target not met")
    required = {"LedgerStoreTests/" + name + "()" for name in (
        "resetFailureAndRetry", "paidDeliveryWriteFailure", "ownedStarterWithoutReceipt", "oldReceiptAfterRelaunch")}
    missing = required.difference(passed_cases(tests["testNodes"]))
    if missing:
        raise ValueError(f"missing successful persistence cases: {sorted(missing)}")
    if (summary.get("result") != "Passed" or summary.get("failedTests") != 0 or summary.get("skippedTests") != 0
            or summary.get("passedTests", 0) <= len(STARTS)):
        raise ValueError("app tests and opening UI tests must both execute and pass")
    return rows


if __name__ == "__main__":
    try:
        evaluate(Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace"),
                 json.loads(Path(sys.argv[2]).read_text(encoding="utf-8")),
                 json.loads(Path(sys.argv[3]).read_text(encoding="utf-8")))
    except ValueError as error:
        sys.exit(str(error))
    print("OPENING_UI_OK")
