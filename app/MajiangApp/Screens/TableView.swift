import SwiftUI
import MajiangKit

/// 牌桌，也是账本：上面是罗盘和记一局的大卡片，往下滚是每一局的记录。
/// 没打完的牌局是第一个 tab 的内容（`isRoot`）；打完的从结算页点进来，左上有返回。
struct TableView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    let gameID: UUID
    var isRoot = false

    @State private var recording = false
    @State private var drawingHand = false
    @State private var specialDraw = false
    @State private var secondRon = false
    @State private var manualScoring = false
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

    private func content(_ game: Game) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header(game)
                // 桌规跟标准不一样时才露一行，点开能改
                if let badge = game.rules.houseRuleBadge {
                    Button { editingRules = true } label: {
                        Text(badge + " ›")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.gray)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(minHeight: 30, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                // 矮屏（iPhone Duo 外屏、SE、mini）牌桌小一圈，账本多露出一行
                TableBoard(game: game, compact: pageHeight > 0 && pageHeight < 640)
                    .padding(.top, 16)
                actions(game)
                    .padding(.top, 24)

                ledger(game)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .safeAreaInset(edge: .bottom) {
            if let record = justRecorded {
                UndoBar(text: tr("已记下第 \(game.records.count) 局", "第\(game.records.count)局を記録しました", "Recorded hand #\(game.records.count)")) { undo(record) }
                    .padding(.bottom, 10)
                    .frame(maxWidth: .infinity)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        // 量到的是整页，不随撤销条出没变
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { pageHeight = $0 }
        .page()
        // 记下一局轻轻「成功」一下；撤销轻震一下
        .sensoryFeedback(.success, trigger: justRecorded?.id) { _, new in new != nil }
        .sensoryFeedback(.impact(weight: .light), trigger: undoCount)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
        .confirmationDialog("谁和错了？", isPresented: $pickingFalseWin, titleVisibility: .visible) {
            ForEach(0..<4, id: \.self) { i in
                Button(game.players[i].name) { record { try $0.recordFalseWin(offender: i) } }
            }
        } message: {
            Text(game.chomboLine())
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
            RoundFlowView(game: game, demo: model.demoScreen, colorScheme: colorScheme) { outcome, photo in
                switch outcome {
                case .win(let win):
                    // 照片只留在这台手机上，跟着这一局的编号存
                    if let saved = record({ try $0.recordWin(win) }), let photo { HandPhotos.save(photo, for: saved.id) }
                case .falseWin(let offender): record { try $0.recordFalseWin(offender: offender) }
                default: break
                }
            }
        }
        .fullScreenCover(isPresented: $secondRon) {
            if case .win(let last)? = game.records.last?.outcome {
                RoundFlowView(game: game.beforeLastRecord, presetDiscarder: last.discarder, colorScheme: colorScheme) { outcome, _ in
                    if case .win(let win) = outcome { edit { try $0.addSecondRon(win) } }
                }
            }
        }
        .modifier(TableSheets(game: game, specialDraw: $specialDraw, drawingHand: $drawingHand, manualScoring: $manualScoring, editingRules: $editingRules, rulesDraft: demoRulesDraft(game), record: { change in record(change) }, edit: { change in edit(change) }))
        .onAppear {
            if model.demoScreen == .table { justRecorded = game.records.last }
            if model.demoScreen == .draw { drawingHand = true }
            if model.demoScreen == .specialDraw { specialDraw = true }
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

    /// 账本：每一局一行，最新的在上面。
    @ViewBuilder
    private func ledger(_ game: Game) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("账本").font(.system(size: 13, weight: .medium))
            Spacer()
            Text(tr("打了 \(game.playedHandsCount) 局", "\(game.playedHandsCount)局消化", "\(game.playedHandsCount) played"))
                .font(.system(size: 13))
        }
        .foregroundStyle(Theme.gray)
        .padding(.top, 24)
        .padding(.bottom, 6)
        Hairline()

        if game.records.isEmpty {
            Text(game.isFinished
                 ? tr("这场没有记录。", "記録はありません。", "No hands recorded.")
                 : tr("还没有记录。有人和了就点上面的按钮。", "まだ記録がありません。和了が出たら上のボタンをタップ。", "No hands yet. Tap the button above when someone wins."))
                .font(.system(size: 14))
                .foregroundStyle(Theme.gray)
                .padding(.vertical, 14)
        }
        ForEach(Array(game.records.enumerated().reversed()), id: \.element.id) { index, record in
            // 和牌的局点进去看怎么和的（在里面也能改）；别的局直接改或删。打完的牌局也一样
            Button {
                open(record, number: index + 1)
            } label: {
                RecordRow(record: record, game: game)
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

    /// 顶上：左边大字局顺和一行进度（打完的牌局是日期，多一个返回），右边发到群和更多。
    private func header(_ game: Game) -> some View {
        HStack(alignment: .top, spacing: 4) {
            if !isRoot {
                Button { model.path.removeLast() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 34, height: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tr("返回", "戻る", "Back"))
            }
            VStack(alignment: .leading, spacing: 2) {
                let title = isRoot ? game.handLabelShort : game.startedAt.dayLabel
                Text(title)
                    .font(Theme.heading(title, size: 32))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(game.progressLine)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.gray)
            }
            Spacer(minLength: 8)
            // 一点就把现在的账本图发到微信群，大家不用凑过来看
            Button { ShareSheet.share(game) } label: { headerIcon("square.and.arrow.up") }
                .buttonStyle(.plain)
                .accessibilityLabel("把账本发到群里")
            Menu {
                if !game.isFinished {
                    Button("有人和错了") { pickingFalseWin = true }
                    Button(tr("特殊流局", "特殊な流局", "Special Draw")) { specialDraw = true }
                }
                if case .win(let last)? = game.records.last?.outcome, last.discarder != nil {
                    Button(tr("还有一家也和了（双响）", "もう一人もロン（ダブロン）", "Another Ron (Double Ron)")) { secondRon = true }
                }
                Button("直接改分") { manualScoring = true }
                Button("这场的规则") { editingRules = true }
                Divider()
                if !game.isFinished {
                    Button("结束牌局", role: .destructive) { confirmEnd = true }
                }
            } label: {
                headerIcon("ellipsis.circle")
            }
            .accessibilityLabel(tr("更多", "その他", "More"))
            .accessibilityIdentifier("table-menu")
        }
    }

    private func headerIcon(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 18))
            .foregroundStyle(Theme.ink)
            .frame(width: 40, height: 44)
            .contentShape(Rectangle())
    }

    /// 主操作：有人和了（拍照），旁边一个玻璃的流局。打完了换成看结算。
    @ViewBuilder
    private func actions(_ game: Game) -> some View {
        if game.isFinished {
            VStack(spacing: 10) {
                Text(finishReason(game))
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("看结算") { settle(game) }
                    .buttonStyle(.primary)
            }
        } else {
            TableActions(symbol: "camera", title: tr("有人和了", "和了を記録", "Someone won"),
                         secondary: tr("流局", "流局", "Draw")) {
                recording = true
            } secondaryAction: {
                drawingHand = true
            }
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
        let wasFinished = updated.isFinished
        do {
            let record = try change(&updated)
            model.update(updated)
            // 这一局让牌局结束了（打满或击飞）：牌桌先留着，不要一下子变回空桌
            if updated.isFinished && !wasFinished { model.justFinishedGameID = updated.id }
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

    /// 牌局为什么结束了：有人点数跌破 0（击飞）、打满了，或者手动结束。
    private func finishReason(_ game: Game) -> String {
        if game.isBusted, let busted = (0..<4).first(where: { game.currentPoints[$0] < 0 }) {
            return tr("\(game.players[busted].name)的点数跌破 0（击飞），这场打完了。",
                      "\(game.players[busted].name)が0点未満（トビ）、対局終了です。",
                      "\(game.players[busted].name) dropped below 0 (bust). The game is over.")
        }
        if game.remainingHands == 0 {
            return tr("局数打满了，这场打完了。", "全局終了しました。", "All hands played. The game is over.")
        }
        return tr("这场打完了。", "対局終了です。", "The game is over.")
    }

    /// 结束牌局（打满 16 局时已经算结束），换到结算页；返回直接回首页。
    private func settle(_ game: Game) {
        var updated = game
        if updated.endedAt == nil { updated.end() }
        model.update(updated)
        model.justFinishedGameID = nil
        model.path = [.settle(game.id)]
    }
}

private struct EditTarget: Identifiable {
    var record: HandRecord
    var number: Int
    var id: UUID { record.id }
}

/// 账本里的一局：左边局顺（东 1），右边这局赢了多少。
private struct RecordRow: View {
    var record: HandRecord
    var game: Game

    private var handMark: String {
        let wind = game.prevalentWind(ofHand: record.handIndex).name
        let kyoku = record.handIndex % 4 + 1
        return "\(Theme.windGlyph(wind))\(kyoku)"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(handMark)
                    .font(Theme.glyph(14, semibold: true))
                    .foregroundStyle(Theme.gray)
                    .frame(width: 28, alignment: .leading)
                VStack(alignment: .leading, spacing: 3) {
                    Text(record.title(in: game)).font(.system(size: 15))
                    Text(record.detail(in: game))
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.gray)
                }
                Spacer(minLength: 8)
                if let value = record.headline {
                    Text(Theme.signed(value))
                        .font(Theme.score(17))
                        .foregroundStyle(Theme.scoreColor(value))
                } else {
                    Text("—").font(.system(size: 17)).foregroundStyle(Theme.gray)
                }
            }
            .padding(.vertical, 13)
            Hairline(color: Theme.lineSoft)
        }
        .accessibilityElement(children: .combine)
    }
}

/// 记下后底部的提示条。
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
                    .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.white)
        .padding(.leading, 16)
        .padding(.trailing, 4)
        .frame(height: 40)
        .background(Theme.fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                        DeltaGrid(game: game, deltas: deltas, hand: game.displayHand)
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
        .presentationCornerRadius(16)
        .presentationBackground(Theme.paper)
    }
}

/// 牌桌上弹出来的几页：特殊流局、流局、直接改分、这场的规则。单独放一处，免得牌桌的 body 太长编译器算不过来。
private struct TableSheets: ViewModifier {
    var game: Game
    @Binding var specialDraw: Bool
    @Binding var drawingHand: Bool
    @Binding var manualScoring: Bool
    @Binding var editingRules: Bool
    var rulesDraft: GameRules?
    var record: ((inout Game) throws -> HandRecord) -> Void
    var edit: ((inout Game) throws -> Void) -> Void

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $specialDraw) {
                SpecialDrawSheet(game: game) { kind, riichi in
                    record { try $0.recordAbortiveDraw(kind, riichi: riichi) }
                } onNagashi: { players, tenpai, riichi in
                    record { try $0.recordNagashi(players: players, tenpai: tenpai, riichi: riichi) }
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
            .sheet(isPresented: $editingRules) {
                GameRulesSheet(game: game, draft: rulesDraft) { rules in
                    edit { try $0.changeRules(rules) }
                }
            }
    }
}
