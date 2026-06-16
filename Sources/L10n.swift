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
    static let navSoftware   = String(localized: "nav.software")
    static let navSoftwareSub = String(localized: "nav.software.sub")
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
    static let cleanCancel   = String(localized: "clean.cancel")
    static let cleanStop     = String(localized: "clean.stop")

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

    // MARK: - Install

    static let installTitle     = String(localized: "install.title")
    static let installMessage   = String(localized: "install.message")
    static let installSubtitle  = String(localized: "install.subtitle")
    static let installCopy      = String(localized: "install.copy")
    static let installCopied    = String(localized: "install.copied")
    static let installRecheck   = String(localized: "install.recheck")
    static let installChecking  = String(localized: "install.checking")
    static let installStillMissing = String(localized: "install.still_missing")
    static let installOtherOptions = String(localized: "install.other_options")
    static let installQuit      = String(localized: "install.quit")
    // MARK: - Privacy

    static let privacyTitle = String(localized: "privacy.title")
    static let privacyMessage = String(localized: "privacy.message")
    static let privacyOpenSettings = String(localized: "privacy.open_settings")
    static let privacyLater = String(localized: "privacy.later")

    // MARK: - Overview

    static let overviewTitle       = String(localized: "overview.title")
    static let overviewSubtitle    = String(localized: "overview.subtitle")
    static let overviewTotalFreed  = String(localized: "overview.total_freed")
    static let overviewCleanCount  = String(localized: "overview.clean_count")
    static let overviewLastClean   = String(localized: "overview.last_clean")
    static let overviewLastScan    = String(localized: "overview.last_scan")
    static let overviewDiskCapacity = String(localized: "overview.disk_capacity")
    static let overviewDiskFree    = String(localized: "overview.disk_free")
    static let overviewDiskUsage   = String(localized: "overview.disk_usage")
    static let overviewQuickScan   = String(localized: "overview.quick_scan")
    static let overviewQuickSettings = String(localized: "overview.quick_settings")

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

    // MARK: - Purge Idle

    static let purgeTitle     = String(localized: "purge.title")
    static let purgeSubtitle  = String(localized: "purge.subtitle")
    static let purgeScanPath  = String(localized: "purge.scan_path")
    static let purgeInitiate  = String(localized: "purge.initiate")

    // MARK: - Purge Scanning

    static let purgeScanning      = String(localized: "purge.scanning")
    static let purgeScanningHint  = String(localized: "purge.scanning.hint")
    static let purgeCancel        = String(localized: "purge.cancel")
    static let purgeStop          = String(localized: "purge.stop")

    // MARK: - Purge Review

    static let purgeReviewTitle   = String(localized: "purge.review.title")
    static let purgeReviewTotal   = String(localized: "purge.review.total")
    static let purgeReviewExecute = String(localized: "purge.review.execute")

    // MARK: - Purge Running

    static let purgeRunTitle      = String(localized: "purge.run.title")
    static let purgeRunSubtitle   = String(localized: "purge.run.subtitle")
    static let purgeRunStatus     = String(localized: "purge.run.status")
    static let purgeRunExecuting  = String(localized: "purge.run.executing")
    static let purgeRunInit       = String(localized: "purge.run.init")

    // MARK: - Purge Done

    static let purgeDoneTitle       = String(localized: "purge.done.title")
    static let purgeDoneSubtitle    = String(localized: "purge.done.subtitle")
    static let purgeDoneSpaceFreed  = String(localized: "purge.done.space_freed")
    static let purgeDoneItemsRemoved = String(localized: "purge.done.items_removed")
    static let purgeDoneNewScan     = String(localized: "purge.done.new_scan")

    // MARK: - Settings: About

    static let settingsAbout         = String(localized: "settings.about")
    static let settingsVersion       = String(localized: "settings.version")

    // MARK: - Update

    static let updateCheck        = String(localized: "update.check")
    static let updateCheckResult  = String(localized: "update.check_result")
    static let updateUpToDate     = String(localized: "update.up_to_date")
    /// "Moler %@ is the latest release." — String(format: L10n.updateUpToDateBody, version)
    static let updateUpToDateBody = String(localized: "update.up_to_date_body")
    /// "Moler %@ is available (you have %@). Download it from the release page."
    static let updateAvailable    = String(localized: "update.available")
    static let updateError        = String(localized: "update.error")
    /// "GitHub didn't answer. Try again later, or open the releases page."
    static let updateErrorBody    = String(localized: "update.error_body")
    static let updateReleasePage  = String(localized: "update.release_page")
    static let updateClose        = String(localized: "update.close")
}
