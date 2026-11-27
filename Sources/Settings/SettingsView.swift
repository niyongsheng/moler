import SwiftUI

/// Settings pane rendered inside the main window content area.
struct SettingsView: View {
    @StateObject private var store = Store.shared
    @ObservedObject private var updater = UpdateManager.shared
    @State private var hasFDA: Bool = false
    @State private var moleVersion: String?
    @State private var moleVersionLoaded = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
                .padding(.horizontal, Brand.margin)
                .padding(.top, 20)
                .padding(.bottom, 16)

            Divider()
                .overlay(Brand.lineColor.opacity(0.3))

            // Content
            ScrollView {
                VStack(spacing: Brand.margin) {
                    generalSection
                    permissionsSection
                    aboutSection
                }
                .padding(Brand.margin)
                .frame(maxWidth: 540)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Brand.bgNavy)
        .environment(\.colorScheme, .dark)
        .onAppear {
            hasFDA = Privacy.hasFullDiskAccess()
            loadMoleVersion()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            hasFDA = Privacy.hasFullDiskAccess()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.settingsWindowTitle)
                    .font(.custom("Jura-Bold", size: 18))
                    .kerning(4)
                    .foregroundColor(Brand.accentOrange)
            }
            Spacer()
        }
    }

    // MARK: - General Section

    private var generalSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Brand.marginTight) {
                Text(L10n.settingsGeneral)
                    .font(.custom("RobotoMono-Regular", size: 10))
                    .kerning(2)
                    .foregroundColor(Brand.textDim)

                Divider()
                    .overlay(Brand.lineColor.opacity(0.2))

                languagePicker

                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                        .foregroundColor(Brand.accentGold)
                    Text(L10n.settingsRestartNote)
                        .font(.custom("RobotoMono-Light", size: 10))
                        .foregroundColor(Brand.textDim)
                }
                .padding(.top, 2)
            }
        }
    }

    // MARK: - Permissions Section

    private var permissionsSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Brand.marginTight) {
                Text(L10n.settingsPermissions)
                    .font(.custom("RobotoMono-Regular", size: 10))
                    .kerning(2)
                    .foregroundColor(Brand.textDim)

                Divider()
                    .overlay(Brand.lineColor.opacity(0.2))

                fdaRow
            }
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Brand.marginTight) {
                Text(L10n.settingsAbout)
                    .font(.custom("RobotoMono-Regular", size: 10))
                    .kerning(2)
                    .foregroundColor(Brand.textDim)

                Divider()
                    .overlay(Brand.lineColor.opacity(0.2))

                HStack(spacing: 6) {
                    Text(L10n.settingsVersion)
                        .font(.custom("RobotoMono-Regular", size: 12))
                        .foregroundColor(Brand.textPrimary)
                    Spacer()
                    if let new = updater.availableVersion {
                        Text(L10n.updateNewBadge)
                            .font(.custom("RobotoMono-Regular", size: 8))
                            .kerning(1)
                            .foregroundColor(Brand.bgNavy)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Brand.accentOrange)
                            .cornerRadius(3)
                        Text("v\(UpdateChecker.currentVersion) → v\(new)")
                            .font(.custom("RobotoMono-Light", size: 12))
                            .foregroundColor(Brand.accentOrange)
                    } else {
                        Text(UpdateChecker.currentVersion)
                            .font(.custom("RobotoMono-Light", size: 12))
                            .foregroundColor(Brand.textDim)
                    }
                }
                .padding(.vertical, 4)

                HStack {
                    Text(L10n.settingsMoleVersion)
                        .font(.custom("RobotoMono-Regular", size: 12))
                        .foregroundColor(Brand.textPrimary)
                    Spacer()
                    Text(moleVersionDisplay)
                        .font(.custom("RobotoMono-Light", size: 12))
                        .foregroundColor(moleVersionColor)
                }
                .padding(.vertical, 4)

                if let version = moleVersion, !MoleCLI.isSupported(version: version) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Brand.accentGold)
                        Text(String(format: L10n.settingsMoleTooOld, MoleCLI.minimumVersion))
                            .font(.custom("RobotoMono-Light", size: 10))
                            .foregroundColor(Brand.accentGold)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 2)
                }

                Divider()
                    .overlay(Brand.lineColor.opacity(0.2))

                // Automatic update checks
                HStack {
                    Text(L10n.updateAutoCheck)
                        .font(.custom("RobotoMono-Regular", size: 12))
                        .foregroundColor(Brand.textPrimary)
                    Spacer()
                    Toggle("", isOn: $updater.autoCheckEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .labelsHidden()
                        .tint(Brand.accentOrange)
                }
                .padding(.vertical, 4)

                updateStatusView

                // Check for Updates + Website buttons
                HStack(spacing: 8) {
                    settingsLinkButton(
                        icon: "arrow.down.circle",
                        label: updater.state == .checking ? L10n.updateChecking : L10n.updateCheck,
                        color: Brand.accentOrange,
                        action: { updater.check(userInitiated: true) }
                    )
                    .disabled(updater.isBusy)
                    .opacity(updater.isBusy ? 0.5 : 1)
                    settingsLinkButton(
                        icon: "link",
                        label: L10n.settingsWebsite,
                        color: Brand.accentBlue,
                        action: { NSWorkspace.shared.open(projectURL) }
                    )
                }
            }
        }
    }

    // MARK: - Update Status

    @ViewBuilder
    private var updateStatusView: some View {
        switch updater.state {
        case .idle:
            EmptyView()

        case .checking:
            spinnerStatus(L10n.updateChecking)

        case .upToDate:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Brand.accentGreen)
                Text(String(format: L10n.updateUpToDateBody, UpdateChecker.currentVersion))
                    .font(.custom("RobotoMono-Light", size: 11))
                    .foregroundColor(Brand.textDim)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 2)

        case .available(let release):
            availableUpdateCard(release)

        case .downloading(let progress):
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(L10n.updateDownloading)
                        .font(.custom("RobotoMono-Light", size: 11))
                        .foregroundColor(Brand.textDim)
                    Spacer()
                    Text("\(Int((progress * 100).rounded()))%")
                        .font(.custom("RobotoMono-Regular", size: 11))
                        .foregroundColor(Brand.accentOrange)
                }
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(Brand.accentOrange)
            }
            .padding(.vertical, 4)

        case .installing:
            spinnerStatus(L10n.updateInstalling)

        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Brand.accentRed)
                    Text(message)
                        .font(.custom("RobotoMono-Light", size: 11))
                        .foregroundColor(Brand.accentRed)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                HStack(spacing: 8) {
                    updateActionButton(L10n.updateRetry, color: Brand.accentOrange) {
                        updater.check(userInitiated: true)
                    }
                    updateActionButton(L10n.updateReleasePage, color: Brand.accentGreen) {
                        NSWorkspace.shared.open(UpdateChecker.releasesPageURL)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func spinnerStatus(_ text: String) -> some View {
        HStack(spacing: 6) {
            ProgressView()
                .controlSize(.small)
                .tint(Brand.accentOrange)
            Text(text)
                .font(.custom("RobotoMono-Light", size: 11))
                .foregroundColor(Brand.textDim)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    private func availableUpdateCard(_ release: UpdateChecker.Release) -> some View {
        let canInstall = release.zipURL != nil && UpdateInstaller.canInstall
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Brand.accentOrange)
                Text(String(format: L10n.updateAvailableShort, release.version))
                    .font(.custom("RobotoMono-Regular", size: 12))
                    .foregroundColor(Brand.textPrimary)
                Spacer()
                Text(String(format: L10n.updateCurrentVersionLine, UpdateChecker.currentVersion))
                    .font(.custom("RobotoMono-Light", size: 10))
                    .foregroundColor(Brand.textDim)
            }

            HStack(spacing: 8) {
                if canInstall {
                    updateActionButton(L10n.updateInstall, color: Brand.accentOrange) {
                        updater.install()
                    }
                    updateActionButton(L10n.updateReleaseNotes, color: Brand.accentGreen) {
                        NSWorkspace.shared.open(release.url)
                    }
                } else {
                    updateActionButton(L10n.updateReleasePage, color: Brand.accentOrange) {
                        NSWorkspace.shared.open(release.url)
                    }
                }
            }

            if !canInstall {
                Text(L10n.updateManualOnly)
                    .font(.custom("RobotoMono-Light", size: 10))
                    .foregroundColor(Brand.accentGold)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(Brand.accentOrange.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Brand.accentOrange.opacity(0.25), lineWidth: 0.5)
        )
        .cornerRadius(6)
    }

    private func updateActionButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.custom("RobotoMono-Regular", size: 10))
                .foregroundColor(color)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(color.opacity(0.15))
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Language Picker

    private var languagePicker: some View {
        HStack {
            Text(L10n.settingsLanguage)
                .font(.custom("RobotoMono-Regular", size: 12))
                .foregroundColor(Brand.textPrimary)

            Spacer()

            Picker("", selection: $store.language) {
                Text(L10n.settingsLanguageSystem)
                    .tag("")
                Text("English")
                    .tag("en")
                Text("简体中文")
                    .tag("zh-Hans")
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 140)
        }
        .padding(.vertical, 4)
    }

    // MARK: - FDA Row

    private var fdaRow: some View {
        HStack {
            Text(L10n.settingsFDATitle)
                .font(.custom("RobotoMono-Regular", size: 12))
                .foregroundColor(Brand.textPrimary)

            Spacer()

            if hasFDA {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                    Text(L10n.settingsFDAGranted)
                        .font(.custom("RobotoMono-Regular", size: 11))
                        .foregroundColor(.green)
                }
                .padding(.vertical, 4)
            } else {
                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Brand.accentRed)
                        Text(L10n.settingsFDANotGranted)
                            .font(.custom("RobotoMono-Regular", size: 11))
                            .foregroundColor(Brand.accentRed)
                    }

                    Button {
                        Privacy.openFullDiskAccessSettings()
                    } label: {
                        Text(L10n.settingsFDAAction)
                            .font(.custom("RobotoMono-Regular", size: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(Brand.accentOrange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Brand.accentOrange.opacity(0.15))
                    .cornerRadius(4)
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Mole CLI Version

    private var moleVersionDisplay: String {
        if let version = moleVersion { return version }
        return moleVersionLoaded ? L10n.settingsMoleNotInstalled : "…"
    }

    private var moleVersionColor: Color {
        guard let version = moleVersion else {
            return moleVersionLoaded ? Brand.accentRed : Brand.textDim
        }
        return MoleCLI.isSupported(version: version) ? Brand.textDim : Brand.accentGold
    }

    private func loadMoleVersion() {
        Task { @MainActor in
            let version = await Task.detached(priority: .utility) {
                MoleCLI.version()
            }.value
            moleVersion = version
            moleVersionLoaded = true
        }
    }

    // MARK: - Helpers

    private func settingsLinkButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(label)
                    .monoFont(10)
            }
            .foregroundColor(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.15))
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}

private let projectURL = URL(string: "https://niyongsheng.github.io/moler/")!

#Preview {
    SettingsView()
}
