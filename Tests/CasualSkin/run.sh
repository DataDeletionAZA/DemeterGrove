#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
checks_dir="$(mktemp -d "${TMPDIR:-/tmp}/daygarden-casual-checks.XXXXXX")"
trap 'rm -rf "$checks_dir"' EXIT
qa_dir="${1:-${CASUAL_SKIN_QA_DIR:-$checks_dir/visuals}}"
mkdir -p "$qa_dir"
qa_dir="$(cd "$qa_dir" && pwd)"
python3 - "$checks_dir" <<'PY'
from pathlib import Path
import plistlib
import sys

root = Path(sys.argv[1])
(root / 'Sources').mkdir()
for source in Path('Sources').glob('*.swift'):
    text = source.read_text()
    if source.name == 'Desktop.swift':
        text = text.replace('@main\n', '', 1)
    (root / 'Sources' / source.name).write_text(text)
contents = root / 'CasualSkinChecks.app' / 'Contents'
(contents / 'MacOS').mkdir(parents=True)
(contents / 'Resources').symlink_to(Path('Resources').resolve(), target_is_directory=True)
(contents / 'Info.plist').write_bytes(plistlib.dumps({
    'CFBundleIdentifier': 'local.daygarden.casual-skin-checks',
    'CFBundleExecutable': 'CasualSkinChecks',
    'CFBundlePackageType': 'APPL',
}))
PY
xcrun swiftc -swift-version 5 -parse-as-library "$checks_dir"/Sources/*.swift Tests/CasualSkin/main.swift -o "$checks_dir/CasualSkinChecks.app/Contents/MacOS/CasualSkinChecks" -framework SwiftUI -framework AppKit -framework UserNotifications -framework Carbon -framework Charts
CASUAL_SKIN_CHECK_ROOT="$checks_dir" CASUAL_SKIN_QA_DIR="$qa_dir" "$checks_dir/CasualSkinChecks.app/Contents/MacOS/CasualSkinChecks"
