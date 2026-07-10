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

        static let lastOptimizeDate            = "moler.lastOptimizeDate"
        static let totalOptimizeCount          = "moler.totalOptimizeCount"
        static let lastOptimizeOptimizations   = "moler.lastOptimizeOptimizations"

        static let lastSoftwareDate        = "moler.lastSoftwareDate"
        static let totalSoftwareRemoved    = "moler.totalSoftwareRemoved"
        static let totalSoftwareBytesFreed = "moler.totalSoftwareBytesFreed"

        static let lastAnalyzePath   = "moler.lastAnalyzePath"
        static let lastAnalyzeDate   = "moler.lastAnalyzeDate"
        static let totalAnalyzeCount = "moler.totalAnalyzeCount"
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
        case "zh-Hans": return "简体中文"
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

    /// Timestamp of the most recent optimize operation.
    @Published var lastOptimizeDate: Date? {
        didSet { defaults.set(lastOptimizeDate, forKey: Key.lastOptimizeDate) }
    }

    /// Total number of optimize operations performed.
    @Published var totalOptimizeCount: Int {
        didSet { defaults.set(totalOptimizeCount, forKey: Key.totalOptimizeCount) }
    }

    /// Number of optimizations applied in the last optimize run.
    @Published var lastOptimizeOptimizations: Int {
        didSet { defaults.set(lastOptimizeOptimizations, forKey: Key.lastOptimizeOptimizations) }
    }

    /// Timestamp of the most recent software uninstall.
    @Published var lastSoftwareDate: Date? {
        didSet { defaults.set(lastSoftwareDate, forKey: Key.lastSoftwareDate) }
    }

    /// Total number of apps removed by the Software tab.
    @Published var totalSoftwareRemoved: Int {
        didSet { defaults.set(totalSoftwareRemoved, forKey: Key.totalSoftwareRemoved) }
    }

    /// Cumulative bytes freed by app uninstalls.
    @Published var totalSoftwareBytesFreed: Int64 {
        didSet { defaults.set(totalSoftwareBytesFreed, forKey: Key.totalSoftwareBytesFreed) }
    }

    /// The last directory analysed.
    @Published var lastAnalyzePath: String {
        didSet { defaults.set(lastAnalyzePath, forKey: Key.lastAnalyzePath) }
    }

    /// Timestamp of the most recent analyse operation.
    @Published var lastAnalyzeDate: Date? {
        didSet { defaults.set(lastAnalyzeDate, forKey: Key.lastAnalyzeDate) }
    }

    /// Total number of analyse operations performed.
    @Published var totalAnalyzeCount: Int {
        didSet { defaults.set(totalAnalyzeCount, forKey: Key.totalAnalyzeCount) }
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

        self.lastOptimizeDate = defaults.object(forKey: Key.lastOptimizeDate) as? Date
        self.totalOptimizeCount = defaults.integer(forKey: Key.totalOptimizeCount)
        self.lastOptimizeOptimizations = defaults.integer(forKey: Key.lastOptimizeOptimizations)

        self.lastSoftwareDate = defaults.object(forKey: Key.lastSoftwareDate) as? Date
        self.totalSoftwareRemoved = defaults.integer(forKey: Key.totalSoftwareRemoved)
        if let num = defaults.object(forKey: Key.totalSoftwareBytesFreed) as? NSNumber {
            self.totalSoftwareBytesFreed = num.int64Value
        } else {
            self.totalSoftwareBytesFreed = 0
        }

        self.lastAnalyzePath = defaults.string(forKey: Key.lastAnalyzePath) ?? home
        self.lastAnalyzeDate = defaults.object(forKey: Key.lastAnalyzeDate) as? Date
        self.totalAnalyzeCount = defaults.integer(forKey: Key.totalAnalyzeCount)
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

    /// Record a successful optimize operation.
    func recordOptimize(optimizationsApplied: Int) {
        totalOptimizeCount += 1
        lastOptimizeDate = Date()
        lastOptimizeOptimizations = optimizationsApplied
    }

    /// Record a successful analyse operation.
    func recordAnalyze(path: String) {
        totalAnalyzeCount += 1
        lastAnalyzeDate = Date()
        lastAnalyzePath = path
    }

    /// Record a successful software uninstall operation.
    func recordSoftwareUninstall(appsRemoved: Int, bytesFreed: Int64) {
        totalSoftwareRemoved += appsRemoved
        totalSoftwareBytesFreed += bytesFreed
        lastSoftwareDate = Date()
    }
}
