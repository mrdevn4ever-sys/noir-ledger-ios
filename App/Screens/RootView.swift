import NoirCore
import SwiftUI

/// Chooses between the save-version guard, Leopold's prologue and the ledger, and hosts what can interrupt play:
/// the return summary, a closed chapter's story moment, the save-recovery note and the celebration banner.
struct RootView: View {
    @Environment(LedgerStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(StoreService.self) private var shop
    @Environment(AdService.self) private var ads

    var body: some View {
        content
            .environment(\.l10n, settings.l10n)
            .environment(\.locale, settings.l10n.locale)
            .environment(\.noirReduceMotion, settings.reduceMotion(system: systemReduceMotion))
            .tint(Noir.amber)
            .font(.toon(.body))
            .sensoryFeedback(.selection, trigger: store.acceptedCount) { _, _ in settings.haptics }
            .sensoryFeedback(.warning, trigger: store.rejectedCount) { _, _ in settings.haptics }
            .sensoryFeedback(.impact(weight: .light), trigger: store.tapCount) { _, _ in settings.haptics }
            .sensoryFeedback(.success, trigger: store.celebration?.id) { _, new in settings.haptics && new != nil }
            .overlay(alignment: .top) {
                CelebrationBanner()
                    .environment(\.l10n, settings.l10n)
                    .environment(\.noirReduceMotion, settings.reduceMotion(system: systemReduceMotion))
            }
            .task {
                shop.start()
                ads.start()
            }
            #if NOIR_QA
            .overlay(alignment: .bottomLeading) { if FrameProbe.enabled { FrameProbeView() } }
            .overlay(alignment: .topLeading) {
                if OpeningProbe.choice != nil, !OpeningProbe.shared.result.isEmpty {
                    ScreenMarker(identifier: "opening.result", title: OpeningProbe.shared.result).allowsHitTesting(false)
                }
            }
            #endif
    }

    @ViewBuilder
    private var content: some View {
        switch store.phase {
        case .loading:
            LoadingView()
        case .futureSave:
            ProtectedSaveView(newer: true)
        case .saveUnavailable:
            ProtectedSaveView(newer: false)
        case .ready:
            if store.state.start == nil {
                PrologueView()
            } else {
                GameRoot()
            }
        }
    }
}

/// The interruptions, one at a time: the return summary first, then the story of a closed chapter.
private enum Interruption: String, Identifiable {
    case welcome, chapter
    var id: String { rawValue }
}

private struct GameRoot: View {
    @Environment(LedgerStore.self) private var store
    @Environment(\.l10n) private var t

    private var interruption: Binding<Interruption?> {
        Binding(
            get: {
                if store.state.welcome != nil { return .welcome }
                if store.state.chapterNews != nil { return .chapter }
                return nil
            },
            set: { newValue in
                guard newValue == nil else { return }
                if store.state.welcome != nil {
                    store.dispatch(.collectOffline(doubled: false))
                } else if store.state.chapterNews != nil {
                    store.dispatch(.seenChapter)
                }
            }
        )
    }

    private var restoredAlert: Binding<Bool> {
        Binding(get: { store.restoredFromBackup }, set: { store.restoredFromBackup = $0 })
    }

    var body: some View {
        LedgerView()
            .sheet(item: interruption) { kind in
                Group {
                    switch kind {
                    case .welcome:
                        if let report = store.state.welcome { ReturnSheet(report: report) }
                    case .chapter:
                        if let n = store.state.chapterNews { ChapterNewsSheet(number: n) }
                    }
                }
                .environment(\.l10n, t)
            }
            .alert(Text(verbatim: t("save_restored_title")), isPresented: restoredAlert) {
                Button(role: .cancel) {} label: { Text(verbatim: t("btn_continue")) }
            } message: {
                Text(verbatim: t("save_restored"))
            }
    }
}

private struct LoadingView: View {
    @Environment(\.l10n) private var t

