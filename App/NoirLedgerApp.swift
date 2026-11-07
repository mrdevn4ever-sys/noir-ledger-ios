import NoirCore
import SwiftUI

@main
struct NoirLedgerApp: App {
    @State private var store: GameStore
    @State private var settings: AppSettings
    @State private var router = Router()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let directory = (try? SaveStore.defaultDirectory()) ?? FileManager.default.temporaryDirectory
        let settings = AppSettings()
        let store = GameStore(saveStore: SaveStore(directory: directory))
        #if NOIR_QA
        QAAccelerator.prepare(store: store, settings: settings)
        #endif
        store.load()
        #if NOIR_QA
        QAAccelerator.apply(store: store)
        #endif
        _store = State(initialValue: store)
        _settings = State(initialValue: settings)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(settings)
                .environment(router)
                .preferredColorScheme(.dark)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .active: store.enterForeground()
            case .background: store.enterBackground()
            default: break
            }
        }
    }
}
