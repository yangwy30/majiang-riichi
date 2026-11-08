import SwiftUI
import MajiangKit

/// 每个役一行：名字、一句白话、几翻。结果页和「这一局」共用。
struct FanList: View {
    var win: WinRecord

    var body: some View {
        VStack(spacing: 0) {
            ForEach(win.fans, id: \.fan) { entry in
                FanRow(name: entry.count > 1 ? "\(entry.fan.name) ×\(entry.count)" : entry.fan.name,
                       plain: entry.fan.explanation, points: entry.points)
            }
            if win.doraFan > 0 {
                FanRow(name: tr("宝牌 ×\(win.doraFan)", "ドラ ×\(win.doraFan)", "Dora ×\(win.doraFan)"),
                       plain: tr("表宝牌、赤宝牌、里宝牌每张 1 翻，不算进起和役",
                                 "表ドラ・赤ドラ・裏ドラは1枚1翻（役にはなりません）",
                                 "Dora, red 5s, and ura-dora add 1 han each (not a yaku)"),
                       points: win.doraFan)
            }
        }
    }
}

private struct FanRow: View {
    var name: String
    var plain: String
    var points: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: 16, weight: .medium))
                Text(plain)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Text("\(points)").font(Theme.score(16, weight: .regular)).foregroundStyle(Theme.gray)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { Hairline(color: Theme.line) }
        .accessibilityElement(children: .combine)
    }
}

/// 「这局谁付多少」：四个人一排，按那一局的东南西北排，每人上面一张风牌（庄家描红边）。
struct DeltaGrid: View {
    var game: Game
    var deltas: [Int]
    /// 第几局（定风位和庄家）。
    var hand: Int

    private var seatOrder: [Int] {
        (0..<4).sorted { game.seatWind(of: $0, inHand: hand).rawValue < game.seatWind(of: $1, inHand: hand).rawValue }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(seatOrder, id: \.self) { i in
                VStack(spacing: 6) {
                    WindTile(text: Theme.tileGlyph(game.seatWind(of: i, inHand: hand)),
                             isDealer: game.dealer(ofHand: hand) == i, width: 22)
                    Text(game.players[i].name).font(.system(size: 12)).foregroundStyle(Theme.gray).lineLimit(1)
                    Text(Theme.signed(deltas[i]))
                        .font(Theme.score(16))
                        .foregroundStyle(Theme.scoreColor(deltas[i]))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.vertical, 6)
    }
}

/// 一手牌排成一行，跟桌上摆的一样：吃碰杠各一组，立牌一组，和的那张单独放在最右，下面一个朱红「和」。
/// 牌的大小按屏幕宽度算，十四张（有杠时十七八张）都放得下一行。
struct HandTiles: View {
    var hand: Hand
    @State private var available: CGFloat = 345

    private struct TileGroup: Identifiable {
        var id: Int
        var tiles: [Tile]
        var mark: String?
        var isWinning = false
    }

    private var groups: [TileGroup] {
        var result = hand.melds.enumerated().map { i, meld in
            TileGroup(id: i, tiles: meld.tiles, mark: meld.kindName)
        }
        var standing = hand.concealed
        if let i = standing.lastIndex(of: hand.winningTile) { standing.remove(at: i) }
        if !standing.isEmpty { result.append(TileGroup(id: 100, tiles: standing)) }
        result.append(TileGroup(id: 200, tiles: [hand.winningTile], mark: tr("和", "和", "Win"), isWinning: true))
        return result
    }

    private static let tileGap: CGFloat = 2
    private static let groupGap: CGFloat = 8

    private var tileWidth: CGFloat {
        let groups = groups
        let count = CGFloat(groups.reduce(0) { $0 + $1.tiles.count })
        let gaps = (count - CGFloat(groups.count)) * Self.tileGap + CGFloat(groups.count - 1) * Self.groupGap
        return max(14, min(32, ((available - gaps) / max(count, 1)).rounded(.down)))
    }

    var body: some View {
        let width = tileWidth
        HStack(alignment: .top, spacing: Self.groupGap) {
            ForEach(groups) { group in
                HStack(alignment: .top, spacing: Self.tileGap) {
                    ForEach(Array(group.tiles.enumerated()), id: \.offset) { i, tile in
                        VStack(spacing: 5) {
                            TileFace(tile: tile, width: width)
                            // 一组吃碰杠只在中间那张下面写一次
                            Text(i == (group.tiles.count - 1) / 2 ? group.mark ?? " " : " ")
                                .font(.system(size: 12, weight: group.isWinning ? .medium : .regular))
                                .foregroundStyle(group.isWinning ? Theme.ink : Theme.gray)
                                .fixedSize()
                        }
                    }
                }
            }
        }
        // minWidth: 0：这一层只按给的宽度算，不被牌排撑宽。不然哪次量大了（iPhone Duo 外屏刚开时侧边状态栏还没让出来），
        // 牌按大的宽度画、把这一层撑宽，再量还是大的，牌就一直超出屏幕
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { available = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var parts = hand.melds.map(\.displayText)
        var standing = hand.concealed
        if let i = standing.lastIndex(of: hand.winningTile) { standing.remove(at: i) }
        parts.append(standing.map(\.displayName).joined(separator: " "))
        parts.append("和 \(hand.winningTile.displayName)")
        return parts.joined(separator: "，")
    }
}
