import SwiftUI
import MajiangKit

/// 改账本里的某一局：和了 / 没人和 / 和错了之间换，改谁和、谁点炮、几番，或者整局删掉。
/// 改完以后这一局之后的局数、风位和分数由 `Game.replace` 重算，这里只预览。
struct EditHandSheet: View {
    @Environment(\.dismiss) private var dismiss
    var game: Game
    var record: HandRecord
    /// 账本里这一行的编号。
    var number: Int
    var onSave: (HandOutcome) -> Void
    var onDelete: () -> Void

    private enum Kind: Hashable { case win, drawn, falseWin, manual }

    @State private var kind: Kind
    @State private var winner: Int
    @State private var selfDrawn: Bool
    @State private var discarder: Int?
    /// 手动改的番数（含花）；nil 表示按牌算或者沿用原来的番数。
    @State private var fanEdit: Int?
    @State private var tenpai: Set<Int>
    @State private var riichi: Set<Int>
    @State private var showRiichi = false
    @State private var offender: Int
    @State private var confirmDelete = false

    init(game: Game, record: HandRecord, number: Int,
         onSave: @escaping (HandOutcome) -> Void, onDelete: @escaping () -> Void) {
        self.game = game
        self.record = record
        self.number = number
        self.onSave = onSave
        self.onDelete = onDelete
        switch record.outcome {
        case .win(let win):
            _kind = State(initialValue: .win)
            _winner = State(initialValue: win.winner)
            _selfDrawn = State(initialValue: win.isSelfDrawn)
            _discarder = State(initialValue: win.discarder)
            _tenpai = State(initialValue: [])
            _riichi = State(initialValue: [])
            _offender = State(initialValue: win.winner)
        case .falseWin(let offender):
            _kind = State(initialValue: .falseWin)
            _winner = State(initialValue: offender)
            _selfDrawn = State(initialValue: true)
            _tenpai = State(initialValue: [])
            _riichi = State(initialValue: [])
            _offender = State(initialValue: offender)
        case .drawn(let tenpai, let riichi):
            _kind = State(initialValue: .drawn)
            _winner = State(initialValue: 0)
            _selfDrawn = State(initialValue: true)
            _tenpai = State(initialValue: tenpai.union(riichi))
            _riichi = State(initialValue: riichi)
            _offender = State(initialValue: 0)
        case .manual, .doubleRon, .nagashi, .abortive:
            _kind = State(initialValue: .manual)
            _winner = State(initialValue: 0)
            _selfDrawn = State(initialValue: true)
            _tenpai = State(initialValue: [])
            _riichi = State(initialValue: [])
            _offender = State(initialValue: 0)
        }
    }

    private var originalWin: WinRecord? {
        if case .win(let win) = record.outcome { return win }
        return nil
    }

    private var kinds: [(Kind, String)] {
        var options: [(Kind, String)] = [(.win, "和了"), (.drawn, "没人和"), (.falseWin, "和错了")]
        switch record.outcome {
        case .manual: options.append((.manual, "直接改分"))
        case .doubleRon, .nagashi, .abortive: options.append((.manual, tr("保持原样", "そのまま", "Keep as is")))
        default: break
        }
        return options
    }

    /// 改完以后的这一局；还缺信息（点炮没选人）时为 nil。
    private var outcome: HandOutcome? {
        switch kind {
        case .win:
            if !selfDrawn && discarder == nil { return nil }
            // 原来不是和牌的话没有牌，只能直接给番数，先按起和番算
            var win = originalWin ?? WinRecord(winner: winner, discarder: nil, hand: nil, context: WinContext(),
                                               fans: [], doraFan: 0, fanOverride: game.rules.minimumFan)
            win.winner = winner
            win.discarder = selfDrawn ? nil : discarder
            if let fanEdit {
                win.fanOverride = fanEdit
                win.fans = []
            }
            return .win(win)
        case .drawn:
            return .drawn(tenpai: tenpai.union(riichi), riichi: riichi)
        case .falseWin:
            return .falseWin(offender: offender)
        case .manual:
            return record.outcome
        }
    }

    private var preview: Result<Game, GameError>? {
        guard let outcome else { return nil }
        do {
            return .success(try game.replacing(record.id, with: outcome))
        } catch let error as GameError {
            return .failure(error)
        } catch {
            return .failure(.recordNotFound)
        }
    }

    private var previewRecord: HandRecord? {
        guard case .success(let edited) = preview else { return nil }
        return edited.records.first { $0.id == record.id }
    }

    /// 番数格子里显示的数：手动改过的、按改完的样子算出来的，都没有就用原来的。
    private var shownFan: Int {
        if let fanEdit { return fanEdit }
        if case .win(let win)? = previewRecord?.outcome { return win.totalFan }
        // 按牌重算以后不够起和：错误里带着不含花的番数
        if case .failure(.belowMinimumFan(let fan))? = preview { return fan + doraFan }
        return originalWin?.totalFan ?? game.rules.minimumFan
    }

    private var doraFan: Int { originalWin?.doraFan ?? 0 }
    private var minimumFan: Int { game.rules.minimumFan + doraFan }

