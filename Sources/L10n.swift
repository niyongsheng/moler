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
    /// "Scan timed out after %d minutes" — String(format: L10n.errorTimedOut, minutes)
    static let errorTimedOut = String(localized: "error.timed_out")
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

    static let overviewLoading     = String(localized: "overview.loading")
    static let overviewCpuCores    = String(localized: "overview.cpu_cores")
    static let overviewSwap        = String(localized: "overview.swap")
    static let overviewDown        = String(localized: "overview.down")
    static let overviewUp          = String(localized: "overview.up")
    static let overviewDiskRead    = String(localized: "overview.disk_read")
    static let overviewDiskWrite   = String(localized: "overview.disk_write")
    static let overviewDisk        = String(localized: "overview.disk")
    /// "FREE %@" — String(format: L10n.overviewFreeFormat, bytesString)
    static let overviewFreeFormat  = String(localized: "overview.free_format")
    /// "%d%% USED" — String(format: L10n.overviewUsedFormat, percent)
    static let overviewUsedFormat  = String(localized: "overview.used_format")

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

    // MARK: - Optimize Idle

    static let optimizeTitle     = String(localized: "optimize.title")
    static let optimizeSubtitle  = String(localized: "optimize.subtitle")
    static let optimizeLastRun   = String(localized: "optimize.last_run")
    static let optimizeTotalCount = String(localized: "optimize.total_count")
    static let optimizeTotalOpts = String(localized: "optimize.total_opts")
    static let optimizeNever     = String(localized: "optimize.never")
    static let optimizePreview   = String(localized: "optimize.preview")
    static let optimizeInitiate  = String(localized: "optimize.initiate")

    // MARK: - Optimize Running

    static let optimizeRunTitle    = String(localized: "optimize.run.title")
    static let optimizeRunStatus   = String(localized: "optimize.run.status")
    static let optimizeRunExecuting = String(localized: "optimize.run.executing")
    static let optimizeCancel      = String(localized: "optimize.cancel")
    static let optimizeDryRun      = String(localized: "optimize.dry_run")

    // MARK: - Optimize Done

    static let optimizeDoneTitle    = String(localized: "optimize.done.title")
    static let optimizeDoneSubtitle = String(localized: "optimize.done.subtitle")
    static let optimizeDonePreviewTitle = String(localized: "optimize.done.preview_title")
    static let optimizeDonePreviewSubtitle = String(localized: "optimize.done.preview_subtitle")
    static let optimizeDoneAllAreas = String(localized: "optimize.done.all_areas")
    static let optimizeDoneDuration = String(localized: "optimize.done.duration")
    static let optimizeDoneNoCategories = String(localized: "optimize.done.no_categories")
    static let optimizeDoneNewRun   = String(localized: "optimize.done.new_run")

    // MARK: - Analyze Idle

    static let analyzeTitle     = String(localized: "analyze.title")
    static let analyzeSubtitle  = String(localized: "analyze.subtitle")
    static let analyzeLastScan  = String(localized: "analyze.last_scan")
    static let analyzeLastDate  = String(localized: "analyze.last_date")
    static let analyzeTotalCount = String(localized: "analyze.total_count")
    static let analyzeNever     = String(localized: "analyze.never")
    static let analyzeScanHome  = String(localized: "analyze.scan_home")

    // MARK: - Analyze Scanning

    static let analyzeScanning  = String(localized: "analyze.scanning")
    static let analyzeCancel    = String(localized: "analyze.cancel")

    // MARK: - Analyze: Path Picker

    /// "OR" — divider between preset pills and folder picker
    static let analyzeOr = String(localized: "analyze.or")
    /// "SELECT FOLDER..."
    static let analyzeSelectFolder = String(localized: "analyze.select_folder")

    // MARK: - Software

    static let softwareTitle     = String(localized: "software.title")
    static let softwareSubtitle  = String(localized: "software.subtitle")
    static let softwareScanApps  = String(localized: "software.scan_apps")
    static let softwareLastScan  = String(localized: "software.last_scan")
    static let softwareTotalRemoved = String(localized: "software.total_removed")
    static let softwareNever     = String(localized: "software.never")
    static let softwareLoading   = String(localized: "software.loading")
    static let softwareCancel    = String(localized: "software.cancel")
    static let softwareNoApps    = String(localized: "software.no_apps")
    static let softwareRemove    = String(localized: "software.remove")
    static let softwareDeselectAll = String(localized: "software.deselect_all")
    static let softwareAutoSelected = String(localized: "software.auto_selected")
    static let softwareNeedsReview = String(localized: "software.needs_review")
    static let softwareSortedByName  = String(localized: "software.sort_name")
    static let softwareSortedBySize  = String(localized: "software.sort_size")
    static let softwareSize     = String(localized: "software.size")

    // MARK: - Software Running & Done

    static let softwareRemoving     = String(localized: "software.removing")
    static let softwareDoneTitle    = String(localized: "software.done.title")
    static let softwareDoneSubtitle = String(localized: "software.done.subtitle")
    static let softwareDoneAppsRemoved = String(localized: "software.done.apps_removed")
    static let softwareDoneBytesFreed  = String(localized: "software.done.bytes_freed")
    static let softwareDoneDuration    = String(localized: "software.done.duration")
    static let softwareDoneBack        = String(localized: "software.done.back")

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