    var body: some View {
        VStack(spacing: Noir.s4) {
            Wordmark()
            ProgressView().tint(Noir.amber)
            Text(verbatim: t("loading")).foregroundStyle(Noir.inkSoft)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { SheetBackdrop() }
    }
}

/// No destructive escape hatch: an older app cannot reconstruct an unknown wallet.
struct ProtectedSaveView: View {
    let newer: Bool
    @Environment(LedgerStore.self) private var store
    @Environment(\.l10n) private var t


    var body: some View {
        ScrollView {
            VStack(spacing: Noir.s5) {
                Wordmark().padding(.top, Noir.s6)
                Image("HeaderError").resizable().scaledToFill()
                    .frame(height: 150).frame(maxWidth: .infinity).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: Noir.corner, style: .continuous))
                    .accessibilityHidden(true)
                Panel(.paper) {
                    Text(verbatim: newer ? t("save_future_title") : t("save_unavailable_title")).font(.toon(.title3, .semibold))
                    Text(verbatim: newer ? t("save_future_body") : t("save_unavailable_body")).font(.toon(.body))
                }
                Button {
                    store.load()
                    if store.phase == .ready { store.enterForeground() }
                } label: { Text(verbatim: t("save_check_again")) }
                    .noirButton(.primary)
                    .accessibilityIdentifier("save.retry")
            }
            .padding(Noir.s4)
        }
        .background { SheetBackdrop() }

    }
}

// MARK: - Opening

/// The first minutes before the ledger: one crate at the cellar door for a buyer who already signed for it, then
/// one of Leopold's things to take. The notary's story is there to read, never in the way.
struct PrologueView: View {
    @Environment(LedgerStore.self) private var store

    var body: some View {
        if store.state.estate == .waiting {
            EstateDoorView()
        } else {
            HeirloomChoiceView(receipt: store.state.ledger.last { $0.kind == .estate }?.amount)
        }
    }
}

/// The first interactive screen: the street at night, the cellar door, the waiting buyer and the crate. One big
/// control books the one-time pickup.
struct EstateDoorView: View {
    @Environment(LedgerStore.self) private var store
    @Environment(\.l10n) private var t
    @Environment(\.noirReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Noir.s4) {
                Wordmark().frame(maxWidth: .infinity).padding(.top, Noir.s4)
                EstateDoorScene(collect: collect)
                    .frame(height: BuildingScene.streetHeight)
                    .clipShape(RoundedRectangle(cornerRadius: Noir.corner, style: .continuous))
                    .environment(\.sceneAnimating, !reduceMotion)
                    .dynamicTypeSize(...DynamicTypeSize.xLarge)
                Text(verbatim: t("l4_estate_title")).font(.display(.title2)).accessibilityAddTraits(.isHeader)
                Text(verbatim: t("l4_estate_body", t.money(FlowContent.estatePickupCash)))
                    .font(.toon(.body)).foregroundStyle(Noir.inkSoft).fixedSize(horizontal: false, vertical: true)
                Button(action: collect) {
                    Label {
                        Text(verbatim: t("l4_estate_collect", t.money(FlowContent.estatePickupCash)))
                    } icon: {
                        Image(systemName: "key.fill")
                    }
                    .font(.toon(.title3, .heavy))
                }
                .noirButton(.primary)
                .accessibilityIdentifier("estate.collect")
                #if NOIR_QA
                .openingMarker(.door)
                #endif
            }
            .padding(Noir.s4)
            .background(alignment: .topLeading) {
                ZStack {
                    ScreenMarker(identifier: "screen.prologue", title: t("l4_estate_title"))
                    ScreenMarker(identifier: "screen.estate", title: t("l4_estate_title"))
                }
            }
        }
        .background { SheetBackdrop() }
        .onAppear { SceneImages.shared.prewarm(EstateDoorScene.prewarm) }
    }

    private func collect() {
        #if NOIR_QA
        OpeningProbe.shared.touch(.door)
        #endif
        store.dispatch(.collectEstate)
    }
}

