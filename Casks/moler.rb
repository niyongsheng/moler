cask "moler" do
  version "0.1.0"
  sha256 :no_check

  url "https://github.com/niyongsheng/moler/releases/latest/download/Moler.dmg"
  name "Moler"
  desc "NASA-Punk themed macOS disk cleaner"
  homepage "https://github.com/niyongsheng/moler"

  depends_on macos: :sonoma

  app "Moler.app"

  zap trash: [
    "~/Library/Preferences/dev.niyongsheng.moler.plist",
    "~/Library/Caches/dev.niyongsheng.moler",
  ]
end
