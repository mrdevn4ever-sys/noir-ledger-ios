import NoirCore
import SwiftUI

/// Native grouped settings: language, motion, haptics, the save, reset and the credits.
struct SettingsView: View {
    @Environment(LedgerStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(StoreService.self) private var shop
    @Environment(AdService.self) private var ads
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false
    @State private var resetFailed = false

    private var t: L10n { settings.l10n }

    var body: some View {
        @Bindable var settings = settings
        Form {
            Group {
            Section {
                Image("HeaderSettings").resizable().scaledToFill()
                    .frame(height: 140).frame(maxWidth: .infinity).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: Noir.corner, style: .continuous))
                    .accessibilityHidden(true)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            Section {
                Picker(selection: $settings.language) {
                    Text(verbatim: t("lang_system")).tag(LanguageChoice.system)
                    Text(verbatim: t("lang_de")).tag(LanguageChoice.de)
                    Text(verbatim: t("lang_en")).tag(LanguageChoice.en)
                } label: {
                    Text(verbatim: t("set_language"))
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .accessibilityIdentifier("settings.language")
            } header: {
                HStack(spacing: Noir.s3) { Image("IconLanguage").resizable().frame(width: 28, height: 28).accessibilityHidden(true); Text(verbatim: t("set_language")) }
            }

            Section {
                Picker(selection: $settings.motion) {
                    Text(verbatim: t("motion_system")).tag(MotionChoice.system)
                    Text(verbatim: t("motion_reduced")).tag(MotionChoice.reduced)
                    Text(verbatim: t("motion_full")).tag(MotionChoice.full)
                } label: {
                    Text(verbatim: t("set_motion"))
                }
                .accessibilityIdentifier("settings.motion")
                Toggle(isOn: $settings.haptics) { HStack(spacing: Noir.s3) { Image("IconHaptics").resizable().frame(width: 28, height: 28).accessibilityHidden(true); Text(verbatim: t("set_haptics")) } }
                    .accessibilityIdentifier("settings.haptics")
            }

            Section {
                Toggle(isOn: $settings.sound) { HStack(spacing: Noir.s3) { Image(settings.sound ? "IconSound" : "IconSoundOff").resizable().frame(width: 28, height: 28).accessibilityHidden(true); Text(verbatim: t("set_sound")) } }
                    .accessibilityIdentifier("settings.sound")
                Toggle(isOn: $settings.music) { HStack(spacing: Noir.s3) { Image(settings.music ? "IconMusic" : "IconMusicOff").resizable().frame(width: 28, height: 28).accessibilityHidden(true); Text(verbatim: t("set_music")) } }
                    .accessibilityIdentifier("settings.music")
                Toggle(isOn: $settings.notifications) { HStack(spacing: Noir.s3) { Image("IconBell").resizable().frame(width: 28, height: 28).accessibilityHidden(true); Text(verbatim: t("set_notifications")) } }
                    .accessibilityIdentifier("settings.notifications")
            } header: {
                Text(verbatim: t("set_audio"))
            }

            Section {
                Button {
                    Task { await shop.restore() }
                } label: {
                    HStack(spacing: Noir.s3) {
                        Image("IconRestore").resizable().frame(width: 28, height: 28).accessibilityHidden(true)
                        Text(verbatim: t(shop.restoring ? "shop_restoring" : "shop_restore"))
                    }
                }
                .disabled(shop.restoring)
                .accessibilityIdentifier("settings.restore")
                if ads.hasPrivacyOptions {
                    Button {
                        ads.presentPrivacyOptions()
                    } label: {
                        Text(verbatim: t("set_ad_privacy"))
                    }
                    .accessibilityIdentifier("settings.adPrivacy")
                }
            } header: {
                Text(verbatim: t("set_purchases"))
            }

            Section {
                Text(verbatim: t("save_info")).font(.toon(.footnote)).foregroundStyle(Noir.inkSoft)
                LabeledContent {
                    Text(verbatim: t.relativeSaved(store.lastSavedAtMs, nowMs: store.nowMs)).monospacedDigit()
                } label: {
                    Text(verbatim: t("save_last_label"))
                }
                .accessibilityIdentifier("settings.lastSaved")
                Button {
                    store.save()
                } label: {
                    Text(verbatim: t("save_now"))
                }
                .accessibilityIdentifier("settings.saveNow")
            } header: {
                Text(verbatim: t("set_save"))
            }

            Section {
                Text(verbatim: t("reset_desc")).font(.toon(.footnote)).foregroundStyle(Noir.inkSoft)
                Button(role: .destructive) {
                    confirmReset = true
                } label: {
                    HStack(spacing: Noir.s3) {
                        Image("IconReset").resizable().frame(width: 28, height: 28).accessibilityHidden(true)
                        Text(verbatim: t("reset_title"))
                    }
                }
                .accessibilityIdentifier("settings.reset")
            } header: {
                Text(verbatim: t("reset_title"))
            }

            Section {
                Text(verbatim: t("about_body", appVersion)).font(.toon(.footnote))
                Text(verbatim: t("credits_body")).font(.toon(.footnote)).foregroundStyle(Noir.inkSoft)
            } header: {
                Text(verbatim: t("about_title"))
            }
            }
            .listRowBackground(Noir.surface)
        }
        .scrollContentBackground(.hidden)
        .background { SheetBackdrop() }
        .toggleStyle(ToonToggleStyle())
        .foregroundStyle(Noir.ink)
        .navigationTitle(Text(verbatim: t("settings_title")))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Noir.ground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button { dismiss() } label: { Text(verbatim: t("btn_done")) }
                    .accessibilityIdentifier("settings.done")
            }
        }
        .alert(Text(verbatim: t("reset_confirm_title")), isPresented: $confirmReset) {
            Button(role: .destructive) {
                if store.resetEverything() { dismiss() } else { resetFailed = true }
            } label: {
                Text(verbatim: t("reset_confirm_btn"))
            }
            .accessibilityIdentifier("settings.reset.confirm")
            Button(role: .cancel) {} label: { Text(verbatim: t("btn_cancel")) }
        } message: {
            Text(verbatim: t("reset_confirm_body"))
        }
        .alert(Text(verbatim: t("reset_failed")), isPresented: $resetFailed) {
            Button(role: .cancel) {} label: { Text(verbatim: t("btn_continue")) }
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}
