#!/bin/bash
# Crea dist/Disableton.app (universale: Intel + Apple Silicon, macOS 12+) e dist/disableton (riga di comando).
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-0.1.0}"
BUILD="${BUILD:-1}"
COMMIT="${COMMIT:-$(git rev-parse HEAD 2>/dev/null || echo sviluppo)}"
ARCHS=(--arch arm64 --arch x86_64)

swift build -c release "${ARCHS[@]}" --product DisabletonApp
swift build -c release "${ARCHS[@]}" --product disableton
BIN_DIR="$(swift build -c release "${ARCHS[@]}" --show-bin-path)"

APP=dist/Disableton.app
rm -rf dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/en.lproj" "$APP/Contents/Resources/it.lproj"
# I menu di sistema seguono la lingua di macOS (italiano su un Mac in italiano, altrimenti inglese).
for l in en it; do printf '"CFBundleName" = "Disableton";\n' > "$APP/Contents/Resources/$l.lproj/InfoPlist.strings"; done
cp "$BIN_DIR/DisabletonApp" "$APP/Contents/MacOS/Disableton"
cp "$BIN_DIR/disableton" dist/disableton

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Disableton</string>
    <key>CFBundleDisplayName</key><string>Disableton</string>
    <key>CFBundleIdentifier</key><string>app.disableton.Disableton</string>
    <key>CFBundleExecutable</key><string>Disableton</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleLocalizations</key><array><string>en</string><string>it</string></array>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${BUILD}</string>
    <key>LSMinimumSystemVersion</key><string>12.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.music</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSHumanReadableCopyright</key><string>Disableton</string>
    <key>DisabletonCommit</key><string>${COMMIT}</string>
</dict>
</plist>
PLIST

# Firma locale (ad hoc): sufficiente per l'uso personale, non per la distribuzione.
codesign --force --sign - "$APP"
codesign --force --sign - dist/disableton

(cd dist && ditto -c -k --keepParent Disableton.app Disableton.zip && zip -q disableton-cli.zip disableton)

echo "Creati:"
lipo -info "$APP/Contents/MacOS/Disableton"
lipo -info dist/disableton
