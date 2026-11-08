import SwiftUI
import MajiangKit

/// 翻指示牌自动数宝牌：一小页绿毡，翻出来的指示牌摆在上面（开杠多翻的往后加），立直和了再摆里宝牌；
/// 赤五在这里标。算不准时核对页的加减号还能手动改。
struct DoraSheet: View {
    @Environment(\.dismiss) private var dismiss
    var flow: RoundFlow

    private enum Target: String, Identifiable {
        case dora, ura
        var id: String { rawValue }
    }

    @State private var picking: Target?

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .firstTextBaseline) {
                Text(tr("数宝牌", "ドラを数える", "Count dora"))
                    .font(.system(size: 20, weight: .bold))
                Spacer()
                Text(tr("宝牌 \(flow.doraTotal)", "ドラ \(flow.doraTotal)", "Dora \(flow.doraTotal)"))
                    .font(Theme.score(20))
                    .contentTransition(.numericText(value: Double(flow.doraTotal)))
                    .animation(.snappy, value: flow.doraTotal)
            }
            row(tr("宝牌指示牌 · 开杠多翻的往后加", "ドラ表示牌・カンドラも", "Dora indicators · incl. kan dora"),
                tiles: flow.doraIndicators, target: .dora) { flow.doraIndicators.remove(at: $0) }
            if flow.context.riichi || flow.context.doubleRiichi {
                row(tr("里宝牌指示牌 · 立直和了才翻", "裏ドラ表示牌・リーチ和了のみ", "Ura-dora indicators · riichi wins only"),
                    tiles: flow.uraIndicators, target: .ura) { flow.uraIndicators.remove(at: $0) }
            }
            if !flow.redFiveSuits.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    label(tr("手里的赤五", "手牌の赤ドラ", "Red fives in the hand"))
                    HStack(spacing: 8) {
                        ForEach(flow.redFiveSuits, id: \.self) { suit in
                            let tile = Tile(suit: suit, rank: 5, isRed: true)!
                            let on = flow.hasRedFive(suit)
                            Button {
                                flow.setRedFive(suit, on: !on)
                            } label: {
                                HStack(spacing: 6) {
                                    TileFace(tile: tile, width: 18)
                                    Text(tile.displayName).font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundStyle(on ? Theme.tileInk : .white)
                                .padding(.leading, 5)
                                .padding(.trailing, 12)
                                .frame(height: 34)
                                .background(on ? Color.white : Color.white.opacity(0.14), in: Capsule())
                                .contentShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            Button { dismiss() } label: {
                Text(tr("好", "OK", "Done"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.tileInk)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(.white, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(PressFade())
        }
        .padding(24)
        .foregroundStyle(.white)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground { FeltTexture() }
        .sheet(item: $picking) { target in
            TileEditSheet(title: tr("翻出来的指示牌", "表示牌", "Indicator"), current: nil) { tile in
                switch target {
                case .dora: flow.doraIndicators.append(tile)
                case .ura: flow.uraIndicators.append(tile)
                }
            }
        }
    }

    private func label(_ text: String) -> some View {
        Text(text).font(.system(size: 13)).foregroundStyle(.white.opacity(0.75))
    }

    /// 一排指示牌：点一张拿掉，后面一个虚线空位加一张（表宝牌最多 5 张：1 张加上四次开杠）。
    private func row(_ title: String, tiles: [Tile], target: Target, remove: @escaping (Int) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            label(title)
            HStack(spacing: 8) {
                ForEach(Array(tiles.enumerated()), id: \.offset) { index, tile in
                    Button { remove(index) } label: {
                        TileFace(tile: tile, width: 34).shadow(color: .black.opacity(0.3), radius: 3, y: 2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tr("拿掉 \(tile.displayName)", "\(tile.displayName)を外す", "Remove \(tile.displayName)"))
                }
                if tiles.count < 5 {
                    Button { picking = target } label: {
                        RoundedRectangle(cornerRadius: 34 * 0.16, style: .continuous)
                            .strokeBorder(.white.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            .frame(width: 34, height: 45)
                            .overlay(Image(systemName: "plus").font(.system(size: 15)).foregroundStyle(.white.opacity(0.85)))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tr("加一张指示牌", "表示牌を追加", "Add an indicator"))
                }
            }
        }
    }
}
