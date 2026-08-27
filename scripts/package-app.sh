#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Music Projects Organizer"
EXEC_NAME="MusicProjectsOrganizer"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"
CONTENTS="$APP/Contents"
ZIP="$DIST/Music-Projects-Organizer.zip"

cd "$ROOT"

echo "Building universal release…"
swift build -c release --arch arm64 --arch x86_64
BIN="$ROOT/.build/apple/Products/Release/$EXEC_NAME"
if [[ ! -x "$BIN" ]]; then
  BIN="$ROOT/.build/release/$EXEC_NAME"
fi

rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
cp "$ROOT/Sources/App/Info.plist" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$CONTENTS/Info.plist"
cp "$BIN" "$CONTENTS/MacOS/$EXEC_NAME"
chmod +x "$CONTENTS/MacOS/$EXEC_NAME"
if [[ -f "$ROOT/Assets/AppIcon.icns" ]]; then
  cp "$ROOT/Assets/AppIcon.icns" "$CONTENTS/Resources/AppIcon.icns"
fi

xattr -cr "$APP"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"

rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "Packed: $APP"
echo "Zip:    $ZIP"
file "$CONTENTS/MacOS/$EXEC_NAME"
