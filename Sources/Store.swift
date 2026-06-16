import Foundation

/// UserDefaults-backed settings store for Moler.
/// All values are typed, clamped, and have sensible defaults.
@MainActor
final class Store: ObservableObject {
    static let shared = Store()

    private let defaults = UserDefaults.standard

    // MARK: - Keys

    private enum Key {
        static let hasOnboarded       = "moler.hasOnboarded"
        static let language           = "AppleLanguages"
        static let lastScanPath       = "moler.lastScanPath"
        static let lastCleanDate      = "moler.lastCleanDate"
        static let totalFreedBytes    = "moler.totalFreedBytes"
        static let totalCleanCount    = "moler.totalCleanCount"
        static let lastPurgeDate      = "moler.lastPurgeDate"
        static let totalPurgeFreedBytes = "moler.totalPurgeFreedBytes"
        static let totalPurgeCount    = "moler.totalPurgeCount"
    }

    // MARK: - Published Values

    /// Whether the user has completed the onboarding flow.
    @Published var hasOnboarded: Bool {
        didSet { defaults.set(hasOnboarded, forKey: Key.hasOnboarded) }
    }

    /// Current app language. Uses `AppleLanguages` so a restart is required
    /// for the change to fully take effect system-wide.
    /// - `""` — follow system language (key removed from UserDefaults)
    /// - `"zh-Hans"` — Simplified Chinese
    /// - `"en"` — English
    @Published var language: String {
        didSet { persistLanguage() }
    }

    private func persistLanguage() {
        if language.isEmpty {
            defaults.removeObject(forKey: Key.language)
        } else {
            defaults.set([language], forKey: Key.language)
        }
    }

    /// Display name for the current language setting.
    var languageDisplayName: String {
        switch language {
        case "zh-Hans": return "中文"
        case "en":      return "English"
        default:        return "跟随系统"
        }
    }

    /// Cycle: Follow System → 中文 → English → Follow System
    func toggleLanguage() {
        switch language {
        case "zh-Hans": language = "en"
        case "en":      language = ""
        default:        language = "zh-Hans"
        }
    }

    /// The last directory that was scanned.
    @Published var lastScanPath: String {
        didSet { defaults.set(lastScanPath, forKey: Key.lastScanPath) }
    }

    /// Timestamp of the most recent clean operation.
    @Published var lastCleanDate: Date? {
        didSet { defaults.set(lastCleanDate, forKey: Key.lastCleanDate) }
    }

    /// Cumulative bytes freed across all clean operations.
    @Published var totalFreedBytes: Int64 {
        didSet { defaults.set(totalFreedBytes, forKey: Key.totalFreedBytes) }
    }

    /// Total number of clean operations performed.
    @Published var totalCleanCount: Int {
        didSet { defaults.set(totalCleanCount, forKey: Key.totalCleanCount) }
    }

    /// Timestamp of the most recent purge operation — separate from lastCleanDate.
    @Published var lastPurgeDate: Date? {
        didSet { defaults.set(lastPurgeDate, forKey: Key.lastPurgeDate) }
    }

    /// Cumulative bytes freed across all purge operations.
    @Published var totalPurgeFreedBytes: Int64 {
        didSet { defaults.set(totalPurgeFreedBytes, forKey: Key.totalPurgeFreedBytes) }
    }

    /// Total number of purge operations performed.
    @Published var totalPurgeCount: Int {
        didSet { defaults.set(totalPurgeCount, forKey: Key.totalPurgeCount) }
    }

    // MARK: - Init

    private init() {
        self.hasOnboarded = defaults.bool(forKey: Key.hasOnboarded)

        // Language: read the first preferred language from AppleLanguages.
        // Normalise: the system may store "zh-Hans-CN" but we only use "zh-Hans".
        // Use _language (no didSet) to avoid persisting the same value on init.
        let raw = defaults.stringArray(forKey: Key.language)?.first ?? ""
        let normalised: String
        if raw.hasPrefix("zh-Hans") {
            normalised = "zh-Hans"
        } else if raw.hasPrefix("en") {
            normalised = "en"
        } else {
            normalised = ""
        }
        self._language = Published(initialValue: normalised)

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        self.lastScanPath = defaults.string(forKey: Key.lastScanPath) ?? home

        self.lastCleanDate = defaults.object(forKey: Key.lastCleanDate) as? Date

        // totalFreedBytes as Int64: UserDefaults stores numbers as NSNumber;
        // reading as Int gives 0 for Int64 values. Use object(forKey:) + cast.
        if let num = defaults.object(forKey: Key.totalFreedBytes) as? NSNumber {
            self.totalFreedBytes = num.int64Value
        } else {
            self.totalFreedBytes = 0
        }

        self.totalCleanCount = defaults.integer(forKey: Key.totalCleanCount)

        self.lastPurgeDate = defaults.object(forKey: Key.lastPurgeDate) as? Date

        if let num = defaults.object(forKey: Key.totalPurgeFreedBytes) as? NSNumber {
            self.totalPurgeFreedBytes = num.int64Value
        } else {
            self.totalPurgeFreedBytes = 0
        }

        self.totalPurgeCount = defaults.integer(forKey: Key.totalPurgeCount)
    }

    // MARK: - Actions

    /// Record a successful clean operation.
    func recordClean(freedBytes: Int64, filesRemoved: Int) {
        totalFreedBytes += freedBytes
        totalCleanCount += 1
        lastCleanDate = Date()
    }

    /// Record a successful purge operation (separate from clean counters).
    func recordPurge(freedBytes: Int64, itemsRemoved: Int) {
        totalPurgeFreedBytes += freedBytes
        totalPurgeCount += 1
        lastPurgeDate = Date()
    }
}