/// The street of the first screen from the delivered art, with plain values only: the shed with its door, the
/// buyer waiting with the signed slip, the one crate.
struct EstateDoorScene: View {
    let collect: () -> Void

    static let prewarm: [(name: String, frames: Int)] = [
        ("SkyNight", 1), ("SkylineFar", 1), ("SkylineNear", 1), ("Street", 1), ("ShaftTile", 1), ("StreetLampGlow", 1),
        ("StreetLamp", 1), ("Moon", 1), ("Fireflies8", 8), (SceneArt.depot(fleetLevel: 1), 1),
        (SceneArt.customers(.cellars, hot: false), 1), (SceneArt.buyer(.cellars, walking: false), 2), (SceneArt.crate(.weed), 1),
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let streetY = h - BuildingScene.roadHeight
            let top = streetY + 4 - StreetSection.buildingHeight
            ZStack(alignment: .topLeading) {
                StreetBackdrop(width: w, height: h, fireflies: true)
                SceneImage(SceneArt.customers(.cellars, hot: false), StreetSection.houseWidth, StreetSection.buildingHeight)
                    .position(x: w - StreetSection.houseWidth / 2, y: top + StreetSection.buildingHeight / 2)
                SceneImage(SceneArt.depot(fleetLevel: 1), StreetSection.depotWidth, StreetSection.buildingHeight)
                    .position(x: StreetSection.depotWidth / 2, y: top + StreetSection.buildingHeight / 2)
                SceneFigure(sheet: SceneArt.buyer(.cellars, walking: false), move: .idle, facing: -1)
                    .position(x: StreetSection.depotWidth + 40, y: streetY + 2 - 35)
                // The crate at the door is a second, smaller way to hand it over.
                Button(action: collect) {
                    SceneImage(SceneArt.crate(.weed), 40, 32)
                        .idle(.bob(2), duration: 0.7)
                        .frame(width: 56, height: 56)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .position(x: StreetSection.depotWidth + 2, y: streetY - 14)
                .accessibilityHidden(true)
            }
            .frame(width: w, height: h, alignment: .topLeading)
        }
    }
}

/// After the pickup: the booking it made, and Leopold's three things, one sentence each. The notary's letter is a
/// tap away for whoever wants the story.
struct HeirloomChoiceView: View {
    /// The pickup's booking when it was made in this game.
    let receipt: Double?
    @Environment(LedgerStore.self) private var store
    @Environment(\.l10n) private var t
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var letter = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Noir.s3) {
                if !typeSize.isAccessibilitySize {
                    Wordmark().frame(maxWidth: .infinity).padding(.top, Noir.s4)
                }
                if let receipt {
                    EstateReceipt(amount: receipt)
                }
                Text(verbatim: t("l4_prologue_choose")).font(.toon(.headline)).accessibilityAddTraits(.isHeader)
                ForEach(StartChoice.allCases, id: \.self) { choice in
                    Button {
                        #if NOIR_QA
                        if OpeningProbe.choice == choice.rawValue { OpeningProbe.shared.touch(.heirloom) }
                        #endif
                        store.dispatch(.choose(choice))
                    } label: {
                        HStack(alignment: .center, spacing: Noir.s3) {
                            Image(SceneArt.item(choice)).resizable().scaledToFit().frame(width: 52, height: 52)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: t(StartText.title(choice))).font(.toon(.headline))
                                Text(verbatim: t(StartText.effect(choice))).font(.toon(.subheadline, .semibold))
                                    .foregroundStyle(Noir.amber).fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "chevron.right").font(.toon(.caption, .bold)).foregroundStyle(Noir.inkSoft)
                                .accessibilityHidden(true)
                        }
                        .padding(Noir.s3)
                        .foregroundStyle(Noir.ink)
                        .background(Noir.leather, in: RoundedRectangle(cornerRadius: Noir.corner, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Noir.corner, style: .continuous).strokeBorder(Noir.leatherEdge, lineWidth: 1))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("start.\(choice.rawValue)")
                    #if NOIR_QA
                    .openingMarker(.heirloom, choice: choice.rawValue)
                    #endif
                }
                Button { letter = true } label: {
                    Label { Text(verbatim: t("l4_letter_open")) } icon: { Image(systemName: "envelope.open.fill") }
                }
                .noirButton(.quiet)
                .accessibilityIdentifier("prologue.letter")
            }
            .padding(Noir.s4)
            .background(alignment: .topLeading) {
                ZStack {
                    ScreenMarker(identifier: "screen.prologue", title: t("l4_prologue_choose"))
                    ScreenMarker(identifier: "screen.heirlooms", title: t("l4_prologue_choose"))
                }
            }
        }
        .background { SheetBackdrop() }
        .sheet(isPresented: $letter) {
            NotaryLetterSheet().environment(\.l10n, t)
        }
    }
}

