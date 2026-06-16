import SwiftUI

/// Settings pane rendered inside the main window content area.
struct SettingsView: View {
    @StateObject private var store = Store.shared
    @State private var hasFDA: Bool = false

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

                HStack {
                    Text(L10n.settingsVersion)
                        .font(.custom("RobotoMono-Regular", size: 12))
                        .foregroundColor(Brand.textPrimary)
                    Spacer()
                    Text("0.1.0")
                        .font(.custom("RobotoMono-Light", size: 12))
                        .foregroundColor(Brand.textDim)
                }
                .padding(.vertical, 4)
            }
        }
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
                Text("中文")
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
}

#Preview {
    SettingsView()
}
