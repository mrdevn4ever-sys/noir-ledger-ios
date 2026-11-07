import NoirCore
import SwiftUI

/// Native grouped settings: language, motion, haptics, the save, reset and the credits.
struct SettingsView: View {
    @Environment(GameStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false

    private var t: L10n { settings.l10n }

    var body: some View {
        @Bindable var settings = settings
        Form {
            Group {
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
                Text(verbatim: t("set_language"))
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
                Toggle(isOn: $settings.haptics) { Text(verbatim: t("set_haptics")) }
                    .accessibilityIdentifier("settings.haptics")
            }

            Section {
                Text(verbatim: t("save_info")).font(.footnote).foregroundStyle(Noir.inkSoft)
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
                Text(verbatim: t("reset_desc")).font(.footnote).foregroundStyle(Noir.inkSoft)
                Button(role: .destructive) {
                    confirmReset = true
                } label: {
                    Text(verbatim: t("reset_title"))
                }
                .accessibilityIdentifier("settings.reset")
            } header: {
                Text(verbatim: t("reset_title"))
            }

            Section {
                Text(verbatim: t("about_body", appVersion)).font(.footnote)
                Text(verbatim: t("credits_body")).font(.footnote).foregroundStyle(Noir.inkSoft)
            } header: {
                Text(verbatim: t("about_title"))
            }
            }
            .listRowBackground(Noir.surface)
        }
        .scrollContentBackground(.hidden)
        .background(Noir.ground)
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
                store.resetEverything()
                router.resetNavigation()
                dismiss()
            } label: {
                Text(verbatim: t("reset_confirm_btn"))
            }
            .accessibilityIdentifier("settings.reset.confirm")
            Button(role: .cancel) {} label: { Text(verbatim: t("btn_cancel")) }
        } message: {
            Text(verbatim: t("reset_confirm_body"))
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}
