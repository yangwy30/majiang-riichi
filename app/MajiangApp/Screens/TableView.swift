import SwiftUI
import MajiangKit

/// 牌桌，也是账本：上面按座位画四个人，往下滚是每一局的记录。
struct TableView: View {
    @Environment(AppModel.self) private var model
    let gameID: UUID

    @State private var recording = false
    @State private var drawingHand = false
    @State private var manualScoring = false
    @State private var showGuide = false
    @State private var editingRules = false
    @State private var confirmEnd = false
    @State private var pickingFalseWin = false
    /// 点开要改的那一局。
    @State private var editing: EditTarget?
    @State private var recordError: String?
    /// 刚记下的一局，底部显示 8 秒「撤销」（牌桌上大家还在说话，5 秒常常反应不过来）。
    @State private var justRecorded: HandRecord?
    @State private var undoTimer: Task<Void, Never>?
    /// 这一页有多高：矮屏方桌画小一点。
    @State private var pageHeight: CGFloat = 0
    /// 点了撤销就加一，触发一下轻震。
    @State private var undoCount = 0

    var body: some View {
        if let game = model.game(gameID) {
            content(game)
        } else {
            ContentUnavailableView("找不到这场牌局", systemImage: "questionmark")
        }
    }

    /// 从结算页点「看每一局」进来的回结算，平时回首页。
    private var backTitle: String {
        if model.path.count >= 2, case .settle = model.path[model.path.count - 2] { return "结算" }
        return "首页"
    }

