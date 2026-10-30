#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if [[ -n "$(git status --porcelain)" ]]; then
    echo "请先提交当前更改，再发布版本。" >&2
    exit 1
fi
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "版本号格式应为数字.数字.数字。" >&2; exit 1; }
tag="v$version"
if git rev-parse "$tag" >/dev/null 2>&1; then
    [[ "$(git rev-list -n 1 "$tag")" == "$(git rev-parse HEAD)" ]] || { echo "该版本标签已指向另一份源码，请增加版本号。" >&2; exit 1; }
fi
bash test.sh
if ! git rev-parse "$tag" >/dev/null 2>&1; then git tag -a "$tag" -m "DemeterGrove $version"; fi
git push origin HEAD
git push origin "$tag"
[[ "$(git ls-remote origin "refs/heads/$(git branch --show-current)" | cut -f1)" == "$(git rev-parse HEAD)" ]]
[[ "$(git ls-remote origin "refs/tags/$tag^{}" | cut -f1)" == "$(git rev-parse HEAD)" ]]
echo "远端源码与版本标签已核对：$tag"
