#!/usr/bin/env python3
"""Cross-platform asset parity tool for NOIR LEDGER iOS.

The canonical asset pack lives in `shared-assets/` and is copied byte-identically from the Android repository
(`F:/Projects/NoirLedger/shared-assets`, read-only). iOS platform exports are generated from those masters.

Usage:
  python3 scripts/shared_assets.py sync --from <android>/shared-assets   # copy pack + regenerate iOS exports
  python3 scripts/shared_assets.py export                                 # regenerate iOS exports only
  python3 scripts/shared_assets.py check                                  # verify; exit 1 on any divergence

`check` fails when:
  - a manifest source or PNG master is missing or its SHA-256 differs from the manifest;
  - a file exists in shared-assets/ that the manifest does not list (other than the manifest itself);
  - an iOS export listed in the manifest is missing or not byte-identical to its master;
  - an asset catalog image name used in App/ Swift code has no imageset;
  - the shared colour tokens in App/Design/Theme.swift differ from shared-assets/tokens/tokens.json.
"""
import hashlib
import json
import pathlib
import re
import shutil
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
PACK = ROOT / "shared-assets"
XCASSETS = ROOT / "App/Resources/Assets.xcassets"
THEME = ROOT / "App/Design/Theme.swift"

IMAGESET = re.compile(r"App/Resources/Assets\.xcassets/(\w+)\.imageset \((vector|copy) (?:from|of) shared-assets/([\w./-]+)\)")
COPY = re.compile(r"(App/Resources/[\w./-]+) \(copy of ([\w./-]+)\)")


