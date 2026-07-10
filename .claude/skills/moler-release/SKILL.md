---
name: moler-release
description: Publish a new version of Moler: build release, tag, zip, upload to GitHub
---

# Release Checklist

Use this skill when preparing a new Moler release.

## Steps

```bash
# 1. Update version in Resources/Info.plist
#    CFBundleShortVersionString → "0.2.0"
#    CFBundleVersion → "2"

# 2. Regenerate + build Release
xcodegen generate --spec project.yml
xcodebuild -project Moler.xcodeproj -scheme Moler -configuration Release build

# 3. Package the .app as zip
cd ~/Library/Developer/Xcode/DerivedData/Moler-*/Build/Products/Release/
zip -ry /tmp/Moler-0.2.0.zip Moler.app

# 4. Tag and push
git tag -a v0.2.0 -m "v0.2.0"
git push origin v0.2.0

# 5. Create GitHub Release at https://github.com/niyongsheng/moler/releases
#    Tag: v0.2.0, upload Moler-0.2.0.zip
```

After release, users clicking "Check for Updates" in the app will detect the new version via the GitHub Releases API and be directed to the release page to download.

> **Note**: No code signing - `CODE_SIGNING_ALLOWED: NO`. Unsigned .app triggers macOS Gatekeeper. Users must allow it in System Settings → Privacy & Security.
