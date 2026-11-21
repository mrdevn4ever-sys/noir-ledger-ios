#!/usr/bin/env python3
"""Require measured UI results, not just successful compilation of the focused tests."""
import json
import math
import re
import sys
from pathlib import Path

STARTS = {"CASHBOX", "ADDRESS_BOOK", "TOOLS"}
ROW = re.compile(r"\bOPENING start=(\w+) reward_s=(\S+) offer_s=(\S+) confirmed_upgrade_s=(\S+) raw_upgrade_s=(\S+) robot_wait_s=(\S+)")


def passed_cases(nodes):
    for node in nodes:
        if node.get("nodeType") == "Test Case" and node.get("result") == "Passed":
            yield node.get("nodeIdentifier", "")
        yield from passed_cases(node.get("children", []))


def evaluate(log, summary, tests):
    rows = {}
    for start, *fields in ROW.findall(log):
        if start in rows:
            raise ValueError(f"duplicate result for {start}; inspect retries")
        rows[start] = tuple(map(float, fields))
    for start, (reward, offer, upgrade, raw, robot) in sorted(rows.items()):
        print(f"{start}: receipt {reward:.2f}s; offer {offer:.2f}s; confirmed {raw:.2f}s - ready for input {robot:.2f}s = {upgrade:.2f}s")
    if set(rows) != STARTS:
        raise ValueError(f"expected {sorted(STARTS)}, got {sorted(rows)}")
    for start, (reward, offer, upgrade, raw, robot) in rows.items():
        if not (all(map(math.isfinite, (reward, offer, upgrade, raw, robot))) and 0 < reward <= 5
                and reward <= offer <= 20 and offer <= raw and 0 <= robot <= raw and 0 <= upgrade <= 20
                and math.isclose(raw - robot, upgrade, rel_tol=0, abs_tol=1e-6)):
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
