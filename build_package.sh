#!/bin/bash

# Mac Setup Buddy - Package Builder
# Builds the app and creates an unsigned PKG for internal testing.

set -euo pipefail

APP_NAME="Mac Setup Buddy"
SCHEME="Mac Setup Buddy"
PROJECT="Mac Setup Buddy.xcodeproj"
CONFIGURATION="${CONFIGURATION:-Release}"
VERSION="${VERSION:-1.2.0}"
IDENTIFIER="com.sebastiansantos.mac-setup-buddy"
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
DERIVED_DATA="$ROOT_DIR/build/DerivedData"
OUTPUT_DIR="$ROOT_DIR/dist"
PKG_NAME="MacSetupBuddy_v${VERSION}_$(date +%Y%m%d).pkg"
APP_PATH="$DERIVED_DATA/Build/Products/$CONFIGURATION/$APP_NAME.app"

echo "================================================"
echo "Mac Setup Buddy - Package Builder"
echo "Version: $VERSION"
echo "Configuration: $CONFIGURATION"
echo "================================================"

echo "Building app..."
xcodebuild \
  -project "$ROOT_DIR/$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA" \
  build \
  CODE_SIGNING_ALLOWED="${CODE_SIGNING_ALLOWED:-NO}" \
  ENABLE_USER_SCRIPT_SANDBOXING="${ENABLE_USER_SCRIPT_SANDBOXING:-NO}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "ERROR: Application not found at:"
  echo "  $APP_PATH"
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

BUILD_DIR="$(mktemp -d)"
PAYLOAD_DIR="$BUILD_DIR/payload"
SCRIPTS_DIR="$BUILD_DIR/scripts"

cleanup() {
  rm -rf "$BUILD_DIR"
}
trap cleanup EXIT

mkdir -p "$PAYLOAD_DIR/Applications/Utilities"
mkdir -p "$SCRIPTS_DIR"

echo "Copying application..."
cp -R "$APP_PATH" "$PAYLOAD_DIR/Applications/Utilities/"

cat > "$SCRIPTS_DIR/postinstall" << 'POSTINSTALL'
#!/bin/bash

echo "Configuring Mac Setup Buddy..."

chown -R root:wheel "/Applications/Utilities/Mac Setup Buddy.app"
chmod -R 755 "/Applications/Utilities/Mac Setup Buddy.app"

mkdir -p /Library/Management/Banner
mkdir -p /Library/Management/Logs
chmod 755 /Library/Management
chmod 755 /Library/Management/Banner
chmod 755 /Library/Management/Logs

echo "Mac Setup Buddy installed to: /Applications/Utilities/Mac Setup Buddy.app"
exit 0
POSTINSTALL

chmod +x "$SCRIPTS_DIR/postinstall"

cat > "$SCRIPTS_DIR/preinstall" << 'PREINSTALL'
#!/bin/bash

OS_MAJOR_VERSION="$(sw_vers -productVersion | cut -d. -f1)"
if [[ "$OS_MAJOR_VERSION" -lt 13 ]]; then
  echo "ERROR: Requires macOS 13.0 or later"
  exit 1
fi

echo "System requirements verified"
exit 0
PREINSTALL

chmod +x "$SCRIPTS_DIR/preinstall"

echo "Building package..."
pkgbuild \
  --root "$PAYLOAD_DIR" \
  --scripts "$SCRIPTS_DIR" \
  --identifier "$IDENTIFIER" \
  --version "$VERSION" \
  --install-location / \
  "$OUTPUT_DIR/$PKG_NAME"

cat > "$OUTPUT_DIR/README.txt" << README
Mac Setup Buddy - Installation Package
=====================================

Installation:
1. Install the package manually or with:
   sudo installer -pkg "$PKG_NAME" -target /

Installed location:
- /Applications/Utilities/Mac Setup Buddy.app

Created:
- /Library/Management/Banner
- /Library/Management/Logs

Build:
- Version: $VERSION
- Configuration: $CONFIGURATION
README

echo ""
echo "Package created:"
echo "  $OUTPUT_DIR/$PKG_NAME"