    private func content(_ game: Game) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 家规跟国标不一样时才露一行，点开能改
                if let badge = game.rules.houseRuleBadge {
                    Button { editingRules = true } label: {
                        Text(badge + " ›")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.gray)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Theme.lineSoft, in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 2)
                }
                // 矮屏（iPhone Duo 外屏、SE、mini）方桌小一圈，账本多露出一行
                TableDiagram(game: game, compact: pageHeight > 0 && pageHeight < 700)
                    .padding(.top, 10)

                HStack(alignment: .firstTextBaseline) {
                    Text("账本").font(.system(size: 14, weight: .medium))
                    Spacer()
                    Text(game.isFinished
                         ? tr("打了 \(game.playedHandsCount) 局", "全\(game.playedHandsCount)局", "\(game.playedHandsCount) hands played")
                         : tr("打了 \(game.playedHandsCount) 局 · 还剩 \(game.remainingHands) 局",
                              "\(game.playedHandsCount)局消化・残り\(game.remainingHands)局",
                              "\(game.playedHandsCount) played · \(game.remainingHands) left"))
                        .font(.system(size: 14))
                }
                .foregroundStyle(Theme.gray)
                .padding(.top, 26)
                .padding(.bottom, 6)
                Hairline()

                if game.records.isEmpty {
                    Text("还没有记录。有人和了就点下面的按钮。")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.gray)
                        .padding(.vertical, 14)
                }
                ForEach(Array(game.records.enumerated().reversed()), id: \.element.id) { index, record in
                    // 和牌的局点进去看怎么和的（在里面也能改）；别的局直接改或删。打完的牌局也一样
                    Button {
                        open(record, number: index + 1)
                    } label: {
                        RecordRow(number: index + 1, record: record, game: game)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(record.isWin ? "点一下看这一局怎么和的" : "点一下可以改或删掉这一局")
                }
                if !game.records.isEmpty && !model.isSeasoned {
                    Text("点一局，看那把怎么和的；记错了也在里面改。")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.gray)
                        .padding(.top, 14)
                        .padding(.bottom, 8)
                }
            }
            .padding(.horizontal, 24)
        }
        .bottomBar {
            if let record = justRecorded {
                UndoBar(text: tr("已记下第 \(game.records.count) 局", "第\(game.records.count)局を記録しました", "Recorded hand #\(game.records.count)")) { undo(record) }
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if game.isFinished {
                Button("看结算") { settle(game) }
                    .buttonStyle(.primary)
            } else {
                Button("有人和了") { recording = true }
                    .buttonStyle(.primary)
                Button("这局没人和") { drawingHand = true }
                    .buttonStyle(.text)
            }
        }
        // 量在底部按钮区外面，量到的是整页（不含导航栏），不随撤销条出没变
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { pageHeight = $0 }
        .page()
        // 记下一局轻轻「成功」一下；撤销轻震一下
        .sensoryFeedback(.success, trigger: justRecorded?.id) { _, new in new != nil }
        .sensoryFeedback(.impact(weight: .light), trigger: undoCount)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            NavBack(backTitle) { model.path.removeLast() }
            NavTool {
                // 一点就把现在的账本图发到微信群，大家不用凑过来看
                Button("发到群") { ShareSheet.share(game) }
                    .accessibilityLabel("把账本发到群里")
            }
            NavTool {
                Menu {
                    if !game.isFinished {
                        Button("有人和错了") { pickingFalseWin = true }
                    }
                    Button("直接改分") { manualScoring = true }
                    Button("这场的规则") { editingRules = true }
                    Button("规则和番种说明") { showGuide = true }
                    Divider()
                    if !game.isFinished {
                        Button("结束牌局", role: .destructive) { confirmEnd = true }
                    }
                } label: {
                    Text("更多")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.gray)
                        .fixedSize()
                        .frame(minHeight: 44)
                }
            }
        }
        .confirmationDialog("谁和错了？", isPresented: $pickingFalseWin, titleVisibility: .visible) {
            ForEach(0..<4, id: \.self) { i in
                Button(game.players[i].name) { record { try $0.recordFalseWin(offender: i) } }
            }
        } message: {
            Text("推倒了却凑不成和牌：赔另外三家各 \(game.rules.falseWinPenalty) 分，这一局接着打。")
        }
        .sheet(item: $editing) { target in
            EditHandSheet(game: game, record: target.record, number: target.number) { outcome in
                edit { try $0.replace(target.record.id, with: outcome) }
            } onDelete: {
                edit { $0.remove(target.record.id) }
                HandPhotos.delete(target.record.id)
            }
        }
        .alert("结束这场牌局？", isPresented: $confirmEnd) {
            Button("结束", role: .destructive) { settle(game) }
            Button("再打会儿", role: .cancel) {}
        } message: {
            Text("结束后就不能再记了，会算出谁该给谁转多少。")
        }
        .fullScreenCover(isPresented: $recording) {
            RoundFlowView(game: game, demo: model.demoScreen) { outcome, photo in
                switch outcome {
                case .win(let win):
                    // 照片只留在这台手机上，跟着这一局的编号存
                    if let saved = record({ try $0.recordWin(win) }), let photo { HandPhotos.save(photo, for: saved.id) }
                case .falseWin(let offender): record { try $0.recordFalseWin(offender: offender) }
                default: break
                }
            }
        }
        .sheet(isPresented: $drawingHand) {
            DrawHandSheet(game: game) { tenpai, riichi in
                record { try $0.recordDraw(tenpai: tenpai, riichi: riichi) }
            }
        }
        .sheet(isPresented: $manualScoring) {
            ManualScoreView(game: game) { deltas, note in
                record { try $0.recordManual(deltas: deltas, note: note) }
            }
        }
        .sheet(isPresented: $showGuide) { RulesGuideView() }
        .sheet(isPresented: $editingRules) {
            GameRulesSheet(game: game, draft: demoRulesDraft(game)) { rules in
                edit { try $0.changeRules(rules) }
            }
        }
        .onAppear {
            if model.demoScreen == .table { justRecorded = game.records.last }
            if model.demoScreen == .draw { drawingHand = true }
            if model.demoScreen == .editHand, game.records.count > 1 {
                editing = EditTarget(record: game.records[1], number: 2)
            }
            if model.demoScreen?.opensRound == true { recording = true }
            if model.demoScreen == .gameRules { editingRules = true }
        }
        .alert("没有记上", isPresented: Binding(get: { recordError != nil }, set: { if !$0 { recordError = nil } })) {
            Button("好") { recordError = nil }
        } message: {
            Text(recordError ?? "")
        }
    }

    /// 截图用：打开「这场的规则」时预先把底分改成 5，好看到重算预览。
    private func demoRulesDraft(_ game: Game) -> GameRules? {
        guard model.demoScreen == .gameRules else { return nil }
        var rules = game.rules
        rules.basePoints = 5
        return rules
    }

    /// 记一条到这场牌局；失败时弹窗说明，不悄悄丢掉。
    @discardableResult
    private func record(_ change: (inout Game) throws -> HandRecord) -> HandRecord? {
        guard var updated = model.game(gameID) else { return nil }
        do {
            let record = try change(&updated)
            model.update(updated)
            showUndo(for: record)
            return record
        } catch let error as GameError {
            recordError = error.message
        } catch {
            recordError = error.localizedDescription
        }
        return nil
    }

    /// 点账本里的一局：和牌的推进「这一局」，别的弹出改局。进去之前收起「撤销」，免得回来撤掉的是改过的版本。
    private func open(_ record: HandRecord, number: Int) {
        guard record.isWin else {
            editing = EditTarget(record: record, number: number)
            return
        }
        undoTimer?.cancel()
        justRecorded = nil
        model.path.append(.hand(gameID, record.id))
    }

    private func showUndo(for record: HandRecord) {
        undoTimer?.cancel()
        withAnimation(.easeOut(duration: 0.2)) { justRecorded = record }
        undoTimer = Task {
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.2)) { justRecorded = nil }
        }
    }

    /// 改以前的一局。改了刚记的那局就收起「撤销」，免得撤销掉的是改过的版本。
    private func edit(_ change: (inout Game) throws -> Void) {
        guard var updated = model.game(gameID) else { return }
        do {
            try change(&updated)
            model.update(updated)
            if let record = justRecorded, updated.records.last?.id != record.id || updated.records.last != record {
                undoTimer?.cancel()
                withAnimation(.easeIn(duration: 0.2)) { justRecorded = nil }
            }
        } catch let error as GameError {
            recordError = error.message
        } catch {
            recordError = error.localizedDescription
        }
    }

    private func undo(_ record: HandRecord) {
        undoTimer?.cancel()
        guard var updated = model.game(gameID), updated.records.last?.id == record.id else { return }
        updated.undoLast()
        model.update(updated)
        undoCount += 1
        HandPhotos.delete(record.id)
        withAnimation(.easeIn(duration: 0.2)) { justRecorded = nil }
    }

    /// 结束牌局（打满 16 局时已经算结束），换到结算页；返回直接回首页。
    private func settle(_ game: Game) {
        var updated = game
        if updated.endedAt == nil { updated.end() }
        model.update(updated)
        model.path = [.settle(game.id)]
    }
}

