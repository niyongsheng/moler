import Foundation
import AppKit

/// Manual-only "Check for Updates": one GET to the GitHub Releases API,
/// compare against the running version, then point the user at the
/// release page. Never automatic, never silent — the request happens only
/// on explicit user action.
enum UpdateChecker {

    static let latestReleaseURL = URL(
        string: "https://api.github.com/repos/niyongsheng/moler/releases/latest"
    )!
    static let releasesPageURL = URL(
        string: "https://github.com/niyongsheng/moler/releases"
    )!

    struct Release {
        let version: String
        let url: URL
    }

    // MARK: - Version Comparison

    /// Numeric per-component compare; tolerates a leading "v" and ragged
    /// lengths (missing components count as 0).
    static func isNewer(_ remote: String, than local: String) -> Bool {
        func parts(_ s: String) -> [Int] {
            var t = s.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("v") || t.hasPrefix("V") { t.removeFirst() }
            return t.split(separator: ".").map { Int($0) ?? 0 }
        }
        let r = parts(remote), l = parts(local)
        for i in 0..<max(r.count, l.count) {
            let rv = i < r.count ? r[i] : 0
            let lv = i < l.count ? l[i] : 0
            if rv != lv { return rv > lv }
        }
        return false
    }

    // MARK: - API Response Parsing

    /// Pull tag + page URL out of a /releases/latest response.
    static func parseLatestRelease(_ data: Data) -> Release? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = obj["tag_name"] as? String,
              let urlString = obj["html_url"] as? String,
              let url = URL(string: urlString) else { return nil }
        var version = tag.trimmingCharacters(in: .whitespaces)
        if version.hasPrefix("v") || version.hasPrefix("V") { version.removeFirst() }
        guard !version.isEmpty else { return nil }
        return Release(version: version, url: url)
    }

    // MARK: - Current Version

    /// The version this build is running, from Info.plist.
    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    // MARK: - Main Entry Point

    /// Guards against concurrent in-flight checks.
    private static var isChecking = false

    /// Fetch the latest release, compare, and present the result via NSAlert.
    /// Called only on explicit user action — never automatically.
    static func checkNow() {
        guard !isChecking else { return }
        isChecking = true

        var request = URLRequest(url: latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                self.isChecking = false
                guard let data, error == nil, let release = parseLatestRelease(data) else {
                    presentResult(
                        title: L10n.updateError,
                        body: L10n.updateErrorBody,
                        link: releasesPageURL
                    )
                    return
                }

                if isNewer(release.version, than: currentVersion) {
                    let body = String(
                        format: L10n.updateAvailable,
                        release.version, currentVersion
                    )
                    presentResult(title: L10n.updateCheckResult, body: body, link: release.url)
                } else {
                    let body = String(
                        format: L10n.updateUpToDateBody, currentVersion
                    )
                    presentResult(
                        title: L10n.updateUpToDate,
                        body: body,
                        link: nil
                    )
                }
            }
        }.resume()
    }

    // MARK: - Alert

    private static func presentResult(title: String, body: String, link: URL?) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body
        if let link {
            alert.addButton(withTitle: L10n.updateReleasePage)
            alert.addButton(withTitle: L10n.updateClose)
        } else {
            alert.addButton(withTitle: L10n.updateClose)
        }
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn, let link {
            NSWorkspace.shared.open(link)
        }
    }
}
