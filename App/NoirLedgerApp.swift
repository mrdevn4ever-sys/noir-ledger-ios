import NoirCore
import SwiftUI

@main
struct NoirLedgerApp: App {
    @State private var store: GameStore
    @State private var settings: AppSettings
    @State private var router = Router()
    @State private var shop: StoreService
    @State private var ads: AdService
    private let sound: SoundEngine
    private let notifier: Notifier
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let directory = (try? SaveStore.defaultDirectory()) ?? FileManager.default.temporaryDirectory
        let settings = AppSettings()
        let store = GameStore(saveStore: SaveStore(directory: directory))
        let sound = SoundEngine()
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
        sound.start()
        store.onFeedback = { [sound] feedback in sound.play(feedback) }
        shop.deliver = { [store] item in store.deliver(item.grant) }
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
                .environment(router)
                .environment(shop)
                .environment(ads)
                .preferredColorScheme(.dark)
                .onChange(of: settings.sound) { _, on in sound.effectsEnabled = on }
                .onChange(of: settings.music) { _, on in sound.musicEnabled = on }
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
                if store.phase == .ready {
                    notifier.schedule(state: store.state, today: store.today, enabled: settings.notifications, t: settings.l10n)
                }
            default:
                break
            }
        }
    }
}
