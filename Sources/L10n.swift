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
    static let navPurge      = String(localized: "nav.purge")
    static let navOptimize   = String(localized: "nav.optimize")
    static let navAnalyze    = String(localized: "nav.analyze")
    static let navSoftware   = String(localized: "nav.software")

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
    static let cleanElapsed   = String(localized: "clean.scanning.elapsed")
    static let cleanFiles    = String(localized: "clean.files")
    static let cleanSize     = String(localized: "clean.size")
    static let cleanSections = String(localized: "clean.sections")
    static let cleanCancel   = String(localized: "clean.cancel")
    static let cleanStop     = String(localized: "clean.stop")

    // MARK: - Clean Review

    static let cleanReviewTitle    = String(localized: "clean.review.title")
    static let cleanReviewSubtitle = String(localized: "clean.review.subtitle")
    static let cleanReviewTotalSize = String(localized: "clean.review.total_size")
    static let cleanReviewTotalFiles = String(localized: "clean.review.total_files")
    static let cleanReviewSelectAll = String(localized: "clean.review.select_all")
    static let cleanReviewDeselectAll = String(localized: "clean.review.deselect_all")
    static let cleanReviewNoFiles = String(localized: "clean.review.no_files")
    static let cleanReviewExecute = String(localized: "clean.review.execute")
    static let cleanReviewCategories = String(localized: "clean.review.categories")
    static let cleanReviewCleanable = String(localized: "clean.review.cleanable")
    static let cleanReviewItems = String(localized: "clean.review.items")
    static let cleanReviewSkippedNote = String(localized: "clean.review.skipped_note")
    static let cleanReviewSudoHint = String(localized: "clean.review.sudo_hint")
    static let cleanReviewDetailedList = String(localized: "clean.review.detailed_list")
    static let cleanReviewReveal = String(localized: "clean.review.reveal")

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
    static let cleanDonePartialNote = String(localized: "clean.done.partial_note")
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
    /// "mo exited with code %d" — String(format: L10n.errorMoExitCode, code)
    static let errorMoExitCode = String(localized: "error.mo_exit_code")

    // MARK: - Relative Date

    static let relativeNever = String(localized: "relative.never")
    static let relativeJustNow = String(localized: "relative.just_now")
    /// "%dm ago" — String(format: L10n.relativeMinutesAgo, minutes)
    static let relativeMinutesAgo = String(localized: "relative.minutes_ago")
    /// "%dh ago" — String(format: L10n.relativeHoursAgo, hours)
    static let relativeHoursAgo = String(localized: "relative.hours_ago")
    /// "%dd ago" — String(format: L10n.relativeDaysAgo, days)
    static let relativeDaysAgo = String(localized: "relative.days_ago")

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
    static let overviewHealth      = String(localized: "overview.health")
    static let overviewHealthExcellent = String(localized: "overview.health_excellent")
    static let overviewHealthGood  = String(localized: "overview.health_good")
    static let overviewHealthFair  = String(localized: "overview.health_fair")
    static let overviewHealthAttention = String(localized: "overview.health_attention")
    static let overviewLive        = String(localized: "overview.live")
    static let overviewUptime      = String(localized: "overview.uptime")
    static let overviewLoad        = String(localized: "overview.load")
    static let overviewBatteryCharging = String(localized: "overview.battery_charging")
    static let overviewBatteryDischarging = String(localized: "overview.battery_discharging")
    static let overviewBatteryAC = String(localized: "overview.battery_ac")
    static let overviewTotalFreed  = String(localized: "overview.total_freed")

    static let overviewLoading     = String(localized: "overview.loading")
    static let overviewCpuCores    = String(localized: "overview.cpu_cores")
    static let overviewSwap        = String(localized: "overview.swap")
    static let overviewDisk        = String(localized: "overview.disk")
    static let overviewDiskPurgeable = String(localized: "overview.disk_purgeable")
    static let overviewDiskTrash   = String(localized: "overview.disk_trash")
    static let overviewDiskSmart   = String(localized: "overview.disk_smart")
    static let overviewProxy       = String(localized: "overview.proxy")
    static let overviewPanelProcesses = String(localized: "overview.panel_processes")
    static let overviewPanelBluetooth = String(localized: "overview.panel_bluetooth")
    static let overviewActivity    = String(localized: "overview.activity")
    static let overviewActivityEmpty = String(localized: "overview.activity_empty")
    /// "FREE %@" — String(format: L10n.overviewFreeFormat, bytesString)
    static let overviewFreeFormat  = String(localized: "overview.free_format")
    /// "%d%% USED" — String(format: L10n.overviewUsedFormat, percent)
    static let overviewUsedFormat  = String(localized: "overview.used_format")

    // MARK: - Overview Panel Titles

    static let overviewPanelCpu     = String(localized: "overview.panel_cpu")
    static let overviewPanelMemory  = String(localized: "overview.panel_memory")
    static let overviewPanelNetwork  = String(localized: "overview.panel_network")
    static let overviewPanelBattery   = String(localized: "overview.panel_battery")
    static let overviewBatteryCharged = String(localized: "overview.battery_charged")

    // MARK: - Settings

    static let settingsWindowTitle = String(localized: "settings.title")
    static let settingsSubtitle    = String(localized: "settings.subtitle")
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
    static let purgeInitiate  = String(localized: "purge.initiate")
    static let purgePathsDefaults = String(localized: "purge.paths.defaults")
    static let purgePathsCustom = String(localized: "purge.paths.custom")
    static let purgePathsShared = String(localized: "purge.paths.shared")
    static let purgePathsSectionDefaults = String(localized: "purge.paths.section_defaults")
    static let purgePathsSectionCustom = String(localized: "purge.paths.section_custom")
    static let purgePathsAdd = String(localized: "purge.paths.add")
    static let purgePathsRemove = String(localized: "purge.paths.remove")
    /// "Could not save purge paths: %@" — String(format: L10n.purgePathsSaveError, message)
    static let purgePathsSaveError = String(localized: "purge.paths.save_error")
    static let purgePickerMessage = String(localized: "purge.picker.message")
    static let purgePickerPrompt = String(localized: "purge.picker.prompt")
    /// "%d/%d selected" — String(format: L10n.purgeSelectedCount, selected, total)
    static let purgeSelectedCount = String(localized: "purge.selected_count")

    // MARK: - Purge Scanning

    static let purgeScanning      = String(localized: "purge.scanning")
    static let purgeScanningHint  = String(localized: "purge.scanning.hint")
    static let purgeCancel        = String(localized: "purge.cancel")

    // MARK: - Purge Review

    static let purgeReviewTitle   = String(localized: "purge.review.title")
    static let purgeReviewTotal   = String(localized: "purge.review.total")
    static let purgeReviewExecute = String(localized: "purge.review.execute")
    static let purgeReviewPaths   = String(localized: "purge.review.paths")
    static let purgeReviewItems   = String(localized: "purge.review.items")
    static let purgeReviewEmpty   = String(localized: "purge.review.empty")
    static let purgeReviewNote    = String(localized: "purge.review.note")
    /// "%d cloud-synced artifacts are skipped in unattended mode…"
    static let purgeReviewCloudNote = String(localized: "purge.review.cloud_note")

    // MARK: - Purge Running

    static let purgeRunTitle      = String(localized: "purge.run.title")
    static let purgeRunSubtitle   = String(localized: "purge.run.subtitle")
    static let purgeRunExecuting  = String(localized: "purge.run.executing")

    // MARK: - Purge Done

    static let purgeDoneTitle       = String(localized: "purge.done.title")
    static let purgeDoneSubtitle    = String(localized: "purge.done.subtitle")
    static let purgeDoneSpaceFreed  = String(localized: "purge.done.space_freed")
    static let purgeDoneItemsRemoved = String(localized: "purge.done.items_removed")
    static let purgeDoneFailed      = String(localized: "purge.done.failed")
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
    static let optimizeDoneUnchanged = String(localized: "optimize.done.unchanged")
    static let optimizeDoneSkipped = String(localized: "optimize.done.skipped")
    static let optimizeDoneUnavailable = String(localized: "optimize.done.unavailable")
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
    static let analyzePresetHome = String(localized: "analyze.preset.home")
    static let analyzePresetDesktop = String(localized: "analyze.preset.desktop")
    static let analyzePresetDocuments = String(localized: "analyze.preset.documents")
    static let analyzePresetDownloads = String(localized: "analyze.preset.downloads")
    static let analyzePresetCaches = String(localized: "analyze.preset.caches")

    // MARK: - Analyze: Loaded

    /// "RE-ANALYZE" — button to return from treemap result to idle page
    static let analyzeNewAnalysis = String(localized: "analyze.new_analysis")
    static let analyzeSidebarTarget = String(localized: "analyze.sidebar.target")
    static let analyzeSidebarEntries = String(localized: "analyze.sidebar.entries")
    static let analyzeSidebarPath = String(localized: "analyze.sidebar.path")
    static let analyzeSidebarSize = String(localized: "analyze.sidebar.size")
    static let analyzeSidebarFiles = String(localized: "analyze.sidebar.files")
    static let analyzeTreemapReveal = String(localized: "analyze.treemap.reveal")
    /// "Other (%d items)" — String(format: L10n.analyzeTreemapOther, count)
    static let analyzeTreemapOther = String(localized: "analyze.treemap.other")

    // MARK: - Analyze Scanning

    static let analyzeScanning  = String(localized: "analyze.scanning")
    static let analyzeCancel    = String(localized: "analyze.cancel")

    // MARK: - Analyze: Path Picker

    /// "OR" — divider between preset pills and folder picker
    static let analyzeOr = String(localized: "analyze.or")
    /// "SELECT FOLDER..."
    static let analyzeSelectFolder = String(localized: "analyze.select_folder")
    static let analyzePickerMessage = String(localized: "analyze.picker.message")
    static let analyzePickerPrompt = String(localized: "analyze.picker.prompt")

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
    static let softwareConfirmTitle = String(localized: "software.confirm_title")
    /// "Remove %d selected application(s)? This action cannot be undone."
    static let softwareConfirmMessage = String(localized: "software.confirm_message")
    /// "%d apps · %@" — String(format: L10n.softwareSelectionCount, count, bytes)
    static let softwareSelectionCount = String(localized: "software.selection_count")
    static let softwareLoadingPreview = String(localized: "software.loading_preview")

    // MARK: - Software Running & Done

    static let softwareRemoving     = String(localized: "software.removing")
    static let softwareDoneTitle    = String(localized: "software.done.title")
    static let softwareDoneSubtitle = String(localized: "software.done.subtitle")
    static let softwareDoneAppsRemoved = String(localized: "software.done.apps_removed")
    static let softwareDoneBytesFreed  = String(localized: "software.done.bytes_freed")
    static let softwareDoneDuration    = String(localized: "software.done.duration")
    static let softwareDoneBack        = String(localized: "software.done.back")
    static let softwareDoneFailedTitle = String(localized: "software.done.failed_title")
    static let softwareDoneFailedSubtitle = String(localized: "software.done.failed_subtitle")
    static let softwareDoneFailedGeneric = String(localized: "software.done.failed_generic")

    // MARK: - Settings: About

    static let settingsAbout         = String(localized: "settings.about")
    static let settingsVersion       = String(localized: "settings.version")
    static let settingsMoleVersion   = String(localized: "settings.mole_version")
    static let settingsMoleNotInstalled = String(localized: "settings.mole_not_installed")
    /// "Mole %@ or newer is required. Run brew upgrade mole."
    static let settingsMoleTooOld    = String(localized: "settings.mole_too_old")

    // MARK: - Update

    static let updateCheck        = String(localized: "update.check")
    /// "Moler %@ is the latest release." — String(format: L10n.updateUpToDateBody, version)
    static let updateUpToDateBody = String(localized: "update.up_to_date_body")
    /// "Moler %@ is available (you have %@). Download it from the release page."
    /// "GitHub didn't answer. Try again later, or open the releases page."
    static let updateErrorBody    = String(localized: "update.error_body")
    /// "GitHub returned HTTP %d." — String(format: L10n.updateHttpError, code)
    static let updateHttpError    = String(localized: "update.http_error")
    static let updateResponseError = String(localized: "update.response_error")
    static let updateReleasePage  = String(localized: "update.release_page")

    // MARK: - Update (in-app installer)

    static let updateAutoCheck    = String(localized: "update.auto_check")
    static let updateChecking     = String(localized: "update.checking")
    static let updateDownloading  = String(localized: "update.downloading")
    static let updateInstalling   = String(localized: "update.installing")
    static let updateInstall      = String(localized: "update.install")
    static let updateRetry        = String(localized: "update.retry")
    /// "Moler %@ is available" — String(format: L10n.updateAvailableShort, version)
    static let updateAvailableShort = String(localized: "update.available_short")
    /// "You have %@" — String(format: L10n.updateCurrentVersionLine, version)
    static let updateCurrentVersionLine = String(localized: "update.current_version_line")
    static let updateNewBadge     = String(localized: "update.new_badge")
    static let updateInstallFailedBody = String(localized: "update.install_failed_body")
    static let updateManualOnly   = String(localized: "update.manual_only")
    static let updateVerifyFailed = String(localized: "update.verify_failed")
    /// "The downloaded update failed verification (%@)." — String(format: ...)
    static let updateVerifyFailedDetail = String(localized: "update.verify_failed_detail")
    static let updateAdminPrompt  = String(localized: "update.admin_prompt")
    static let updateReleaseNotes = String(localized: "update.release_notes")

    // MARK: - About

    /// "WEBSITE" — button to open project homepage
    static let settingsWebsite = String(localized: "settings.website")

    /// "TIP" — button to open the donation page
    static let settingsDonate = String(localized: "settings.donate")
}
