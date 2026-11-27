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
            PageHeaderBand(
                icon: Pane.settings.iconName,
                title: L10n.settingsWindowTitle,
                subtitle: L10n.settingsSubtitle
            )

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
        .environment(\.colorScheme, .dark)
        .onAppear {
            hasFDA = Privacy.hasFullDiskAccess()
            loadMoleVersion()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            hasFDA = Privacy.hasFullDiskAccess()
        }
    }

    // MARK: - General Section

    private var generalSection: some View {
        settingsSection(L10n.settingsGeneral) {
            languagePicker

            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 10))
                    .foregroundColor(Brand.accentGold)
                Text(L10n.settingsRestartNote)
                    .monoLightFont(10)
                    .foregroundColor(Brand.textDim)
            }
            .padding(.top, 2)
        }
    }

    // MARK: - Permissions Section

    private var permissionsSection: some View {
        settingsSection(L10n.settingsPermissions) {
            fdaRow
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        settingsSection(L10n.settingsAbout) {
            HStack(spacing: 6) {
                Text(L10n.settingsVersion)
                    .monoFont(12)
                    .foregroundColor(Brand.textPrimary)
                Spacer()
                if let new = updater.availableVersion {
                    Text(L10n.updateNewBadge)
                        .monoFont(8)
                        .kerning(1)
                        .foregroundColor(Brand.bgNavy)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Brand.accentOrange)
                        .cornerRadius(3)
                    Text("v\(UpdateChecker.currentVersion) → v\(new)")
                        .monoLightFont(12)
                        .foregroundColor(Brand.accentOrange)
                } else {
                    Text(UpdateChecker.currentVersion)
                        .monoLightFont(12)
                        .foregroundColor(Brand.textDim)
                }
            }
            .padding(.vertical, 4)

            HStack {
                Text(L10n.settingsMoleVersion)
                    .monoFont(12)
                    .foregroundColor(Brand.textPrimary)
                Spacer()
                Text(moleVersionDisplay)
                    .monoLightFont(12)
                    .foregroundColor(moleVersionColor)
            }
            .padding(.vertical, 4)

            if let version = moleVersion, !MoleCLI.isSupported(version: version) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Brand.accentGold)
                    Text(String(format: L10n.settingsMoleTooOld, MoleCLI.minimumVersion))
                        .monoLightFont(10)
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
                    .monoFont(12)
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
                    color: Brand.accentGreen,
                    action: { NSWorkspace.shared.open(officialWebsiteURL) }
                )
                settingsLinkButton(
                    icon: "heart.fill",
                    label: L10n.settingsDonate,
                    color: Brand.accentRed,
                    action: { NSWorkspace.shared.open(donateURL) }
                )
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
                    .monoLightFont(11)
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
                        .monoLightFont(11)
                        .foregroundColor(Brand.textDim)
                    Spacer()
                    Text("\(Int((progress * 100).rounded()))%")
                        .monoFont(11)
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
                        .monoLightFont(11)
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
                .monoLightFont(11)
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
                    .monoFont(12)
                    .foregroundColor(Brand.textPrimary)
                Spacer()
                Text(String(format: L10n.updateCurrentVersionLine, UpdateChecker.currentVersion))
                    .monoLightFont(10)
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
                    .monoLightFont(10)
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
                .monoFont(10)
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
                .monoFont(12)
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
                .monoFont(12)
                .foregroundColor(Brand.textPrimary)

            Spacer()

            if hasFDA {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Brand.accentGreen)
                    Text(L10n.settingsFDAGranted)
                        .monoFont(11)
                        .foregroundColor(Brand.accentGreen)
                }
                .padding(.vertical, 4)
            } else {
                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Brand.accentRed)
                        Text(L10n.settingsFDANotGranted)
                            .monoFont(11)
                            .foregroundColor(Brand.accentRed)
                    }

                    Button {
                        Privacy.openFullDiskAccessSettings()
                    } label: {
                        Text(L10n.settingsFDAAction)
                            .monoFont(10)
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

    private func settingsSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Brand.marginTight) {
                Text(title)
                    .monoFont(10)
                    .kerning(2)
                    .foregroundColor(Brand.textDim)

                Divider()
                    .overlay(Brand.lineColor.opacity(0.2))

                content()
            }
        }
    }

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

private let officialWebsiteURL = URL(string: "https://moler.looplooptech.com/")!
private let donateURL = URL(string: "https://ifdian.net/a/nico2026")!

#Preview {
    SettingsView()
}
