import NoirCore
import SwiftUI
import UIKit

@main
struct NoirLedgerApp: App {
    @State private var store: LedgerStore
    @State private var settings: AppSettings
    @State private var shop: StoreService
    @State private var ads: AdService
    private let sound: SoundEngine
    private let notifier: Notifier
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let directory = (try? SaveStore.defaultDirectory()) ?? FileManager.default.temporaryDirectory
        let settings = AppSettings()
        let store = LedgerStore(saveStore: FlowSaveStore(directory: directory), tycoonStore: TycoonSaveStore(directory: directory),
                                legacyStore: SaveStore(directory: directory))
        let sound = SoundEngine()
        Self.styleNavigationBars()
        let shop = StoreService()
        #if NOIR_QA
        QAAccelerator.prepare(store: store, settings: settings)
        #endif
        store.load()
        #if NOIR_QA
        QAAccelerator.apply(store: store)
        #endif
        sound.effectsEnabled = settings.sound
        sound.musicEnabled = settings.music
        sound.start(mood: SoundMood.of(store.state))
        store.onFeedback = { [sound] feedback in sound.play(feedback) }
        shop.deliver = { [store] item, transaction in store.book(item.grant, transaction: transaction) }
        shop.adoptDelivered = { [store] ids in store.adoptDeliveredTransactions(ids) }
        self.sound = sound
        self.notifier = Notifier()
        _store = State(initialValue: store)
        _settings = State(initialValue: settings)
        _shop = State(initialValue: shop)
        _ads = State(initialValue: AdService.makeDefault())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(settings)
                .environment(shop)
                .environment(ads)
                .preferredColorScheme(.dark)
                .onChange(of: settings.sound) { _, on in sound.effectsEnabled = on }
                .onChange(of: settings.music) { _, on in sound.musicEnabled = on }
                .onChange(of: SoundMood.of(store.state)) { _, mood in sound.setMood(mood) }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .active:
                store.enterForeground()
                sound.resume()
                notifier.clear()
            case .background:
                store.enterBackground()
                sound.pause()
                if store.phase == .ready, !QAFlags.isAutomatedRun {
                    notifier.schedule(state: store.state, today: store.today, enabled: settings.notifications, t: settings.l10n)
                }
            default:
                break
            }
        }
    }

    /// Window titles in the title face, white on night blue.
    private static func styleNavigationBars() {
        let title = UIFont(name: ToonFont.display, size: 20) ?? .systemFont(ofSize: 18, weight: .bold)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0x14 / 255, green: 0x1A / 255, blue: 0x33 / 255, alpha: 1)
        appearance.titleTextAttributes = [.font: title, .foregroundColor: UIColor.white]
        appearance.shadowColor = .clear
        let item = UIBarButtonItemAppearance()
        item.normal.titleTextAttributes = [.font: ToonFont.uiFont(size: 17, weight: .bold, style: .body)]
        appearance.buttonAppearance = item
        appearance.doneButtonAppearance = item
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }
}
