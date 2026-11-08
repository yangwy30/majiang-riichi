import SwiftUI
import MajiangKit

/// 翻指示牌自动数宝牌。开杠多翻的直接往后加；赤五在这里标。算不准时核对页的加减号还能手动改。
struct DoraSheet: View {
    @Environment(\.dismiss) private var dismiss
    var flow: RoundFlow

    private enum Target: String, Identifiable {
        case dora, ura
        var id: String { rawValue }
    }

    @State private var picking: Target?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    row(tr("宝牌指示牌（开杠多翻的也加在这里）", "ドラ表示牌（カンドラも）", "Dora indicators (incl. kan dora)"),
                        tiles: flow.doraIndicators, target: .dora) { flow.doraIndicators.remove(at: $0) }
                    if flow.context.riichi || flow.context.doubleRiichi {
                        row(tr("里宝牌指示牌", "裏ドラ表示牌", "Ura-dora indicators"),
                            tiles: flow.uraIndicators, target: .ura) { flow.uraIndicators.remove(at: $0) }
                    }
                    if !flow.redFiveSuits.isEmpty {
                        SectionLabel(tr("赤五", "赤ドラ", "Red fives"))
                            .padding(.top, 24)
                            .padding(.bottom, 10)
                        HStack(spacing: 8) {
                            ForEach(flow.redFiveSuits, id: \.self) { suit in
                                let tile = Tile(suit: suit, rank: 5, isRed: true)!
                                NameChip(name: tile.displayName, selected: flow.hasRedFive(suit)) {
                                    flow.setRedFive(suit, on: !flow.hasRedFive(suit))
                                }
                            }
                        }
                    }
                    Text(tr("这手牌现在 \(flow.doraTotal) 张宝牌", "現在ドラ\(flow.doraTotal)枚", "\(flow.doraTotal) dora in this hand"))
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.gray)
                        .padding(.top, 24)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            .page()
            .navigationTitle(tr("数宝牌", "ドラを数える", "Count Dora"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { NavClose { dismiss() } }
            .sheet(item: $picking) { target in
                TileEditSheet(title: tr("翻出来的指示牌", "表示牌", "Indicator"), current: nil) { tile in
                    switch target {
                    case .dora: flow.doraIndicators.append(tile)
                    case .ura: flow.uraIndicators.append(tile)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(_ title: String, tiles: [Tile], target: Target, remove: @escaping (Int) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title)
            HStack(spacing: 8) {
                ForEach(Array(tiles.enumerated()), id: \.offset) { index, tile in
                    Button { remove(index) } label: { TileFace(tile: tile, width: 34) }
                        .buttonStyle(.plain)
                        .accessibilityLabel(tr("删掉 \(tile.displayName)", "\(tile.displayName)を削除", "Remove \(tile.displayName)"))
                }
                // 表宝牌最多 5 张：1 张加上四次开杠。
                if tiles.count < 5 {
                    Button(tr("加一张", "追加", "Add")) { picking = target }
                        .buttonStyle(.text(size: 14))
                }
            }
        }
        .padding(.top, 16)
    }
}
