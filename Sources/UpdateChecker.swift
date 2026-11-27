import Foundation

/// Talks to the GitHub Releases API and compares versions.
/// UI lives in `UpdateManager`; installation lives in `UpdateInstaller`.
enum UpdateChecker {

    static let latestReleaseURL = URL(
        string: "https://api.github.com/repos/niyongsheng/moler/releases/latest"
    )!
    static let releasesPageURL = URL(
        string: "https://github.com/niyongsheng/moler/releases"
    )!

    struct Release: Equatable {
        /// Version without the leading "v" (e.g. "0.2.1").
        let version: String
        /// Release page shown in the browser.
        let url: URL
        /// Universal .zip asset used for in-app updates, when the release has one.
        let zipURL: URL?

        init(version: String, url: URL, zipURL: URL? = nil) {
            self.version = version
            self.url = url
            self.zipURL = zipURL
        }
    }

    enum CheckError: LocalizedError {
        case http(Int)
        case badResponse

        var errorDescription: String? {
            switch self {
            case .http(let code): return String(format: L10n.updateHttpError, code)
            case .badResponse:    return L10n.updateResponseError
            }
        }
    }

    // MARK: - Version Comparison

    /// Numeric per-component compare; tolerates a leading "v" and ragged
    /// lengths (missing components count as 0).
    static func isNewer(_ remote: String, than local: String) -> Bool {
        MoleCLI.compareVersions(remote, local) == .orderedDescending
    }

    // MARK: - API Response Parsing

    /// Pull tag + page URL + zip asset out of a /releases/latest response.
    static func parseLatestRelease(_ data: Data) -> Release? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = obj["tag_name"] as? String,
              let urlString = obj["html_url"] as? String,
              let url = URL(string: urlString) else { return nil }
        let version = normalizedVersion(tag)
        guard !version.isEmpty else { return nil }
        let assets = obj["assets"] as? [[String: Any]] ?? []
        return Release(
            version: version,
            url: url,
            zipURL: preferredZipAsset(assets, version: version)
        )
    }

    /// Choose the universal .zip asset for in-app updates. Prefers the
    /// versioned name produced by CI (`Moler-0.2.1.zip`), then a stable
    /// `Moler.zip` alias, then any Moler*.zip asset.
    static func preferredZipAsset(_ assets: [[String: Any]], version: String) -> URL? {
        var candidates: [(name: String, url: URL)] = []
        for asset in assets {
            guard let name = asset["name"] as? String,
                  let urlString = asset["browser_download_url"] as? String,
                  let url = URL(string: urlString) else { continue }
            let lower = name.lowercased()
            guard lower.hasPrefix("moler"), lower.hasSuffix(".zip"),
                  !lower.contains("sha256"), !lower.contains("checksum") else { continue }
            candidates.append((name, url))
        }
        let versioned = "moler-\(version.lowercased()).zip"
        if let exact = candidates.first(where: { $0.name.lowercased() == versioned }) {
            return exact.url
        }
        if let stable = candidates.first(where: { $0.name.lowercased() == "moler.zip" }) {
            return stable.url
        }
        return candidates.first?.url
    }

    // MARK: - Current Version

    /// The version this build is running, from Info.plist.
    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    // MARK: - Fetching

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    /// Fetch the latest published (non-prerelease) release.
    static func fetchLatest() async throws -> Release {
        var request = URLRequest(url: latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw CheckError.http(http.statusCode)
        }
        guard let release = parseLatestRelease(data) else {
            throw CheckError.badResponse
        }
        return release
    }
}
