#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
version="$(cat VERSION)"
revision="${KEYPRESS_GIT_REVISION:-}"
if [[ -z "$revision" ]]; then
    if [[ "$(git rev-parse --show-toplevel 2>/dev/null || true)" == "$PWD" ]]; then
        revision="$(git rev-parse --short=12 HEAD)"
        if [[ -n "$(git status --porcelain --untracked-files=normal)" ]]; then
            revision="$revision-dirty"
        fi
    else
        # git archive substitutes this value; formula builds can also supply it explicitly.
        revision="$(cat .git_archival.txt 2>/dev/null || true)"
        if [[ ! "$revision" =~ ^[0-9a-f]{40}$ ]]; then revision="unknown"; fi
    fi
fi
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ || ! "$revision" =~ ^([0-9a-f]{7,40}(-dirty)?|unknown)$ ]]; then
    printf 'Invalid version or Git revision\n' >&2
    exit 1
fi
# Use a compact hash in the panel, retaining the dirty suffix for local changes.
if [[ "$revision" =~ ^[0-9a-f]{40}$ ]]; then revision="${revision:0:12}"; fi
./scripts/swift.sh build -c release "$@"
app="$(pwd)/build/Keypress.app"
mkdir -p "$app/Contents/MacOS"
cp "$(./scripts/swift.sh build -c release --show-bin-path "$@")/Keypress" "$app/Contents/MacOS/Keypress"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>CFBundleExecutable</key><string>Keypress</string>
    <key>CFBundleIdentifier</key><string>local.keypress.app</string>
    <key>CFBundleName</key><string>Keypress</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $version" "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :KeypressGitRevision string $revision" "$app/Contents/Info.plist"
codesign --force --sign - --identifier local.keypress.app "$app"
printf 'Built %s\n' "$app"
