import SwiftUI
import MajiangKit

/// 不常见的流局：途中流局和流局满贯。平常的荒牌流局走「这局没人和」。
struct SpecialDrawSheet: View {
    @Environment(\.dismiss) private var dismiss
    var game: Game
    var onAbortive: (AbortiveDraw, Set<Int>) -> Void
    var onNagashi: (Set<Int>, Set<Int>, Set<Int>) -> Void

    private enum Mode: Hashable { case abortive, nagashi }

    @State private var mode = Mode.abortive
    @State private var kind = AbortiveDraw.kyuushuKyuuhai
    @State private var nagashi: Set<Int> = []
    @State private var tenpai: Set<Int> = []
    @State private var riichi: Set<Int> = []

    private var note: String {
        mode == .abortive
            ? tr("不收付，庄家连庄，下一局加 1 本场，立直棒留在桌上。",
                 "収支なし・親連荘・1本場追加。リーチ棒は場に残ります。",
                 "No payment. Dealer repeats, +1 honba. Riichi sticks stay on the table.")
            : tr("按满贯自摸收点，不再收听牌罚符，加 1 本场。",
                 "満貫ツモの収支で不聴罰符なし。1本場追加。",
                 "Paid as a mangan tsumo, with no tenpai payments. +1 honba.")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SegmentedSwitch(options: [(Mode.abortive, tr("途中流局", "途中流局", "Abortive")),
                                              (Mode.nagashi, tr("流局满贯", "流し満貫", "Nagashi Mangan"))],
                                    selection: $mode)
                        .padding(.top, 16)
                    if mode == .abortive {
                        SectionLabel(tr("什么情况", "種類", "Reason")).padding(.top, 20).padding(.bottom, 10)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(AbortiveDraw.allCases, id: \.self) { item in
                                NameChip(name: item.name, selected: kind == item) { kind = item }
                            }
                        }
                    } else {
                        players(tr("谁流局满贯", "流し満貫の人", "Who made it"), $nagashi)
                        players(tr("谁听牌（决定庄家连不连庄）", "聴牌した人（連荘の判定）", "Who was tenpai (decides dealer repeat)"), $tenpai)
                    }
                    if !(mode == .abortive && kind == .suuchaRiichi) {
                        players(tr("这局谁立直了", "リーチした人", "Who declared Riichi"), $riichi)
                    }
                    Text(note)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.gray)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 16)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            .bottomBar {
                Button(tr("记下", "記録", "Save")) {
                    if mode == .abortive {
                        onAbortive(kind, riichi)
                    } else {
                        onNagashi(nagashi, tenpai, riichi)
                    }
                    dismiss()
                }
                .buttonStyle(.primary)
                .disabled(mode == .nagashi && nagashi.isEmpty)
            }
            .page()
            .navigationTitle(tr("特殊流局", "特殊な流局", "Special Draw"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { NavClose { dismiss() } }
        }
        .presentationDetents([.large])
    }

    private func players(_ title: String, _ selection: Binding<Set<Int>>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title)
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { i in
                    let selected = selection.wrappedValue.contains(i)
                    NameChip(name: game.players[i].name, selected: selected) {
                        if selected { selection.wrappedValue.remove(i) } else { selection.wrappedValue.insert(i) }
                    }
                }
            }
        }
        .padding(.top, 20)
    }
}