/// The ledger's first line: the signed pickup, booked once.
struct EstateReceipt: View {
    let amount: Double
    @Environment(\.l10n) private var t
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Noir.s2) {
                        Image("StampPaid").resizable().scaledToFit().frame(width: 32, height: 32).accessibilityHidden(true)
                        Text(verbatim: "+" + t.money(amount)).font(.toon(.title2, .heavy)).monospacedDigit()
                    }
                    Text(verbatim: t("l4_estate_short_receipt")).font(.toon(.subheadline, .semibold))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                detailedReceipt
            }
        }
        .padding(Noir.s3)
        .foregroundStyle(Noir.paperInk)
        .background(Noir.paper, in: RoundedRectangle(cornerRadius: Noir.corner, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("estate.receipt")
        #if NOIR_QA
        .openingMarker(.receipt)
        #endif
    }

    private var detailedReceipt: some View {
        HStack(spacing: Noir.s3) {
            Image("StampPaid").resizable().scaledToFit().frame(width: 52, height: 52).rotationEffect(.degrees(-8))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: t("l4_estate_booked")).font(.toon(.subheadline, .semibold)).fixedSize(horizontal: false, vertical: true)
                Text(verbatim: t("l4_estate_once")).font(.toon(.caption)).foregroundStyle(Noir.paperInk.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(verbatim: "+" + t.money(amount)).font(.toon(.title2, .heavy)).monospacedDigit()
        }
    }
}

/// The notary's office in the rain, for whoever wants to read it.
struct NotaryLetterSheet: View {
    @Environment(\.l10n) private var t
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Noir.s4) {
                Image("ScenePrologue")
                    .resizable().scaledToFill()
                    .frame(height: 200).frame(maxWidth: .infinity).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: Noir.corner, style: .continuous))
                    .accessibilityHidden(true)
                Panel(.paper) {
                    Text(verbatim: t("l4_prologue_title")).font(.display(.title2)).accessibilityAddTraits(.isHeader)
                    Text(verbatim: t("l4_prologue_body")).font(.toon(.body)).fixedSize(horizontal: false, vertical: true)
                }
                Button { dismiss() } label: { Text(verbatim: t("btn_continue")) }
                    .noirButton(.primary)
                    .accessibilityIdentifier("letter.close")
            }
            .padding(Noir.s4)
            .background(alignment: .topLeading) { ScreenMarker(identifier: "screen.letter", title: t("l4_prologue_title")) }
        }
        .background { SheetBackdrop() }
    }
}

// MARK: - Coming back

/// The welcome back: how long, what the automated stations booked, what piled up, what to do first. The money is
/// already in the book; this only shows it (and offers the sponsor's double).
struct ReturnSheet: View {
    let report: FlowReturn
    @Environment(LedgerStore.self) private var store
    @Environment(AdService.self) private var ads
    @Environment(\.l10n) private var t

