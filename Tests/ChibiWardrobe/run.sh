#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
checks_dir="$(mktemp -d "${TMPDIR:-/tmp}/daygarden-wardrobe-checks.XXXXXX")"
trap 'rm -rf "$checks_dir"' EXIT
python3 - "$checks_dir" <<'PY'
from pathlib import Path
import plistlib
import sys
root=Path(sys.argv[1])
(root/'Sources').mkdir()
for source in Path('Sources').glob('*.swift'):
    text=source.read_text()
    if source.name=='Desktop.swift': text=text.replace('@main\n','',1)
    (root/'Sources'/source.name).write_text(text)
contents=root/'WardrobeChecks.app'/'Contents'
(contents/'Resources').mkdir(parents=True)
(contents/'MacOS').mkdir()
(contents/'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':'local.daygarden.wardrobe-checks','CFBundleExecutable':'WardrobeChecks','CFBundlePackageType':'APPL'}))
PY
xcrun swiftc -swift-version 5 -parse-as-library "$checks_dir"/Sources/*.swift Tests/ChibiWardrobe/main.swift -o "$checks_dir/WardrobeChecks.app/Contents/MacOS/WardrobeChecks" -framework SwiftUI -framework AppKit -framework UserNotifications -framework Carbon -framework Charts
WARDROBE_CHECK_ROOT="$checks_dir" "$checks_dir/WardrobeChecks.app/Contents/MacOS/WardrobeChecks"
