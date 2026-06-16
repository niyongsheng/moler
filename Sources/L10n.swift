import Foundation

/// Centralized localization keys for Moler.
/// Every user-visible string in the app routes through one of these keys.
/// English .strings file serves as the base; zh-Hans overrides where present.
///
/// Usage:
///   Text(L10n.cleanTitle)           // in SwiftUI views
///   String(localized: L10n.cleanTitle)  // for string interpolation
enum L10n {

    // MARK: - Navigation

    static let navClean      = String(localized: "nav.clean")
    static let navCleanSub   = String(localized: "nav.clean.sub")
    static let navPurge      = String(localized: "nav.purge")
    static let navPurgeSub   = String(localized: "nav.purge.sub")
    static let navOptimize   = String(localized: "nav.optimize")
    static let navOptimizeSub = String(localized: "nav.optimize.sub")
    static let navAnalyze    = String(localized: "nav.analyze")
    static let navAnalyzeSub = String(localized: "nav.analyze.sub")
    static let navOffline    = String(localized: "nav.offline")

    // MARK: - Clean Idle

    static let cleanTitle    = String(localized: "clean.title")
    static let cleanSubtitle = String(localized: "clean.subtitle")
    static let cleanLastScan = String(localized: "clean.last_scan")
    static let cleanLastClean = String(localized: "clean.last_clean")
    static let cleanTotalFreed = String(localized: "clean.total_freed")
    static let cleanCleanCount = String(localized: "clean.clean_count")
    static let cleanNever    = String(localized: "clean.never")
    static let cleanInitiate = String(localized: "clean.initiate")

    // MARK: - Clean Scanning

    static let cleanScanning = String(localized: "clean.scanning")
    static let cleanScanningHint = String(localized: "clean.scanning.hint")
    static let cleanScanningWait = String(localized: "clean.scanning.wait")
    static let cleanElapsed   = String(localized: "clean.scanning.elapsed")
    static let cleanFiles    = String(localized: "clean.files")
    static let cleanSize     = String(localized: "clean.size")

    // MARK: - Clean Review

    static let cleanReviewTitle    = String(localized: "clean.review.title")
    static let cleanReviewSubtitle = String(localized: "clean.review.subtitle")
    static let cleanReviewScanPath = String(localized: "clean.review.scan_path")
    static let cleanReviewTotalSize = String(localized: "clean.review.total_size")
    static let cleanReviewTotalFiles = String(localized: "clean.review.total_files")
    static let cleanReviewSelected = String(localized: "clean.review.selected")
    static let cleanReviewSelectAll = String(localized: "clean.review.select_all")
    static let cleanReviewDeselectAll = String(localized: "clean.review.deselect_all")
    static let cleanReviewNoFiles = String(localized: "clean.review.no_files")
    static let cleanReviewBack    = String(localized: "clean.review.back")
    static let cleanReviewExecute = String(localized: "clean.review.execute")

    /// "N files selected" — use String(format: L10n.cleanReviewFilesSelected, count)
    static let cleanReviewFilesSelected = String(localized: "clean.review.files_selected")

    // MARK: - Clean Running

    static let cleanRunTitle    = String(localized: "clean.run.title")
    static let cleanRunSubtitle = String(localized: "clean.run.subtitle")
    static let cleanRunStatus   = String(localized: "clean.run.status")
    static let cleanRunExecuting = String(localized: "clean.run.executing")
    static let cleanRunInit     = String(localized: "clean.run.init")

    // MARK: - Clean Done

    static let cleanDoneTitle    = String(localized: "clean.done.title")
    static let cleanDoneSubtitle = String(localized: "clean.done.subtitle")
    static let cleanDoneSpaceFreed = String(localized: "clean.done.space_freed")
    static let cleanDoneFilesRemoved = String(localized: "clean.done.files_removed")
    static let cleanDoneNewScan  = String(localized: "clean.done.new_scan")

    // MARK: - Errors

    static let errorDismiss = String(localized: "error.dismiss")
    static let errorMoNotFound = String(localized: "error.mo_not_found")
    /// "mo exited with code %d: %@" — String(format: L10n.errorMoFailed, code, stderr)
    static let errorMoFailed = String(localized: "error.mo_failed")
    /// "Failed to parse mo output: %@" — String(format: L10n.errorParseFailed, msg)
    static let errorParseFailed = String(localized: "error.parse_failed")

    // MARK: - Privacy

    static let privacyTitle = String(localized: "privacy.title")
    static let privacyMessage = String(localized: "privacy.message")
    static let privacyOpenSettings = String(localized: "privacy.open_settings")
    static let privacyLater = String(localized: "privacy.later")

    // MARK: - Settings

    static let settingsWindowTitle = String(localized: "settings.title")
    static let settingsGeneral     = String(localized: "settings.general")
    static let settingsLanguage    = String(localized: "settings.language")
    static let settingsLanguageSystem = String(localized: "settings.language.system")
    static let settingsRestartNote = String(localized: "settings.restart_note")

    // MARK: - Settings: Permissions

    static let settingsPermissions   = String(localized: "settings.permissions")
    static let settingsFDATitle      = String(localized: "settings.fda.title")
    static let settingsFDAGranted    = String(localized: "settings.fda.granted")
    static let settingsFDANotGranted = String(localized: "settings.fda.not_granted")
    static let settingsFDAAction     = String(localized: "settings.fda.action")

    // MARK: - Settings: About

    static let settingsAbout         = String(localized: "settings.about")
    static let settingsVersion       = String(localized: "settings.version")
}