    var body: some View {
        let s = store.state
        ScrollView {
            VStack(alignment: .leading, spacing: Noir.s4) {
                Image("HeaderReturn").resizable().scaledToFill()
                    .frame(height: 160).frame(maxWidth: .infinity).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: Noir.corner, style: .continuous))
                    .overlay { if !report.clockMovedBack && report.earned > 0 { TimedSprite(name: "MoneyRain8", frames: 8, size: 220, fps: 8) } }
                    .accessibilityHidden(true)
                Text(verbatim: t("l4_return_title")).font(.display(.title2)).foregroundStyle(Noir.ink)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("welcome.title")
                if report.clockMovedBack {
                    Text(verbatim: t("l4_return_clock")).font(.toon(.body)).foregroundStyle(Noir.inkSoft)
                } else {
                    Text(verbatim: t("l4_return_away", t.duration(report.away), t.duration(report.credited)))
                        .font(.toon(.subheadline)).foregroundStyle(Noir.inkSoft)
                    VStack(spacing: 2) {
                        Text(verbatim: t("l4_return_booked")).font(.toon(.caption)).foregroundStyle(Noir.inkSoft)
                        Text(verbatim: "+" + t.money(report.earned))
                            .font(.toon(.largeTitle, .bold)).monospacedDigit()
                            .foregroundStyle(Noir.amber)
                            .accessibilityIdentifier("welcome.earned")
                    }
                    .frame(maxWidth: .infinity)
                    Panel(.paper) {
                        ValueRow(label: t("l4_return_deliveries"), value: t.decimal(Double(report.deliveries), digits: 0))
                        if report.ordersDone + report.ordersFailed > 0 {
                            ValueRow(label: t("l4_return_orders"), value: "\(report.ordersDone) / \(report.ordersFailed)")
                        }
                        if report.capped {
                            Text(verbatim: t("l4_return_capped", t.duration(report.credited))).font(.toon(.caption))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        ForEach(report.fullShelves, id: \.self) { g in
                            Label { Text(verbatim: t("l4_return_full", t(GoodText.name(g)))) } icon: { Image("IconStock").resizable().frame(width: 20, height: 20) }
                                .font(.toon(.caption, .semibold)).foregroundStyle(Noir.paperRed)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if !s.dispatcher || s.openGoods.contains(where: { s.workshop($0)?.lead != true }) {
                            Text(verbatim: t("l4_return_manual")).font(.toon(.caption)).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if let advice = Flow.returnAdvice(s) {
                        Panel(.leather) {
                            Text(verbatim: t("l4_advice_title")).font(.toon(.caption, .bold)).foregroundStyle(Noir.amber)
                            Text(verbatim: AdviceText.reason(advice, t)).font(.toon(.subheadline))
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("welcome.next")
                            // Carried out only on this tap; the summary closes afterwards.
                            Button {
                                if store.dispatch(advice.action) != nil { store.dispatch(.collectOffline(doubled: false)) }
                            } label: {
                                Text(verbatim: AdviceText.button(advice, t))
                            }
                            .noirButton(.go)
                            .accessibilityIdentifier("welcome.advice.\(AdviceText.id(advice))")
                        }
                    }
                    if let hire = Flow.nextHire(s), s.cash + 1e-9 < hire.cost {
                        Text(verbatim: t("l4_advice_saving", AdviceText.who(hire.advice), t.money(hire.cost), t.money(hire.cost - s.cash)))
                            .font(.toon(.caption)).foregroundStyle(Noir.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("welcome.saving")
                    }
                }
                if s.meta.offlineBonus > 0, store.rewardOffered(ads: ads) {
                    Button {
                        store.claimReward(.offlineDouble, ads: ads)
                    } label: {
                        Label {
                            Text(verbatim: t(s.meta.noAds ? "offline_double_free" : "offline_double_video", t.money(s.meta.offlineBonus)))
                        } icon: {
                            Image(s.meta.noAds ? "IconBoost" : "IconAd").resizable().frame(width: 22, height: 22)
                        }
                    }
                    .noirButton(.secondary)
                    .accessibilityIdentifier("welcome.double")
                }
                Button {
                    store.dispatch(.collectOffline(doubled: false))
                } label: {
                    Text(verbatim: t("l4_return_ok"))
                }
                .noirButton(.primary)
                .accessibilityIdentifier("welcome.ok")
            }
            .padding(Noir.s4)
        }
        .background { SheetBackdrop() }
        .onChange(of: store.state.meta.offlineBonus) { old, new in
            if old > 0 && new <= 0 { store.dispatch(.dismissWelcome) }
        }
    }

}

// MARK: - Chapters

struct ChapterSheet: View {
    @Environment(LedgerStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.l10n) private var t

    var body: some View {
        let s = store.state
        SheetFrame("l4_chapter", identifier: "screen.chapter") {
            if let ch = FlowContent.chapter(s.chapter) {
                Image(SceneArt.chapter(ch.number, outro: false)).resizable().scaledToFill()
                    .frame(height: 180).frame(maxWidth: .infinity).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: Noir.corner, style: .continuous))
                    .accessibilityHidden(true)
                HStack(spacing: Noir.s3) {
                    Portrait(crewId: ch.person, size: 64, mood: Flow.chapterComplete(s) ? .happy : .smug).clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: t("l4_chapter_n", ch.number)).font(.toon(.caption, .bold)).foregroundStyle(Noir.amber)
                        Text(verbatim: t(ChapterText.title(ch.number))).font(.display(.title2))
                    }
                }
                Text(verbatim: t(ChapterText.intro(ch.number))).font(.toon(.body)).fixedSize(horizontal: false, vertical: true)
                Panel(.paper) {
                    Text(verbatim: t("l4_goals")).font(.toon(.headline))
                    ForEach(ch.goals) { goal in
                        let p = Flow.goalProgress(s, goal)
                        let done = Flow.goalDone(s, goal)
                        HStack(spacing: Noir.s2) {
                            Image(SceneArt.goal(goal.kind)).resizable().frame(width: 40, height: 40)
                                .saturation(done ? 1 : 0.6).accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(verbatim: ChapterText.goal(goal, t)).font(.toon(.subheadline)).fixedSize(horizontal: false, vertical: true)
                                if !done && p.target > 1 {
                                    Meter(fraction: min(1, p.current / p.target), tint: Noir.paperGold, height: 4)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Image(done ? "CheckDone" : "CheckOpen").resizable().frame(width: 26, height: 26).accessibilityHidden(true)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("goal.\(goal.id)")
                    }
                }
                if let who = ch.joins {
                    Label { Text(verbatim: t("l4_chapter_reward", Content.crewDef(SpecialistText.crew(who))?.name ?? "", t(SpecialistText.role(who)))) } icon: {
                        Image("IconHire").resizable().frame(width: 22, height: 22)
                    }
                    .font(.toon(.subheadline)).foregroundStyle(Noir.brass).fixedSize(horizontal: false, vertical: true)
                }
                Text(verbatim: t("l4_chapter_bonus", t.percent(FlowContent.chapterBonus - 1))).font(.toon(.footnote)).foregroundStyle(Noir.inkSoft)
                Button {
                    if store.dispatch(.closeChapter) != nil { dismiss() }
                } label: { Text(verbatim: t("l4_chapter_close")) }
                .noirButton(.primary)
                .disabled(!Flow.chapterComplete(s))
                .accessibilityIdentifier("chapter.close")
            }
        }
    }
}

/// The story moment after a chapter closes: what happened, who joins, what opens.
struct ChapterNewsSheet: View {
    let number: Int
    @Environment(LedgerStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let ch = FlowContent.chapter(number)
        ScrollView {
            VStack(alignment: .leading, spacing: Noir.s4) {
                Image(SceneArt.chapter(number, outro: true)).resizable().scaledToFill()
                    .frame(height: 200).frame(maxWidth: .infinity).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: Noir.corner, style: .continuous))
                    .accessibilityHidden(true)
                Text(verbatim: t("l4_chapter_closed", number)).font(.toon(.caption, .bold)).foregroundStyle(Noir.amber)
                Text(verbatim: t(ChapterText.title(number))).font(.display(.title)).accessibilityIdentifier("chapter.news")
                Text(verbatim: t(ChapterText.outro(number))).font(.toon(.body)).fixedSize(horizontal: false, vertical: true)
                if let who = ch?.joins {
                    Panel(.leather) {
                        HStack(spacing: Noir.s3) {
                            Portrait(crewId: SpecialistText.crew(who), size: 56, mood: .happy).clipShape(Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: t("l4_joins", Content.crewDef(SpecialistText.crew(who))?.name ?? "")).font(.toon(.headline))
                                Text(verbatim: t(SpecialistText.effect(who))).font(.toon(.caption)).foregroundStyle(Noir.inkSoft)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                if let next = FlowContent.chapter(number + 1) {
                    Text(verbatim: t("l4_next_chapter", t(ChapterText.title(next.number)))).font(.toon(.subheadline, .semibold))
                } else {
                    Text(verbatim: t("l4_finale_done")).font(.toon(.subheadline, .semibold))
                }
                Button { store.dispatch(.seenChapter) } label: { Text(verbatim: t("btn_continue")) }
                    .noirButton(.primary)
                    .accessibilityIdentifier("chapter.news.ok")
            }
            .padding(Noir.s4)
        }
        .background { SheetBackdrop() }
    }
}

// MARK: - Challenges

struct ChallengesSheet: View {
    @Environment(LedgerStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let s = store.state
        SheetFrame("l4_challenges", identifier: "screen.challenges") {
            Text(verbatim: t("l4_challenges_b")).font(.toon(.subheadline)).foregroundStyle(Noir.inkSoft).fixedSize(horizontal: false, vertical: true)
            if let c = s.challenge {
                Panel(.leather) {
                    Image(SceneArt.challenge(c.id)).resizable().scaledToFill()
                    .frame(height: 130).frame(maxWidth: .infinity).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: Noir.corner, style: .continuous))
                    .accessibilityHidden(true)
                    Text(verbatim: t(ChallengeText.name(c.id))).font(.toon(.headline))
                    Text(verbatim: t("l4_challenge_left", t.duration(max(0, c.endsAt - s.time)))).font(.toon(.subheadline)).monospacedDigit()
                    ForEach(0..<3, id: \.self) { i in
                        Label { Text(verbatim: t(ChallengeText.goal(c.id, i), t.money(c.target))) } icon: {
                            Image(c.goalsDone[i] ? "CheckDone" : "CheckOpen").resizable().frame(width: 20, height: 20)
                        }
                        .font(.toon(.caption))
                    }
                }
            }
            ForEach(FlowContent.challenges) { def in
                Panel(.anthracite) {
                    HStack(spacing: Noir.s2) {
                        Image(SceneArt.challenge(def.id, icon: true)).resizable().frame(width: 40, height: 40).accessibilityHidden(true)
                        Text(verbatim: t(ChallengeText.name(def.id))).font(.toon(.headline))
                        Spacer()
                        if s.challengesDone.contains(def.id) {
                            StatusChip(text: t("l4_challenge_won"), symbol: "checkmark.seal.fill")
                        }
                    }
                    Text(verbatim: t(ChallengeText.desc(def.id))).font(.toon(.caption)).foregroundStyle(Noir.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(verbatim: t("l4_challenge_rewards", def.rewards.reduce(0, +), t.percent(FlowContent.challengeBonus)))
                        .font(.toon(.caption, .semibold)).foregroundStyle(Noir.amber)
                    Button { store.dispatch(.startChallenge(def.id)) } label: { Text(verbatim: t("l4_challenge_start")) }
                        .noirButton(.primary)
                        .disabled(s.challenge != nil)
                        .accessibilityIdentifier("challenge.\(def.id.rawValue)")
                }
            }
        }
    }
}
