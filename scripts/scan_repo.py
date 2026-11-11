#!/usr/bin/env python3
"""Final repository scan for NOIR LEDGER iOS. Exit 1 on any genuine hit.

Scans shipped source and resources (App/, Packages/NoirCore/Sources/, AppTests/, UITests/, project.yml, scripts/) for:
  - unfinished-work markers (TODO, FIXME, XXX, placeholder, coming soon, lorem ipsum, "tbd");
  - real drug terminology (English and German);
  - network, analytics or tracking APIs anywhere, and store or advertising APIs outside App/Monetization
    (the only place allowed to talk to the App Store and to the rewarded-video SDK);
  - accidental secrets (private keys, tokens, Apple credentials).
The binding brief and reference docs are excluded: they name these terms in order to forbid them.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
TARGETS = ["App", "Packages/NoirCore/Sources", "AppTests", "UITests", "project.yml", "scripts", ".github"]
SELF = pathlib.Path(__file__).resolve()
TEXT_SUFFIXES = {".swift", ".strings", ".plist", ".json", ".yml", ".yaml", ".py", ".sh", ".xcprivacy", ".md"}

UNFINISHED = re.compile(r"\b(TODO|FIXME|XXX|TBD)\b|placeholder|coming soon|lorem ipsum", re.I)
DRUGS = re.compile(
    r"\b(cocaine|kokain|heroin|crystal meth|methamphetamine|metamphetamin|fentanyl|cannabis|marijuana|haschisch|hashish|"
    r"\blsd\b|mdma|ecstasy|opium|opioid|ketamin|ketamine|amphetamine|amphetamin|crack cocaine|speedball|narcotic|"
    r"betäubungsmittel|rauschgift)\b", re.I)
NETWORK = re.compile(
    r"\b(URLSession|URLRequest|NWConnection|import Network|WKWebView|import WebKit|AdSupport|"
    r"ASIdentifierManager|AppTrackingTransparency|ATTrackingManager|Firebase|Crashlytics|Mixpanel|Amplitude|"
    r"AppsFlyer|Adjust\b|Sentry|analytics)\b")
# Purchases and rewarded videos live in one folder; nothing else may reach the store or the advertising SDK.
MONETIZATION = re.compile(r"\b(StoreKit|SKPayment|GoogleMobileAds|UserMessagingPlatform|GADMobileAds|GADRewardedAd)\b")
MONETIZATION_HOME = ("App/Monetization/", "project.yml", "App/Info.plist", "StoreKit/")
URLS = re.compile(r"https?://", re.I)
SECRETS = re.compile(r"BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|ghp_[A-Za-z0-9]{20,}|gho_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|"
                     r"xox[baprs]-|\.p12\b|\.mobileprovision\b|APPLE_ID_PASSWORD|app-specific password", re.I)

# Benign, documented exceptions (file suffix, rule, reason).
ALLOW = [
    ("project.yml", "urls", "Swift package URLs of the advertising SDK and its consent library"),
    ("scripts/shared_assets.py", "urls", "none expected"),
    (".github/workflows/ios.yml", "urls", "GitHub run URL in the evidence report"),
    ("scripts/ci/report.py", "urls", "builds the GitHub Actions run URL for the report"),
    ("scripts/check_l10n.py", "unfinished", "none expected"),
]


def allowed(rel: str, rule: str) -> bool:
    return any(rel == f and rule == r for f, r, _ in ALLOW)


def main() -> int:
    hits = []
    files = []
    for t in TARGETS:
        p = ROOT / t
        files += [p] if p.is_file() else [f for f in p.rglob("*") if f.is_file()]
    for f in files:
        if f.resolve() == SELF or f.suffix not in TEXT_SUFFIXES:
            continue
        rel = f.relative_to(ROOT).as_posix()
        for n, line in enumerate(f.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
            if MONETIZATION.search(line) and not rel.startswith(MONETIZATION_HOME):
                hits.append(f"{rel}:{n}: [monetization outside App/Monetization] {line.strip()[:140]}")
            for rule, rx in (("unfinished", UNFINISHED), ("drugs", DRUGS), ("network", NETWORK), ("urls", URLS), ("secrets", SECRETS)):
                if rx.search(line) and not allowed(rel, rule):
                    if rule == "urls" and ("apple.com/DTDs" in line or "www.w3.org/2000/svg" in line):
                        continue
                    hits.append(f"{rel}:{n}: [{rule}] {line.strip()[:140]}")
    print(f"files scanned: {len(files)}")
    for h in hits:
        print("HIT:", h)
    print("SCAN_OK" if not hits else f"SCAN_FAIL ({len(hits)} hits)")
    return 1 if hits else 0


if __name__ == "__main__":
    sys.exit(main())
