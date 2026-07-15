---
name: moler-release
description: Publish a new version of Moler: build release, tag, zip/dmg, upload to GitHub, sync cask
---

# Release Checklist

Use this skill when preparing a new Moler release.

> Set the version variable at the start — substitute `0.x.0` with your actual version.

## Steps

```bash
# ── Variables ──────────────────────────────────
VERSION="0.x.0"          # e.g. "0.2.0"
BUNDLE_VERSION="x"       # e.g. "2"
TAG="v${VERSION}"

# ── 1. Update version in Resources/Info.plist ──
#    CFBundleShortVersionString → "${VERSION}"
#    CFBundleVersion → "${BUNDLE_VERSION}"

# ── 2. Regenerate + build Release ──────────────
xcodegen generate --spec project.yml
xcodebuild -project Moler.xcodeproj -scheme Moler -configuration Release build

# ── 3. Locate the built app ────────────────────
APP_DIR=~/Library/Developer/Xcode/DerivedData/Moler-*/Build/Products/Release
ls "$APP_DIR/Moler.app"

# ── 4. Package as .zip and .dmg ────────────────
cd "$APP_DIR"
zip -ry "/tmp/Moler-${VERSION}.zip" Moler.app
hdiutil create -volname Moler -srcfolder Moler.app -ov -format UDZO "/tmp/Moler.dmg"
echo "Zip: $(ls -lh /tmp/Moler-${VERSION}.zip | awk '{print $5}')"
echo "DMG: $(ls -lh /tmp/Moler.dmg | awk '{print $5}')"

# ── 5. Commit, tag and push ────────────────────
git add Resources/Info.plist
git commit -m "chore: bump version to ${VERSION}"
git tag -a "${TAG}" -m "${TAG}"
git push origin main && git push origin "${TAG}"

# ── 6. Create GitHub Release ───────────────────
gh release create "${TAG}" --repo niyongsheng/moler \
  --title "${TAG}" \
  --notes "## ${TAG}" \
  --latest

gh release upload "${TAG}" --repo niyongsheng/moler \
  "/tmp/Moler-${VERSION}.zip" \
  "/tmp/Moler.dmg" \
  --clobber

# ── 7. Sync Homebrew cask formula ──────────────
#    Fork/clone: https://github.com/niyongsheng/homebrew-moler
#    Update Casks/moler.rb:
#      - version → "${VERSION}"
#      - sha256  → run: shasum -a 256 /tmp/Moler.dmg (then paste the hash, remove :no_check)
#      - commit, tag (e.g. moler-v0.1.0), push
```

After release, users clicking "Check for Updates" in the app will detect the new version via the GitHub Releases API and be directed to the release page to download.

> **Note**: No code signing - `CODE_SIGNING_ALLOWED: NO`. Unsigned .app triggers macOS Gatekeeper. Users must allow it in System Settings → Privacy & Security.