def sha(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def manifest() -> dict:
    return json.loads((PACK / "asset-manifest.json").read_text(encoding="utf-8"))


def ios_exports(m: dict):
    """Yields (asset id, kind, target, master path) for every iOS export in the manifest."""
    for a in m["assets"]:
        for e in a.get("exports", {}).get("ios", []):
            mi = IMAGESET.match(e)
            if mi:
                yield a["id"], "imageset:" + a.get("kind", ""), mi.group(1), PACK / mi.group(3)
                continue
            mc = COPY.match(e)
            if mc:
                yield a["id"], "copy", ROOT / mc.group(1), PACK / mc.group(2)
                continue
            yield a["id"], "other", e, None


def write_imageset(name: str, master: pathlib.Path, template: bool) -> None:
    d = XCASSETS / f"{name}.imageset"
    if d.exists():
        shutil.rmtree(d)
    d.mkdir(parents=True)
    shutil.copyfile(master, d / master.name)
    props = {"author": "xcode", "version": 1}
    contents = {"images": [{"filename": master.name, "idiom": "universal"}], "info": props}
    properties = {}
    if master.suffix == ".svg":
        properties["preserves-vector-representation"] = True
    if template:
        # Single-colour marks are tinted by the surrounding foreground colour; the artwork bytes are unchanged.
        properties["template-rendering-intent"] = "template"
    if properties:
        contents["properties"] = properties
    (d / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n", encoding="utf-8", newline="\n")


def export() -> None:
    m = manifest()
    for asset_id, kind, target, master in ios_exports(m):
        if kind.startswith("imageset"):
            write_imageset(target, master, template=kind == "imageset:mark")
        elif kind == "copy":
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(master, target)
    print("exports regenerated from shared-assets/")


def sync(source: pathlib.Path) -> None:
    if not (source / "asset-manifest.json").is_file():
        raise SystemExit(f"no asset-manifest.json in {source}")
    if PACK.exists():
        shutil.rmtree(PACK)
    shutil.copytree(source, PACK)
    print(f"copied {sum(1 for p in PACK.rglob('*') if p.is_file())} files from {source}")
    export()


def theme_tokens() -> dict:
    text = THEME.read_text(encoding="utf-8")
    block = re.search(r"// BEGIN SHARED TOKENS(.*?)// END SHARED TOKENS", text, re.S)
    if not block:
        return {}
    return {name: f"#{hexv.upper()}" for name, hexv in re.findall(r"static let (\w+) = Color\(hex: 0x([0-9A-Fa-f]{6})\)", block.group(1))}


def check() -> int:
    errors = []
    m = manifest()
    listed = {"asset-manifest.json"}
    for a in m["assets"]:
        for key in ("source",):
            p = PACK / a[key]
            listed.add(a[key])
            if not p.is_file():
                errors.append(f"{a['id']}: missing master {a[key]}")
            elif sha(p) != a["sha256"]:
                errors.append(f"{a['id']}: sha256 mismatch for {a[key]}")
        if "png" in a:
            p = PACK / a["png"]["source"]
            listed.add(a["png"]["source"])
            if not p.is_file():
                errors.append(f"{a['id']}: missing PNG master {a['png']['source']}")
            elif sha(p) != a["png"]["sha256"]:
                errors.append(f"{a['id']}: sha256 mismatch for {a['png']['source']}")
    for p in PACK.rglob("*"):
        if p.is_file() and p.relative_to(PACK).as_posix() not in listed:
            errors.append(f"unlisted file in shared-assets: {p.relative_to(PACK).as_posix()}")

    imagesets = set()
    exports = 0
    for asset_id, kind, target, master in ios_exports(m):
        exports += 1
        if kind.startswith("imageset"):
            imagesets.add(target)
            f = XCASSETS / f"{target}.imageset" / master.name
            if not f.is_file() or f.read_bytes() != master.read_bytes():
                errors.append(f"{asset_id}: imageset {target} is missing or not byte-identical to {master.relative_to(ROOT).as_posix()}")
        elif kind == "copy":
            if not target.is_file() or target.read_bytes() != master.read_bytes():
                errors.append(f"{asset_id}: {target.relative_to(ROOT).as_posix()} is not a copy of {master.relative_to(ROOT).as_posix()}")
        elif kind == "other":
            if "Theme.swift" not in str(target):
                errors.append(f"{asset_id}: unrecognised iOS export '{target}'")

    used = set()
    for f in (ROOT / "App").rglob("*.swift"):
        used.update(re.findall(r'(?:Image|UIImage)\(\s*"([A-Za-z0-9]+)"', f.read_text(encoding="utf-8")))
        used.update(re.findall(r'"((?:Product|District|Front|Role|Branch|Status|Brand|Material)[A-Z][A-Za-z0-9]*)"',
                               f.read_text(encoding="utf-8")))
    on_disk = {p.name[: -len(".imageset")] for p in XCASSETS.glob("*.imageset")}
    for name in sorted(used - on_disk):
        errors.append(f"Swift references missing imageset {name}")

    tokens = {k: v["hex"].upper() for k, v in json.loads((PACK / "tokens/tokens.json").read_text(encoding="utf-8"))["colors"].items()}
    theme = theme_tokens()
    if theme != tokens:
        for k in sorted(set(tokens) | set(theme)):
            if tokens.get(k) != theme.get(k):
                errors.append(f"token {k}: shared {tokens.get(k)} vs Theme.swift {theme.get(k)}")

    print(f"manifest assets: {len(m['assets'])}, iOS exports: {exports}, imagesets: {len(imagesets)}, "
          f"image names used in Swift: {len(used)}, tokens: {len(tokens)}")
    print(f"manifest sha256: {sha(PACK / 'asset-manifest.json')}")
    for e in errors:
        print("ERROR:", e)
    print("ASSET_PARITY_OK" if not errors else f"ASSET_PARITY_FAIL ({len(errors)} problems)")
    return 1 if errors else 0


def main() -> int:
    if len(sys.argv) >= 2 and sys.argv[1] == "check":
        return check()
    if len(sys.argv) >= 2 and sys.argv[1] == "export":
        export()
        return 0
    if len(sys.argv) >= 4 and sys.argv[1] == "sync" and sys.argv[2] == "--from":
        sync(pathlib.Path(sys.argv[3]))
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