private struct EditTarget: Identifiable {
    var record: HandRecord
    var number: Int
    var id: UUID { record.id }
}

/// 方桌：我（开局时填在第一行的人）在下面，下家在右，对家在上，上家在左。
/// 中央采用日本立直麻将电投桌风格深胜色中控盘，显示局顺（東三局）、本场数与立直供托棒（—•—）。
private struct TableDiagram: View {
    var game: Game
    var compact = false

    private func handKanji(_ hand: Int) -> String {
        ["一", "二", "三", "四"][hand % 4]
    }

    var body: some View {
        let hand = game.displayHand
        let seating = game.seating(ofRound: game.roundIndex(ofHand: hand))
        let me = game.position(of: game.me, inHand: hand)
        let at = { (offset: Int) in seating[(me + offset) % 4] }
        let wind = game.prevalentWind(ofHand: hand).name
        ZStack {
            VStack(spacing: compact ? 8 : 12) {
                Text(game.rules.totalHands == 4
                     ? tr("东风战", "東風戦", "EAST ONLY")
                     : tr("半庄战", "半荘戦", "HANCHAN"))
                    .font(.system(size: 11, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(Color.white.opacity(0.52))

                if game.isFinished {
                    Text(tr("终局", "終局", "Finished"))
                        .font(Theme.serif(compact ? 30 : 36))
                        .foregroundStyle(Theme.tileFace)
                } else {
                    Text(tr("\(wind)\(handKanji(hand))局",
                            "\(wind)\(handKanji(hand))局",
                            "\(wind) \(hand % 4 + 1)"))
                        .font(Theme.serif(compact ? 30 : 36))
                        .foregroundStyle(Theme.tileFace)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                HStack(spacing: 8) {
                    Text(tr("\(game.currentHonba)本场", "\(game.currentHonba)本場", "\(game.currentHonba) Honba"))
                        .font(.system(size: 12, weight: .medium).monospacedDigit())
                        .foregroundStyle(Color.white.opacity(0.88))
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 1, height: 10)
                    HStack(spacing: 4) {
                        RiichiStickIcon(width: 20, height: 5, borderColor: .clear)
                            .opacity(game.currentPot > 0 ? 1 : 0.6)
                        Text("×\(game.currentPot / 1000)")
                            .font(.system(size: 12, weight: game.currentPot > 0 ? .semibold : .regular).monospacedDigit())
                            .foregroundStyle(game.currentPot > 0 ? Color(hex: 0xFF8A80) : Color.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.09), in: Capsule())
            }
            .frame(width: compact ? 148 : 174, height: compact ? 148 : 174)
            .background {
                RoundedRectangle(cornerRadius: compact ? 24 : 28, style: .continuous)
                    .fill(Theme.ink)
                    .overlay(
                        RoundedRectangle(cornerRadius: compact ? 20 : 24, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.11), lineWidth: 1)
                            .padding(5)
                    )
                    .shadow(color: Theme.ink.opacity(0.16), radius: 14, y: 8)
            }

            SeatLabel(game: game, player: at(2), hand: hand, alignment: .center)
                .frame(maxHeight: .infinity, alignment: .top)
            SeatLabel(game: game, player: at(0), hand: hand, alignment: .center)
                .frame(maxHeight: .infinity, alignment: .bottom)
            SeatLabel(game: game, player: at(3), hand: hand, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            SeatLabel(game: game, player: at(1), hand: hand, alignment: .trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(height: compact ? 256 : 304)
    }
}

private struct SeatLabel: View {
    var game: Game
    var player: Int
    var hand: Int
    var alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            HStack(spacing: 6) {
                Text(game.seatWind(of: player, inHand: hand).name)
                    .font(Theme.serif(13))
                    .foregroundStyle(Theme.gray)
                Text(game.players[player].name)
                    .font(.system(size: 16, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if game.dealer(ofHand: hand) == player && !game.isFinished {
                    DealerStamp(size: 18)
                }
            }
            Text(Theme.signed(game.scores[player]))
                .font(Theme.score(26))
                .foregroundStyle(Theme.scoreColor(game.scores[player]))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        // 左右两边夹在桌子和屏幕边之间，只有 80 宽
        .frame(maxWidth: alignment == .center ? nil : 84,
               alignment: alignment == .leading ? .leading : alignment == .trailing ? .trailing : .center)
    }
}

/// 账本里的一局。
private struct RecordRow: View {
    var number: Int
    var record: HandRecord
    var game: Game

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("\(number)")
                    .font(.system(size: 14).monospacedDigit())
                    .foregroundStyle(Theme.gray)
                    .frame(width: 18, alignment: .leading)
                VStack(alignment: .leading, spacing: 3) {
                    Text(record.title(in: game)).font(.system(size: 16))
                    Text(record.detail(in: game))
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.gray)
                }
                Spacer(minLength: 8)
                if let value = record.headline {
                    Text(Theme.signed(value))
                        .font(.system(size: 17).monospacedDigit())
                        .foregroundStyle(Theme.scoreColor(value))
                } else {
                    Text("—").font(.system(size: 17)).foregroundStyle(Theme.gray)
                }
            }
            .padding(.vertical, 14)
            Hairline(color: Theme.lineSoft)
        }
        .accessibilityElement(children: .combine)
    }
}

/// 记下后底部的黑色提示条。
private struct UndoBar: View {
    var text: String
    var undo: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Text(text).font(.system(size: 14))
            Button(action: undo) {
                Text("撤销")
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(.white.opacity(0.14), in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.white)
        .padding(.leading, 18)
        .padding(.trailing, 4)
        .frame(height: 40)
        .background(Theme.ink, in: Capsule())
    }
}

/// 荒牌流局：点选哪几家听牌（可多选，0–4 人）与哪几家立直（每家投 1000 点留作供托），自动计算不听罚 3000 点与庄家连庄/流庄。
private struct DrawHandSheet: View {
    @Environment(\.dismiss) private var dismiss
    var game: Game
    var onSave: (Set<Int>, Set<Int>) -> Void

    @State private var tenpai: Set<Int>
    @State private var riichi: Set<Int>
    @State private var showRiichi = false

    init(game: Game, onSave: @escaping (Set<Int>, Set<Int>) -> Void) {
        self.game = game
        self.onSave = onSave
        _tenpai = State(initialValue: DemoScreen.current == .draw ? [0, 2] : [])
        _riichi = State(initialValue: [])
    }

    private var effectiveTenpai: Set<Int> { tenpai.union(riichi) }
    private var deltas: [Int] { Payment.drawDeltas(tenpai: effectiveTenpai, riichi: riichi) }
    private var dealer: Int { game.dealer }
    private var dealerTenpai: Bool { effectiveTenpai.contains(dealer) }

    private var summaryNote: String {
        let dealerName = game.players[dealer].name
        let nextHonba = game.currentHonba + 1
        let nextPot = game.currentPot + riichi.count * 1000
        let potNote = riichi.isEmpty ? "" : tr(
            "，桌面供托累计 \(nextPot) 点归下次和牌者",
            "（供託計\(nextPot)点は次の和了者へ）",
            " (Pot \(nextPot) pts goes to next winner)"
        )
        let dealerStatus = dealerTenpai
            ? tr("庄家（\(dealerName)）听牌连庄 · 下一局为 \(nextHonba) 本场\(potNote)",
                 "親（\(dealerName)）聴牌連荘・次局は\(nextHonba)本場\(potNote)",
                 "Dealer (\(dealerName)) tenpai repeats · Next is \(nextHonba) honba\(potNote)")
            : tr("庄家（\(dealerName)）未听牌流庄 · 下一局为 \(nextHonba) 本场\(potNote)",
                 "親（\(dealerName)）不聴流局・次局は\(nextHonba)本場\(potNote)",
                 "Dealer (\(dealerName)) noten rotates · Next is \(nextHonba) honba\(potNote)")
        switch effectiveTenpai.count {
        case 0:
            return tr("四家都没听牌，不交换听牌罚符。\(dealerStatus)。",
                      "全員不聴のため不聴罰符の授受なし。\(dealerStatus)。",
                      "All 4 players noten; no tenpai payments. \(dealerStatus).")
        case 4:
            return tr("四家都听牌，不交换听牌罚符。\(dealerStatus)。",
                      "全員聴牌のため不聴罰符の授受なし。\(dealerStatus)。",
                      "All 4 players tenpai; no tenpai payments. \(dealerStatus).")
        case 1:
            return tr("1 家听牌收 +3000 点，其余 3 家各付 −1000 点。\(dealerStatus)。",
                      "1人聴牌（+3000点）、不聴3人が各−1000点。\(dealerStatus)。",
                      "1 tenpai receives +3000 pts; 3 noten pay −1000 pts each. \(dealerStatus).")
        case 2:
            return tr("2 家听牌各收 +1500 点，不听 2 家各付 −1500 点。\(dealerStatus)。",
                      "2人聴牌（各+1500点）、不聴2人が各−1500点。\(dealerStatus)。",
                      "2 tenpai receive +1500 pts each; 2 noten pay −1500 pts each. \(dealerStatus).")
        default:
            return tr("3 家听牌各收 +1000 点，不听 1 家独付 −3000 点。\(dealerStatus)。",
                      "3人聴牌（各+1000点）、不聴1人が−3000点。\(dealerStatus)。",
                      "3 tenpai receive +1000 pts each; 1 noten pays −3000 pts. \(dealerStatus).")
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SectionLabel("哪几家听牌了（可多选）")
                        .padding(.top, 16)
                        .padding(.bottom, 10)
                    HStack(spacing: 8) {
                        ForEach(0..<4, id: \.self) { i in
                            let selected = effectiveTenpai.contains(i)
                            let dealerSuffix = i == dealer ? tr("·庄", "・親", "·D") : ""
                            NameChip(name: game.players[i].name + dealerSuffix, selected: selected) {
                                if selected {
                                    tenpai.remove(i)
                                    riichi.remove(i)
                                } else {
                                    tenpai.insert(i)
                                }
                            }
                        }
                    }

                    Text(summaryNote)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.gray)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 14)

                    if showRiichi || !riichi.isEmpty {
                        SectionLabel("这局有人立直吗（立直棒 1000 点留作供托）")
                            .padding(.top, 20)
                            .padding(.bottom, 10)
                        HStack(spacing: 8) {
                            ForEach(0..<4, id: \.self) { i in
                                let selected = riichi.contains(i)
                                NameChip(name: game.players[i].name, selected: selected) {
                                    if selected {
                                        riichi.remove(i)
                                    } else {
                                        riichi.insert(i)
                                        tenpai.insert(i)
                                    }
                                }
                            }
                        }
                    } else {
                        Button(tr("这局有人立直（留 1000 点供托棒）›",
                                  "リーチした人がいる（供託1000点）›",
                                  "Someone declared Riichi (+1000 pot) ›")) {
                            withAnimation(.easeOut(duration: 0.2)) { showRiichi = true }
                        }
                        .buttonStyle(.text(size: 14))
                        .padding(.top, 12)
                    }

                    if deltas != [0, 0, 0, 0] {
                        SectionLabel("本局点数变动")
                            .padding(.top, 22)
                            .padding(.bottom, 8)
                        DeltaGrid(game: game, deltas: deltas)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            .bottomBar {
                Button("记下流局") {
                    onSave(effectiveTenpai, riichi)
                    dismiss()
                }
                .buttonStyle(.primary)
            }
            .page()
            .navigationTitle("这局流局")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                NavClose { dismiss() }
            }
        }
        .presentationDetents([.height(460), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(30)
        .presentationBackground(Theme.paper)
    }
}