    private var blockedReason: String? {
        if kind == .win && !selfDrawn && discarder == nil {
            return tr("选一下谁点的炮", "放銃した人を選んでください", "Select who dealt in")
        }
        if case .failure(let error) = preview { return error.message }
        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SegmentedSwitch(options: kinds, selection: $kind)

                    switch kind {
                    case .win: winSection
                    case .drawn: drawnSection
                    case .falseWin: falseWinSection
                    case .manual: note(tr("这一局不能在这里改。要重填就删掉，再记一次。", "この局はここでは変更できません。削除して記録し直してください。", "This hand can't be edited here. Delete it and record it again."))
                    }

                    if let previewRecord, previewRecord.deltas != [0, 0, 0, 0] {
                        SectionLabel("这一局")
                            .padding(.top, 28)
                            .padding(.bottom, 10)
                        deltaGrid(previewRecord.deltas)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .bottomBar {
                Button(blockedReason ?? tr("保存", "保存", "Save")) {
                    if let outcome { onSave(outcome) }
                    dismiss()
                }
                .buttonStyle(.primary)
                .disabled(blockedReason != nil)
                Button("删掉这一局") { confirmDelete = true }
                    .buttonStyle(.text)
            }
            .page()
            .navigationTitle("改第 \(number) 局")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                NavClose { dismiss() }
            }
            .confirmationDialog("删掉第 \(number) 局？", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("删掉", role: .destructive) {
                    onDelete()
                    dismiss()
                }
            } message: {
                Text("这一局的分数全部退回，后面的局往前挪。")
            }
            .onChange(of: winner) { _, new in
                if discarder == new { discarder = nil }
            }
        }
    }

    // MARK: 和了

    @ViewBuilder
    private var winSection: some View {
        SectionLabel("谁和了")
            .padding(.top, 28)
            .padding(.bottom, 10)
        chips(selected: winner) { winner = $0 }

        SectionLabel("怎么和的")
            .padding(.top, 28)
            .padding(.bottom, 10)
        SegmentedSwitch(options: [(true, tr("自摸", "ツモ", "Tsumo")), (false, tr("荣和", "ロン", "Ron"))], selection: $selfDrawn)
        if !selfDrawn {
            Text("是谁打的？")
                .font(.system(size: 14))
                .foregroundStyle(Theme.gray)
                .padding(.top, 10)
            HStack(spacing: 8) {
                ForEach((0..<4).filter { $0 != winner }, id: \.self) { i in
                    NameChip(name: game.players[i].name, selected: discarder == i) { discarder = i }
                }
            }
            .padding(.top, 10)
        }

        fanRow
            .block()
            .padding(.top, 22)
        Text(fanNote)
            .font(.system(size: 14))
            .foregroundStyle(Theme.gray)
            .padding(.top, 10)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var fanRow: some View {
        HStack {
            Text("翻数").font(.system(size: 16))
            Spacer()
            HStack(spacing: 14) {
                stepButton("minus", label: "少一翻") { fanEdit = max(minimumFan, shownFan - 1) }
                    .disabled(shownFan <= minimumFan)
                Text("\(shownFan)")
                    .font(.system(size: 17).monospacedDigit())
                    .frame(minWidth: 28)
                stepButton("plus", label: "多一翻") { fanEdit = shownFan + 1 }
            }
        }
        .frame(minHeight: 60)
    }

    private var fanNote: String {
        let flowers = doraFan > 0 ? tr("含宝牌 \(doraFan) 翻。", "ドラ \(doraFan) 翻を含む。", "Includes \(doraFan) Dora.") : ""
        if fanEdit != nil || originalWin?.fanOverride != nil || originalWin == nil {
            return flowers + tr("翻数是手填的，账本里不再列役种。", "翻数は手入力のため、役一覧は表示されません。", "Han entered manually; yaku breakdown hidden.")
        }
        if originalWin?.hand != nil {
            return flowers + tr("按拍下的牌自动算，换了谁和、自摸还是荣和会重算。要直接改就点加减。",
                                "牌姿から自動計算されます。直接変更するには＋/－を押してください。",
                                "Auto-calculated from tiles. Tap +/- to override.")
        }
        return flowers + tr("要改翻数就点加减。", "翻数を変更するには＋/－を押してください。", "Tap +/- to adjust han.")
    }

    // MARK: 流局

    @ViewBuilder
    private var drawnSection: some View {
        SectionLabel("哪几家听牌了（可多选）")
            .padding(.top, 28)
            .padding(.bottom, 10)
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { i in
                let selected = tenpai.contains(i)
                NameChip(name: game.players[i].name, selected: selected) {
                    if selected {
                        tenpai.remove(i)
                        riichi.remove(i)
                    } else {
                        tenpai.insert(i)
                    }
                }
            }
        }
        note(tenpai.isEmpty || tenpai.count == 4
             ? "全员不听或全员听牌不交换听牌罚符；庄家听牌则连庄，下一局加 1 本场。"
             : "不听牌的家合计付 3000 点给听牌的家；庄家听牌则连庄，下一局加 1 本场。")
        if showRiichi || !riichi.isEmpty {
            SectionLabel("这局有人立直吗（立直棒 1000 点留作供托）")
                .padding(.top, 22)
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
    }

    // MARK: 和错了

    @ViewBuilder
    private var falseWinSection: some View {
        SectionLabel("谁和错了")
            .padding(.top, 28)
            .padding(.bottom, 10)
        chips(selected: offender) { offender = $0 }
        note(game.chomboLine())
    }

    // MARK: 小部件

    private func chips(selected: Int, pick: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { i in
                NameChip(name: game.players[i].name, selected: selected == i) { pick(i) }
            }
        }
    }

    private func note(_ text: String) -> some View {
        Text(LocalizedStringKey(text))
            .font(.system(size: 14))
            .foregroundStyle(Theme.gray)
            .padding(.top, 16)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func deltaGrid(_ deltas: [Int]) -> some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(0..<4, id: \.self) { i in
                VStack(alignment: .leading, spacing: 4) {
                    Text(game.players[i].name)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.gray)
                        .lineLimit(1)
                    Text(Theme.signed(deltas[i]))
                        .font(Theme.score(22))
                        .foregroundStyle(Theme.scoreColor(deltas[i]))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 18)
        .block()
    }

    private func stepButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 32, height: 32)
                .overlay(Circle().strokeBorder(Theme.line))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
