import SwiftUI
import MajiangKit

/// 核对：一页里核对牌面、补上照片看不出来的（自摸还是荣和、少见情况、宝牌）。
/// 拿不准的牌一次问一张；凑不成和牌时原地说最可能认错了哪张。
struct CheckView: View {
    @Environment(AppModel.self) private var model
    @Bindable var flow: RoundFlow
    var finish: (HandOutcome) -> Void

    @State private var editing: EditTarget?
    @State private var actionTile: Int?
    @State private var actionMeld: Int?
    @State private var confirmFalseWin = false
    @State private var rareOpen = false
    @State private var countingDora = false
    /// 牌一张张落进格子里（从拍照页升上来时）。
    @State private var landed = false
    /// 再认一遍时牌从这个时刻开始翻，等落定以后。
    @State private var flipStart = Date()
    /// 再认一遍等久了才给「不等了」。
    @State private var canSkip = false
    @State private var showPhoto = false
    @State private var showInvite = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum EditTarget: Identifiable {
        case replace(Int)
        case insert(after: Int)
        case add
        case meld

        var id: String {
            switch self {
            case .replace(let i): "replace-\(i)"
            case .insert(let i): "insert-\(i)"
            case .add: "add"
            case .meld: "meld"
            }
        }
    }

    private var game: Game { flow.game }
    private var winnerName: String { game.players[flow.winner].name }

    /// 这一页有多宽（不用屏幕宽度：Duo 分屏时窗口比屏幕窄）。
    @State private var pageWidth: CGFloat = 0

