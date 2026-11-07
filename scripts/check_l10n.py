#!/usr/bin/env python3
"""Localization integrity gate for NOIR LEDGER (runs on any host; CI runs it on macOS).

Checks:
  1. en and de Localizable.strings parse and contain exactly the same keys.
  2. Every key has the same format specifiers in both languages.
  3. Every key referenced literally from App/ code (t("…"), t.plural("…"), keys inside t(cond ? "a" : "b"))
     exists in both tables (plurals need _one and _other).
  4. No player-facing literal text: Text("…"), Label("…"), Button("…") and Text(verbatim: "…") with a literal are
     forbidden in App/, except the brand wordmark.
Computed keys (Labels.*) are verified by the Swift test LocalizationTests on the simulator.
Exit code 1 on any failure.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
APP = ROOT / "App"
ALLOWED_LITERALS = {"NOIR LEDGER"}

ENTRY = re.compile(r'^"((?:[^"\\]|\\.)+)"\s*=\s*"((?:[^"\\]|\\.)*)";\s*$')
SPEC = re.compile(r"%(?:(\d+)\$)?[-+ 0#]*\d*(?:\.\d+)?(l{0,2})([@dfsxXuc])")


def parse(path: pathlib.Path) -> dict:
    table = {}
    for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        s = line.strip()
        if not s or s.startswith("/*") or s.startswith("//"):
            continue
        m = ENTRY.match(s)
        if not m:
            raise SystemExit(f"{path}:{n}: cannot parse: {line}")
        if m.group(1) in table:
            raise SystemExit(f"{path}:{n}: duplicate key {m.group(1)}")
        table[m.group(1)] = m.group(2)
    return table


def strip_interpolations(s: str) -> str:
    """Removes Swift string interpolations (backslash-paren ... paren, with nesting)."""
    out, i = [], 0
    while i < len(s):
        if s.startswith("\\(", i):
            depth, i = 1, i + 2
            while i < len(s) and depth:
                depth += {"(": 1, ")": -1}.get(s[i], 0)
                i += 1
        else:
            out.append(s[i])
            i += 1
    return "".join(out)


def specs(value: str) -> list:
    out = []
    pos = 0
    for m in SPEC.finditer(value.replace("%%", "")):
        pos += 1
        out.append((int(m.group(1)) if m.group(1) else pos, m.group(3)))
    return sorted(out)


def main() -> int:
    errors = []
    en = parse(APP / "Resources/en.lproj/Localizable.strings")
    de = parse(APP / "Resources/de.lproj/Localizable.strings")
    for k in sorted(set(en) ^ set(de)):
        errors.append(f"key only in {'en' if k in en else 'de'}: {k}")
    for k in sorted(set(en) & set(de)):
        if specs(en[k]) != specs(de[k]):
            errors.append(f"format mismatch for {k}: en {specs(en[k])} de {specs(de[k])}")

    used = set()
    plural = set()
    sources = sorted(APP.rglob("*.swift"))
    for f in sources:
        text = f.read_text(encoding="utf-8")
        for m in re.finditer(r'\bt\.plural\(\s*"([a-z0-9_]+)"', text):
            plural.add(m.group(1))
        for m in re.finditer(r'\bt\(\s*"([a-z0-9_]+)"', text):
            used.add(m.group(1))
        for m in re.finditer(r'\bt\(([^()"]*\?\s*"([a-z0-9_]+)"\s*:\s*"([a-z0-9_]+)")', text):
            used.update([m.group(2), m.group(3)])
        for m in re.finditer(r'\b(?:Text|Label|Button)\(\s*"([^"]*)"', text):
            errors.append(f"{f.relative_to(ROOT)}: literal player-facing text \"{m.group(1)}\"")
        for m in re.finditer(r'Text\(verbatim:\s*"((?:[^"\\]|\\.)*)"\)', text):
            literal = strip_interpolations(m.group(1))
            if re.search(r"[A-Za-z]", literal) and m.group(1) not in ALLOWED_LITERALS:
                errors.append(f"{f.relative_to(ROOT)}: literal verbatim text \"{m.group(1)}\"")
    for k in sorted(used):
        if k not in en:
            errors.append(f"missing key used in code: {k}")
    for k in sorted(plural):
        for suffix in ("_one", "_other"):
            if k + suffix not in en:
                errors.append(f"missing plural form: {k}{suffix}")

    print(f"en keys: {len(en)}, de keys: {len(de)}, literal keys used: {len(used)}, plural keys: {len(plural)}, "
          f"swift files scanned: {len(sources)}")
    for e in errors:
        print("ERROR:", e)
    print("L10N_OK" if not errors else f"L10N_FAIL ({len(errors)} problems)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
