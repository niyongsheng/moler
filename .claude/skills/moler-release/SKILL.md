---
name: moler-release
description: Publish a new version of Moler: bump version, build, tag, push (CI handles packaging)
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

# ── 2. Regenerate + build Release (verify it compiles) ──
xcodegen generate --spec project.yml
xcodebuild -project Moler.xcodeproj -scheme Moler -configuration Release build

# ── 3. Commit, tag and push ────────────────────
git add Resources/Info.plist project.yml
git commit -m "chore: bump version to ${VERSION}"
git tag -a "${TAG}" -m "${TAG}"
git push origin main && git push origin "${TAG}"

# ════════════════════════════════════════════════════
# CI (.github/workflows/ci.yml) handles packaging:
#   - Builds a universal Release (arm64 + x86_64) on macos-15
#   - Ad-hoc signs the app, then creates PKG, DMG and ZIP
#   - PKG installs to /Applications and its postinstall clears quarantine
#   - Uploads to GitHub Release as:
#       Moler-${VERSION}-mac-universal.pkg
#       Moler-${VERSION}.dmg
#       Moler-${VERSION}.zip
#       Moler.pkg   ← stable alias used by docs/index.html:
#                     https://github.com/niyongsheng/moler/releases/latest/download/Moler.pkg
#       Moler.zip   ← stable alias for in-app auto-update (the updater
#                     prefers the versioned zip from the API response)
#     Keep the Moler.pkg asset name stable — the landing page's download
#     button hardcodes it.
# ════════════════════════════════════════════════════

# ── 4. Wait for CI to finish, then sync cask ───
#    Fork/clone: https://github.com/niyongsheng/homebrew-moler
#    Download the CI-built DMG from the release:
gh release download "${TAG}" --repo niyongsheng/moler --pattern "Moler-${VERSION}.dmg"

#    Compute sha256
sha256=$(sha256sum "Moler-${VERSION}.dmg" | awk '{print $1}')
echo "sha256 = ${sha256}"

#    Update Casks/moler.rb:
#      - version → "${VERSION}"
#      - sha256  → "${sha256}"
#      - url     → "https://github.com/niyongsheng/moler/releases/download/${TAG}/Moler-${VERSION}.dmg"
#      - commit, tag (e.g. moler-v0.1.0), push

# ── 5. Clean up ────────────────────────────────
rm -f "Moler-${VERSION}.dmg"
```

After release, running apps detect the new version via the GitHub Releases API — automatically at launch (at most once a day, silent) and from Settings → "Check for Updates". A newer release shows an "Install Update" button: the app downloads the `.zip` asset, verifies the bundle identifier, version and ad-hoc signature, then swaps the bundle in place (asking for an admin password when installed in `/Applications` via the pkg) and relaunches.

> **Note**: No code signing — `CODE_SIGNING_ALLOWED: NO`. Unsigned .app triggers macOS Gatekeeper. Users must allow it in System Settings → Privacy & Security. Auto-update only offers in-app installation when the app lives in `/Applications` or `~/Applications`; other copies fall back to the release page.