    /// 点了「荣和」、还没在小桌上点放铳的人。
    @State private var choosingDiscarder = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 20)
                // 认出的牌摆在一条绿毡上，像桌上真的牌；点哪张换哪张
                feltStrip
                    .padding(.top, 10)
                VStack(alignment: .leading, spacing: 0) {
                notes
                inviteLine

                if flow.isReviewing {
                    reviewingLine.padding(.top, 14)
                } else if let index = flow.firstPending {
                    QuestionCard(flow: flow, index: index) { editing = .replace(index) }
                        .padding(.top, 18)
                } else if !flow.tiles.isEmpty && !flow.isValidWin {
                    problemCard.padding(.top, 18)
                } else if flow.tiles.isEmpty {
                    // 手动输入还没加牌时，和错了也要能直接记
                    falseWinLink().padding(.top, 8)
                }

                howWon
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 24)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { pageWidth = $0 }
        .bottomBar {
            ScoreBar(flow: flow)
        }
        .page()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarRole(.editor)
        // 核对页盖在拍照页上，不在导航栈里，返回键自己放；系统的返回键和导航栏都藏掉
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $editing) { target in sheet(for: target) }
        .sheet(isPresented: $rareOpen) { rareSheet }
        // 牌摆上绿毡时很轻地震一下
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: landed) { _, new in new }
        .onAppear {
            if model.demoScreen == .doraSheet { countingDora = true }
        }
        // 换了牌以后，原来选的和牌不能和了，就挑一张最可能的
        .onChange(of: flow.tiles.map(\.tile), initial: true) { _, _ in flow.settleWinningTile() }
        .task {
            // 等页面淡入再摆牌（onAppear 里直接改，第一帧还没画，看不到动画）
            flipStart = Date().addingTimeInterval(reduceMotion ? 0 : 1.3)
            try? await Task.sleep(for: .seconds(0.3))
            landed = true
        }
        .task(id: flow.isReviewing) {
            canSkip = false
            guard flow.isReviewing else { return }
            // 九成 16 秒内认完，12 秒还没好才给出口
            try? await Task.sleep(for: .seconds(12))
            if !Task.isCancelled { canSkip = true }
        }
        .fullScreenCover(isPresented: $showPhoto) {
            if let photo = flow.photo {
                PhotoViewer(photo: photo) { showPhoto = false }
            }
        }
        .sheet(isPresented: $showInvite) { InviteView() }
        .sheet(isPresented: $flow.showResult) {
            ResultSheet(flow: flow, finish: finish)
        }
        .confirmationDialog(actionTitle, isPresented: Binding(get: { actionTile != nil }, set: { if !$0 { actionTile = nil } }),
                            titleVisibility: .visible, presenting: actionTile) { index in
            Button("换一张") { editing = .replace(index) }
            if index != winningIndex {
                Button("这张是和的那张") { flow.winningIndex = index }
            }
            Button("在后面加一张") { editing = .insert(after: index) }
            Button("删掉这张", role: .destructive) { flow.remove(at: index) }
        }
        .confirmationDialog("删掉这组？", isPresented: Binding(get: { actionMeld != nil }, set: { if !$0 { actionMeld = nil } }),
                            titleVisibility: .visible, presenting: actionMeld) { index in
            Button("删掉", role: .destructive) {
                if flow.melds.indices.contains(index) { flow.melds.remove(at: index) }
            }
        }
        .confirmationDialog(flow.winnerChosen ? "\(winnerName)和错了？" : "谁和错了？",
                            isPresented: $confirmFalseWin, titleVisibility: .visible) {
            if flow.winnerChosen {
                Button(tr("记下：赔三家各 \(game.rules.falseWinPenalty) 点", "記録：他家に各 \(game.rules.falseWinPenalty) 点", "Record: pay \(game.rules.falseWinPenalty) pts each"), role: .destructive) {
                    finish(.falseWin(offender: flow.winner))
                }
            } else {
                ForEach(0..<4, id: \.self) { i in
                    Button(game.players[i].name, role: .destructive) { finish(.falseWin(offender: i)) }
                }
            }
        } message: {
            Text("这一局不算打完，接着打。")
        }
        .onChange(of: flow.selfDrawn) { _, _ in
            // 换了自摸 / 荣和，不再可能的少见情况自动去掉
            flow.specials = flow.specials.filter { flow.isAvailable($0) }
        }
    }

    private var subtitle: String {
        let who = flow.winnerChosen ? tr("\(winnerName)和了 · ", "\(winnerName) 和了・", "\(winnerName) won · ") : ""
        if flow.source == "手动输入" { return who + tr("手动输入", "手動入力", "Manual entry") }
        // 演示数据不看照片，一定要说清楚，不然会以为是认错了（截图模式除外）
        if flow.source == "演示" && DemoScreen.current == nil {
            return tr("演示数据，没看你的照片 · 在「更多」里填 Key", "デモデータ（写真は未解析）", "Demo data (photo not analyzed)")
        }
        let count = who + tr("认出 \(flow.hand.allTiles.count) 张", "\(flow.hand.allTiles.count)枚を認識", "Recognized \(flow.hand.allTiles.count) tiles")
        if flow.isReviewing { return count }
        if flow.source == "双读" {
            return count + (flow.reviewAtLoad == 0
                            ? tr(" · 两遍读得一样", "・2回の認識が一致", " · Verified")
                            : tr(" · \(flow.reviewAtLoad) 张两遍不一样", "・\(flow.reviewAtLoad)枚に差異あり", " · \(flow.reviewAtLoad) tile(s) to check"))
        }
        return count
    }

    private var winningIndex: Int? { flow.winningIndex ?? flow.tiles.indices.last }

    private var actionTitle: String {
        guard let i = actionTile, flow.tiles.indices.contains(i) else { return "" }
        return "第 \(i + 1) 张 · \(flow.tiles[i].tile.displayName)"
    }

    // MARK: 照片

    /// 标题右边一张小图，点开全屏看：核对时要对照照片，不用退回去重拍。
    @ViewBuilder
    private var photoThumbnail: some View {
        if let photo = flow.photo {
            Button { showPhoto = true } label: {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.line))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            .accessibilityLabel("看拍的照片")
        }
    }

    /// 没邀请码、用离线认牌时，这手牌要动手改过、牌也对了，才提一句 AI 认牌。拍照页不提，免得打扰。
    @ViewBuilder
    private var inviteLine: some View {
        if model.needsInvite && flow.source != "手动输入" && flow.corrections > 0
            && !flow.isReviewing && flow.firstPending == nil && flow.isValidWin {
            Button { showInvite = true } label: {
                Text("这手有 \(flow.corrections) 处要你动手改。有邀请码可以开 AI 认牌，更准 ›")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.gray)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
    }

    // MARK: 牌面

    /// 不成和时最可能认错的那张，标成朱红虚线。
    private var suspect: Int? {
        guard flow.firstPending == nil, !flow.isValidWin else { return nil }
        return flow.suggestions.first?.index
    }

    private var canAddTile: Bool { flow.tiles.count + 3 * flow.melds.count < 14 }

    /// 顶上一行：左边回去重拍，右边认出几张、拍的照片。
    private var header: some View {
        HStack(spacing: 12) {
            Button { flow.steps.removeAll() } label: {
                HStack(spacing: 3) {
                    Image(systemName: "chevron.left").font(.system(size: 17, weight: .semibold))
                    Text(tr("重拍", "撮り直す", "Retake"))
                }
                .font(.system(size: 17))
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Spacer()
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(Theme.gray)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            photoThumbnail
        }
    }

    /// 和的是哪张会影响翻符时才问：那几张亮着，别的暗一点，点一下选；翻符都一样就不问。
    private var askingWinningTile: Bool {
        !flow.isReviewing && flow.firstPending == nil && flow.winningTileMatters
    }

    /// 一条绿毡，牌一张张摆上去（从左往右推进来，像发牌）。不要求和的那张放最右。
    private var feltStrip: some View {
        FeltBanner {
            VStack(spacing: 12) {
                let width = stripTileWidth
                let asking = askingWinningTile
                let candidates = Set(flow.winningCandidates.map { flow.tiles[$0.index].tile })
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(Array(flow.tiles.enumerated()), id: \.element.id) { index, tile in
                        let isCandidate = candidates.contains(tile.tile)
                        Button {
                            // 问和的是哪张时，点亮着的牌就是选它；点已经选中的那张才是换牌
                            if asking && isCandidate && index != winningIndex {
                                flow.winningIndex = index
                            } else {
                                actionTile = index
                            }
                        } label: {
                            FlippingTile(index: index, width: width, active: flow.isReviewing, start: flipStart) {
                                TileFace(tile: tile.tile, width: width,
                                         state: tile.needsReview ? .doubt : index == suspect ? .wrong : .normal)
                            }
                            .overlay(alignment: .bottom) {
                                if asking && index == winningIndex {
                                    Capsule().fill(.white).frame(width: width * 0.5, height: 3).offset(y: 8)
                                        .accessibilityLabel("和的那张")
                                }
                            }
                            .opacity(asking && !isCandidate ? 0.45 : 1)
                            .offset(y: asking && index == winningIndex ? -4 : 0)
                            .animation(.snappy(duration: 0.2), value: winningIndex)
                        }
                        .buttonStyle(.plain)
                        .disabled(flow.isReviewing)
                        .opacity(landed || reduceMotion ? 1 : 0)
                        .offset(x: landed || reduceMotion ? 0 : -18)
                        .animation(.easeOut(duration: 0.28).delay(Double(index) * 0.035), value: landed)
                    }
                    if canAddTile && !flow.isReviewing {
                        Button { editing = .add } label: {
                            RoundedRectangle(cornerRadius: width * 0.16, style: .continuous)
                                .strokeBorder(.white.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                                .frame(width: width, height: (width * 1.32).rounded())
                                .overlay(Image(systemName: "plus").font(.system(size: width * 0.45)).foregroundStyle(.white.opacity(0.8)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("加一张")
                    }
                }
                .padding(.horizontal, 12)
                if !flow.melds.isEmpty {
                    HStack(spacing: 12) {
                        ForEach(Array(flow.melds.enumerated()), id: \.offset) { index, meld in
                            Button { actionMeld = index } label: {
                                HStack(spacing: 1) {
                                    ForEach(Array(meld.tiles.enumerated()), id: \.offset) { _, tile in
                                        TileFace(tile: tile, width: min(width, 22))
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(meld.kindName + meld.displayText)
                        }
                    }
                }
                HStack(spacing: 14) {
                    Text(stripHint)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.8))
                    if !flow.isReviewing {
                        Button { editing = .meld } label: {
                            Text(tr("+ 吃碰杠", "+ 鳴き", "+ Meld"))
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 10)
                                .frame(height: 26)
                                .background(.white.opacity(0.16), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 16)
        }
    }

    /// 一排放得下 14 张（有杠时再多几张）：按页面宽度算，最大 28。
    private var stripTileWidth: CGFloat {
        let width = min(pageWidth > 0 ? pageWidth : 390, Theme.columnWidth) - 24
        let count = CGFloat(flow.tiles.count + 1) + 0.45
        return max(16, min(28, ((width - count * 2) / count).rounded(.down)))
    }

    private var stripHint: String {
        if flow.isReviewing { return tr("每张再认一遍，几秒就好", "もう一度読み取り中…", "Double-checking each tile…") }
        if flow.firstPending != nil { return tr("点一张牌就能换 · 红框那张看不太清", "タップで差し替え・赤枠は不鮮明", "Tap a tile to swap · red frame = unclear") }
        if askingWinningTile {
            return tr("和的是哪张？亮着的几张算出来不一样，点一下", "和了牌はどれ？明るい牌で点数が変わります", "Which tile won? The lit tiles score differently")
        }
        return tr("点一张牌就能换", "タップで差し替え", "Tap a tile to swap")
    }

    /// 识别时的说明（画面里有别的牌没算、副露两边读得不一样、Gemini 没复核上……）。
    @ViewBuilder
    private var notes: some View {
        if !flow.notes.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(flow.notes, id: \.self) { note in
                    Text(note)
                }
            }
            .font(.system(size: 14))
            .foregroundStyle(Theme.gray)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 10)
        }
    }

    /// 第一遍已经读出来了，后台再认一遍：牌在上面翻，这里只说一句。
    private var reviewingLine: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("每张翻过来再认一遍，几秒就好。可以先选下面谁和的、怎么和的。")
                .font(.system(size: 14))
                .foregroundStyle(Theme.gray)
                .fixedSize(horizontal: false, vertical: true)
            if canSkip {
                // 偶尔会卡到超时（一分钟），不让人干等
                Button("不等了，就用现在这些牌 ›") {
                    flow.cancelRecognition()
                    flow.notes.append(tr("没等第二遍认完，只有第一遍的读法，对照照片看一眼",
                                         "2回目の読み取りをスキップしました。写真と見比べて確認してください",
                                         "Skipped second pass; please double-check the tiles against the photo"))
                }
                .buttonStyle(.text(size: 14))
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.3), value: canSkip)
    }

    // MARK: 不成和

    private var problemCard: some View {
        let suggestion = flow.suggestions.first
        let minimum = game.rules.minimumFan
        var title = tr("还凑不成和牌", "まだ和了形になっていません", "Not a valid winning hand yet")
        var reason: Text
        switch flow.scoring {
        case .success(let result):
            title = result.fanWithoutDora == 0
                ? tr("无役，立直麻将至少要有 \(minimum) 翻役才能和",
                     "役なし（和了には最低 \(minimum) 翻の役が必要です）",
                     "No Yaku (at least \(minimum) han of yaku required)")
                : tr("只有 \(result.fanWithoutDora) 翻役，本场要 \(minimum) 翻才能和",
                     "役が \(result.fanWithoutDora) 翻のみ（この対局は \(minimum) 翻縛り）",
                     "Only \(result.fanWithoutDora) han of yaku (\(minimum)-han minimum)")
            reason = Text("牌型没问题。如果这手立直了，在下面点一下「立直」；宝牌每张加 1 翻，但不算进起和役。")
        case .failure(.wrongTileCount):
            reason = Text("和牌一共 14 张（每个杠多 1 张），现在是 \(flow.hand.allTiles.count) 张。")
        case .failure(.tileMoreThanFour):
            reason = Text("\(flow.hand.overusedTiles.map(\.displayName).joined(separator: "、")) 超过了 4 张，一定有牌认错了。")
        case .failure:
            reason = Text("和牌要 4 面子加 1 雀头（或七对子、国士无双），这 \(flow.hand.allTiles.count) 张凑不出来。")
        }
        if let suggestion, let index = suggestion.index {
            reason = reason + Text("最可能是") + Text("第 \(index + 1) 张").fontWeight(.semibold).foregroundStyle(.white)
                + Text("认错了：改成 \(suggestion.to.displayName) 就能和。")
        } else if let suggestion {
            reason = reason + Text("好像少认了一张：补一张 \(suggestion.to.displayName) 就能和。")
        } else if case .failure = flow.scoring {
            reason = reason + Text(flow.photo == nil ? "改一张也凑不成，可能不止一张认错了，对照桌上的牌再看看。"
                                    : "改一张也凑不成，可能不止一张认错了，点右上角的照片对照着再看看。")
        }

        // 绿毡上的一块：标题、原因；能改一张就和时，摆出「这张 → 那张」，点一下换上
        return VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.system(size: 17, weight: .semibold))
            reason
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.85))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
            if let suggestion {
                HStack(spacing: 12) {
                    if let index = suggestion.index, flow.tiles.indices.contains(index) {
                        TileFace(tile: flow.tiles[index].tile, width: 32, state: .wrong)
                    } else {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(.white.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            .frame(width: 32, height: 42)
                    }
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                    TileFace(tile: suggestion.to, width: 32)
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 3)
                    Spacer(minLength: 4)
                    Button {
                        flow.apply(suggestion)
                    } label: {
                        Text(suggestion.index == nil ? tr("补上", "補う", "Add it") : tr("换上", "差し替え", "Swap in"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.tileInk)
                            .padding(.horizontal, 18)
                            .frame(height: 40)
                            .background(.white, in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(PressFade())
                    Button { editing = suggestion.index.map { .replace($0) } ?? .add } label: {
                        Text(tr("自己改", "自分で", "Pick"))
                            .font(.system(size: 14))
                            .padding(.horizontal, 12)
                            .frame(height: 40)
                            .background(.white.opacity(0.16), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 14)
            }
            Rectangle().fill(.white.opacity(0.15)).frame(height: 0.5)
                .padding(.top, 14)
                .padding(.bottom, 10)
            falseWinLink(onFelt: true)
        }
        .feltCard()
    }

    private func falseWinLink(onFelt: Bool = false) -> some View {
        Button {
            confirmFalseWin = true
        } label: {
            Text(flow.tiles.isEmpty
                 ? tr("其实是和错了？记下来（赔三家各 \(game.rules.falseWinPenalty) 点）›", "実はチョンボ？記録する（他家に各 \(game.rules.falseWinPenalty) 点）›", "Actually a false win? Record it (\(game.rules.falseWinPenalty) pts to each) ›")
                 : tr("牌没认错，是真的和错了？记下来（赔三家各 \(game.rules.falseWinPenalty) 点）›", "牌は正しく、本当にチョンボ？記録する（他家に各 \(game.rules.falseWinPenalty) 点）›", "Tiles are right but it's a false win? Record it (\(game.rules.falseWinPenalty) pts to each) ›"))
                .font(.system(size: 13))
                .foregroundStyle(onFelt ? .white.opacity(0.7) : Theme.gray)
                .multilineTextAlignment(.leading)
        }
        .buttonStyle(.plain)
    }

    // MARK: 谁和了、怎么和的、桌上的筹码

    private var shapeBroken: Bool {
        if case .failure = flow.scoring { return true }
        return false
    }

    /// 左边一张小牌桌，点座位选谁和了（荣和时再点放铳的人）；右边自摸 / 荣和。下面一块绿毡放立直棒、一发、宝牌这些。
    @ViewBuilder
    private var howWon: some View {
        SectionLabel(tr("谁和了、怎么和的", "和了した人と和了り方", "Who won, and how"))
            .padding(.top, 26)
            .padding(.bottom, 10)
        HStack(alignment: .center, spacing: 16) {
            SeatPicker(game: game,
                       winner: flow.winnerChosen ? flow.winner : nil,
                       discarder: flow.wayChosen && !flow.selfDrawn ? flow.discarder : nil,
                       pickingDiscarder: choosingDiscarder) { player in
                if choosingDiscarder, flow.winnerChosen, player != flow.winner {
                    flow.pickDiscarder(player)
                    choosingDiscarder = false
                } else {
                    flow.pickWinner(player)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    wayButton(tr("自摸", "ツモ", "Tsumo"), on: flow.wayChosen && flow.selfDrawn) {
                        flow.pickSelfDrawn()
                        choosingDiscarder = false
                    }
                    wayButton(tr("荣和", "ロン", "Ron"), on: choosingDiscarder || (flow.wayChosen && !flow.selfDrawn)) {
                        choosingDiscarder = true
                    }
                }
                .disabled(!flow.winnerChosen)
                .opacity(flow.winnerChosen ? 1 : 0.45)
                if let wayNote {
                    Text(wayNote)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.gray)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        // 牌还凑不成和的时候，先改牌
        .opacity(shapeBroken ? 0.5 : 1)
        .disabled(shapeBroken)

        SectionLabel(tr("放到桌上的", "卓に置くもの", "On the table"))
            .padding(.top, 24)
            .padding(.bottom, 10)
        tokens
    }

    private func wayButton(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: on ? .semibold : .regular))
                .foregroundStyle(on ? Color.white : Theme.ink)
                .frame(maxWidth: .infinity, minHeight: 42)
                .background(on ? Theme.fill : Theme.card, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private var wayNote: String? {
        if !flow.winnerChosen { return tr("在小桌上点和了的人。", "小さな卓で和了した人をタップ。", "Tap the winner on the little table.") }
        if choosingDiscarder { return tr("再在小桌上点放铳的人。", "放銃した人をタップ。", "Now tap who dealt in.") }
        if model.isSeasoned { return nil }
        if !flow.wayChosen {
            return tr("自己摸到的选「自摸」；和的是别人打出的牌，选「荣和」再点放铳的人。",
                      "自分で引いたら「ツモ」、他家の捨牌なら「ロン」で放銃者を選びます。",
                      "Tsumo if self-drawn; Ron, then tap who discarded it.")
        }
        if flow.selfDrawn { return tr("自摸：三家都要付。", "ツモ：他家3人が支払い。", "Tsumo: all three others pay.") }
        let dName = flow.discarder.map { game.players[$0].name } ?? tr("别人", "他家", "another player")
        return tr("荣和：\(dName)放铳。", "ロン：\(dName)が放銃。", "Ron off \(dName).")
    }

    private var availableRare: [SpecialWin] { SpecialWin.allCases.filter { flow.isAvailable($0) } }
    /// 收在「其他」里的少见情况（立直、一发直接摆在桌上）。
    private var otherRareOptions: [SpecialWin] { availableRare.filter { $0 != .riichi && $0 != .ippatsu } }

    /// 桌上的筹码：一根立直棒（点一下放上 / 拿掉）、一发、宝牌数，「其他」点开是双立直、岭上这些少见情况。
    private var tokens: some View {
        let riichiOn = flow.specials.contains(.riichi) || flow.specials.contains(.doubleRiichi)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom, spacing: 14) {
                if flow.isAvailable(.riichi) || riichiOn {
                    token(flow.specials.contains(.doubleRiichi) ? SpecialWin.doubleRiichi.name : SpecialWin.riichi.name, on: riichiOn) {
                        RiichiStickIcon(width: 52, height: 7, borderColor: .clear)
                            .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
                            .frame(height: 24)
                    } action: {
                        if riichiOn {
                            flow.specials.subtract([.riichi, .doubleRiichi, .ippatsu])
                        } else {
                            flow.specials.insert(.riichi)
                        }
                    }
                }
                if riichiOn && flow.isAvailable(.ippatsu) {
                    let on = flow.specials.contains(.ippatsu)
                    token(SpecialWin.ippatsu.name, on: on) {
                        chipFace(tr("一发", "一発", "Ippatsu"), on: on).frame(height: 24)
                    } action: {
                        if on { flow.specials.remove(.ippatsu) } else { flow.specials.insert(.ippatsu) }
                    }
                }
                if !otherRareOptions.isEmpty || flow.winnerChosen {
                    token(tr("其他", "その他", "More"), on: rareOpen || rareCount > 0) {
                        chipFace(rareCount > 0 ? "+\(rareCount)" : "+", on: rareCount > 0).frame(height: 24)
                    } action: {
                        rareOpen = true
                    }
                }
                Spacer(minLength: 0)
                if game.rules.includeDora { dora }
            }
        }
        .padding(16)
        .foregroundStyle(.white)
        .background(FeltTexture().clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)))
    }

    private var rareCount: Int {
        otherRareOptions.filter { flow.specials.contains($0) }.count + flow.riichiPlayers.subtracting([flow.winner]).count
    }

    /// 一个筹码：上面是东西本身，下面一行字；选上了字后面打个勾。
    private func token<Face: View>(_ title: String, on: Bool, @ViewBuilder face: () -> Face, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                face().opacity(on ? 1 : 0.4)
                Text(title + (on ? " ✓" : ""))
                    .font(.system(size: 12, weight: on ? .semibold : .regular))
                    .foregroundStyle(.white.opacity(on ? 1 : 0.75))
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// 绿毡上的小片：选上是白底，没选是白色虚线框。
    private func chipFace(_ text: String, on: Bool) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(on ? Theme.tileInk : .white)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 10)
            .frame(height: 22)
            .background(on ? Color.white : Color.clear, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(on ? 0 : 0.7), style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
    }

    /// 宝牌：点牌面打开「翻指示牌」（表宝、杠宝、立直时的里宝，赤五自动算），下面加减手动调。
    private var dora: some View {
        VStack(spacing: 6) {
            Button { countingDora = true } label: {
                TileFace(tile: Tile.parseList("0p").first ?? Tile(suit: .dots, rank: 5)!, width: 18)
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(tr("翻宝牌指示牌", "ドラ表示牌", "Dora indicators"))
            HStack(spacing: 8) {
                stepButton("minus", label: "少一张") { flow.stepDora(by: -1) }
                    .disabled(flow.doraTotal == 0)
                Text(tr("宝牌 \(flow.doraTotal)", "ドラ \(flow.doraTotal)", "Dora \(flow.doraTotal)"))
                    .font(Theme.score(12))
                    .lineLimit(1)
                    .fixedSize()
                stepButton("plus", label: "多一张") { flow.stepDora(by: 1) }
                    .disabled(flow.doraTotal >= 30)
            }
        }
        .accessibilityElement(children: .contain)
        .sheet(isPresented: $countingDora) { DoraSheet(flow: flow) }
    }

    private func stepButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .frame(width: 22, height: 22)
                .background(.white.opacity(0.16), in: Circle())
                .contentShape(Circle().inset(by: -8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// 「其他」：一小页绿毡，放少见的役和别家的立直棒。
    private var rareSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(tr("其他", "その他", "More"))
                .font(.system(size: 20, weight: .bold))
            rareChips
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(.white)
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.visible)
        .presentationBackground { FeltTexture() }
    }

    /// 「其他」里面：少见的役（双立直、岭上、海底……）和别家也立直了。
    private var rareChips: some View {
        VStack(alignment: .leading, spacing: 10) {
            FlowLayout(spacing: 8) {
                ForEach(otherRareOptions, id: \.self) { special in
                    let on = flow.specials.contains(special)
                    Button {
                        if on {
                            flow.specials.remove(special)
                        } else {
                            flow.specials.subtract(special.conflicts)
                            flow.specials.insert(special)
                        }
                    } label: {
                        chipFace("\(special.name) · \(special.fanPoints)", on: on)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            if flow.winnerChosen {
                Text(tr("别家也立直了？每家的立直棒归和牌的人", "他家もリーチ？リーチ棒は和了者へ", "Others in riichi? Their sticks go to the winner"))
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.75))
                FlowLayout(spacing: 8) {
                    ForEach((0..<4).filter { $0 != flow.winner }, id: \.self) { i in
                        let on = flow.riichiPlayers.contains(i)
                        Button {
                            if on { flow.riichiPlayers.remove(i) } else { flow.riichiPlayers.insert(i) }
                        } label: {
                            chipFace(game.players[i].name, on: on)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
            }
        }
    }

    // MARK: 改牌

    @ViewBuilder
    private func sheet(for target: EditTarget) -> some View {
        switch target {
        case .replace(let index) where flow.tiles.indices.contains(index):
            TileEditSheet(title: "第 \(index + 1) 张是", current: flow.tiles[index].tile) { flow.choose($0, at: index) }
        case .insert(let index):
            TileEditSheet(title: "在第 \(index + 1) 张后面加", current: nil) { flow.insert($0, after: index) }
        case .add:
            TileEditSheet(title: "加一张", current: nil) { flow.append($0) }
        case .meld:
            MeldEditSheet { flow.melds.append($0) }
        default:
            EmptyView()
        }
    }
}

/// 拿不准的一张：「第 13 张看不太清，是哪个？」，候选旁边说选了能不能和。
/// 只有一边读到的牌问「照片里有这张吗」，多一个「没有这张」。
private struct QuestionCard: View {
    var flow: RoundFlow
    var index: Int
    var other: () -> Void

    private var tile: RecognizedTile { flow.tiles[index] }
    private var candidates: [Tile] { Array(tile.candidates.prefix(tile.uncertain ? 3 : 4)) }
    private var onlyOneSide: Bool { tile.uncertain && tile.alternatives.isEmpty }

    /// 拿不准的那张从绿毡上拿起来（斜一点、有影子），候选的牌摆在下面，标着选了能不能和。
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                TileFace(tile: tile.tile, width: 40, state: .doubt)
                    .rotationEffect(.degrees(-6))
                    .shadow(color: .black.opacity(0.35), radius: 8, y: 8)
                    .offset(y: -2)
                VStack(alignment: .leading, spacing: 3) {
                    Text(onlyOneSide
                         ? tr("这张可能是多认的", "余分に認識した可能性", "This one might be extra")
                         : tr("这张看不太清", "この牌が不鮮明です", "This tile is unclear"))
                        .font(.system(size: 17, weight: .semibold))
                    Text(onlyOneSide
                         ? tr("第 \(index + 1) 张 · 照片里有这张吗？", "\(index + 1)枚目・写真にありますか？", "Tile #\(index + 1) · Is it in the photo?")
                         : tr("第 \(index + 1) 张 · 是下面哪一张？", "\(index + 1)枚目・どれですか？", "Tile #\(index + 1) · Which one is it?"))
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            HStack(alignment: .top, spacing: 14) {
                ForEach(candidates, id: \.self) { candidate in
                    option(title: onlyOneSide ? tr("有这张", "ある", "Present") : candidate.displayName, wins: hint(for: candidate)) {
                        TileFace(tile: candidate, width: 36)
                    } action: {
                        flow.choose(candidate, at: index)
                    }
                }
                if tile.uncertain {
                    option(title: tr("没有这张", "ない", "Not there"), wins: removalHint) {
                        RoundedRectangle(cornerRadius: 36 * 0.16, style: .continuous)
                            .strokeBorder(.white.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            .frame(width: 36, height: 48)
                            .overlay(Image(systemName: "xmark").font(.system(size: 14)).foregroundStyle(.white.opacity(0.8)))
                    } action: {
                        flow.remove(at: index)
                    }
                }
                Spacer(minLength: 0)
            }
            Button(action: other) {
                Text(tr("都不是，自己选 ›", "どれでもない ›", "None of these ›"))
                    .font(.system(size: 13))
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(.white.opacity(0.16), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .feltCard()
    }

    /// 一张候选：牌、名字，下面一个小标签说选了能不能和（能和的牌描白圈）。
    private func option(title: String, wins: Bool?, @ViewBuilder face: () -> some View,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                face()
                    .padding(3)
                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(.white, lineWidth: wins == true ? 2 : 0))
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
                Text(title).font(.system(size: 12, weight: .medium)).lineLimit(1)
                if let wins {
                    Text(wins ? tr("能和", "和了可", "Wins") : tr("和不了", "不可", "No win"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(wins ? Theme.tileInk : .white.opacity(0.7))
                        .padding(.horizontal, 8)
                        .frame(height: 20)
                        .background(wins ? Color.white : Color.white.opacity(0.12), in: Capsule())
                }
            }
            .frame(minWidth: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressFade())
    }

    /// 只有这一张拿不准时，直接试一下能不能和；好几张都拿不准时，用规则引擎推荐的那组读法。
    private func hint(for tile: Tile) -> Bool? {
        if flow.pendingReviewCount == 1 { return flow.wins(with: tile, at: index) }
        if flow.recommendedRemovals.contains(index) { return false }
        guard let recommended = flow.recommended[index] else { return nil }
        return recommended == tile
    }

    private var removalHint: Bool? {
        if flow.pendingReviewCount == 1 { return flow.wins(removing: index) }
        if flow.recommendedRemovals.contains(index) { return true }
        return flow.recommended[index] == nil ? nil : false
    }
}

/// 全屏看拍的照片：双指放大、拖动，双击放大或复原。
private struct PhotoViewer: View {
    var photo: UIImage
    var close: () -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            Image(uiImage: photo)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(offset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    MagnifyGesture()
                        .onChanged { scale = min(5, max(1, lastScale * $0.magnification)) }
                        .onEnded { _ in
                            lastScale = scale
                            if scale == 1 { resetOffset() }
                        }
                )
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            guard scale > 1 else { return }
                            offset = CGSize(width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height)
                        }
                        .onEnded { _ in lastOffset = offset }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        scale = scale > 1 ? 1 : 2.5
                        lastScale = scale
                        if scale == 1 { resetOffset() }
                    }
                }
            Button("关闭", action: close)
                .buttonStyle(NavButtonStyle(color: .white))
                .padding(.horizontal, 20)
        }
        .statusBarHidden()
    }

    private func resetOffset() {
        offset = .zero
        lastOffset = .zero
    }
}

/// 小牌桌：四家按真实座次坐在四边，点座位选人。和了的人白圈，放铳的人黄圈。
private struct SeatPicker: View {
    var game: Game
    var winner: Int?
    var discarder: Int?
    var pickingDiscarder: Bool
    var pick: (Int) -> Void

    var body: some View {
        let hand = game.displayHand
        let order = game.seating(ofRound: game.roundIndex(ofHand: hand))
        let me = game.position(of: game.me, inHand: hand)
        let at = { (offset: Int) in order[(me + offset) % 4] }
        ZStack {
            FeltTexture()
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(centerText)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .frame(width: 64)
            seat(at(2), hand: hand).frame(maxHeight: .infinity, alignment: .top).padding(.top, 5)
            seat(at(0), hand: hand).frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, 5)
            seat(at(3), hand: hand).frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 4)
            seat(at(1), hand: hand).frame(maxWidth: .infinity, alignment: .trailing).padding(.trailing, 4)
        }
        .padding(7)
        .frame(width: 164, height: 164)
        .background(LinearGradient(colors: Theme.walnut, startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color(hex: 0x28190A).opacity(0.25), radius: 8, y: 6)
        .animation(.snappy(duration: 0.25), value: winner)
        .animation(.snappy(duration: 0.25), value: discarder)
        .sensoryFeedback(.selection, trigger: winner)
        .sensoryFeedback(.selection, trigger: discarder)
    }

    private var centerText: String {
        if let winner {
            let name = game.players[winner].name
            if let discarder { return tr("\(name) 和了\n\(game.players[discarder].name) 放铳", "\(name) 和了\n\(game.players[discarder].name) 放銃", "\(name) won\n\(game.players[discarder].name) dealt") }
            return pickingDiscarder ? tr("点放铳的人", "放銃者をタップ", "Tap who dealt in") : tr("\(name) 和了", "\(name) 和了", "\(name) won")
        }
        return tr("点和了的人", "和了者をタップ", "Tap the winner")
    }

    private func seat(_ player: Int, hand: Int) -> some View {
        let isWinner = winner == player
        let isDiscarder = discarder == player
        let ring: Color = isWinner ? .white : isDiscarder ? Color(hex: 0xFFD27A) : .clear
        return Button { pick(player) } label: {
            VStack(spacing: 1) {
                WindTile(text: Theme.tileGlyph(game.seatWind(of: player, inHand: hand)),
                         isDealer: game.dealer(ofHand: hand) == player, width: 19)
                Text(game.players[player].name)
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                    .frame(maxWidth: 46)
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(ring.opacity(isWinner || isDiscarder ? 0.2 : 0), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(ring, lineWidth: 2))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(game.players[player].name)
        .accessibilityAddTraits(isWinner || isDiscarder ? .isSelected : [])
    }
}

/// 核对页底部：左边几翻几符（还不能看时写原因），右边「看结果」带上这手赢多少。
private struct ScoreBar: View {
    @Bindable var flow: RoundFlow

    var body: some View {
        HStack(spacing: 10) {
            if let reason = flow.blockedReason {
                Text(reason)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.gray)
                    .frame(maxWidth: .infinity, minHeight: 54)
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    if case .success(let result) = flow.scoring {
                        Text(tr("\(result.totalFan) 翻 \(result.fu) 符", "\(result.totalFan)翻 \(result.fu)符", "\(result.totalFan) han \(result.fu) fu"))
                            .font(Theme.score(16))
                    }
                    if let record = flow.winRecord,
                       let limit = Payment.limitName(han: flow.game.rules.paidFan(record), fu: record.fu, kiriageMangan: flow.game.rules.kiriageMangan) {
                        Text(limit).font(.system(size: 12)).foregroundStyle(Theme.gray)
                    }
                }
                .padding(.leading, 16)
                Spacer(minLength: 8)
                Button { flow.showResult = true } label: {
                    HStack(spacing: 6) {
                        if let record = flow.winRecord, let deltas = flow.deltas, record.winner < deltas.count {
                            Text(Theme.signed(deltas[record.winner])).font(Theme.score(17))
                        } else {
                            Text(tr("看结果", "結果を見る", "See result"))
                        }
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold))
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .frame(minHeight: 46)
                    .background(Theme.fill, in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(PressFade())
                .accessibilityLabel(tr("看结果", "結果を見る", "See result"))
            }
        }
        .padding(5)
        .background(Theme.card, in: Capsule())
        .shadow(color: .black.opacity(0.08), radius: 14, y: 6)
    }
}

private extension View {
    /// 核对页的提示块：一小块绿毡，胡桃木细边，白字。
    func feltCard() -> some View {
        self
            .foregroundStyle(.white)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FeltTexture().clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .strokeBorder(LinearGradient(colors: Theme.walnut, startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 4)
            )
            .shadow(color: Color(hex: 0x28190A).opacity(0.18), radius: 8, y: 5)
    }
}
