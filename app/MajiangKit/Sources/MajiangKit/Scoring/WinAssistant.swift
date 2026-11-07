import Foundation

/// 照片拍不出来、要用户在核对页勾一下的情况（立直、一发、双立直、岭上开花、海底、河底、抢杠）。
public enum SpecialWin: String, CaseIterable, Hashable, Codable, Sendable {
    /// 立直：门前清听牌宣布立直，1 翻。
    case riichi
    /// 一发：立直后一巡内和牌，1 翻。
    case ippatsu
    /// 双立直：第一巡无人副露时宣布立直，2 翻。
    case doubleRiichi
    /// 岭上开花：开杠后补牌自摸，1 翻。
    case kongReplacement
    /// 海底摸月：牌山最后一张自摸，1 翻。
    case lastTileDraw
    /// 河底捞鱼：全桌最后一张点炮和牌，1 翻。
    case lastTileClaim
    /// 抢杠：别人加杠时抢和，1 翻。
    case robbingTheKong
    /// 天和 / 地和：第一巡无人吃碰杠时自摸和牌（庄家为天和，闲家为地和，役满）。
    case blessingOfHeavenOrEarth

    public var name: String {
        switch self {
        case .riichi: return tr("立直", "リーチ", "Riichi")
        case .ippatsu: return tr("一发", "一発", "Ippatsu")
        case .doubleRiichi: return tr("双立直", "ダブルリーチ", "Double Riichi")
        case .kongReplacement: return tr("岭上开花", "嶺上開花", "Rinshan Kaihou")
        case .lastTileDraw: return tr("海底摸月", "海底摸月", "Haitei")
        case .lastTileClaim: return tr("河底捞鱼", "河底撈魚", "Houtei")
        case .robbingTheKong: return tr("抢杠", "槍槓", "Chankan")
        case .blessingOfHeavenOrEarth: return tr("天和 / 地和", "天和・地和", "Tenhou / Chiihou")
        }
    }

    public var fan: Fan {
        switch self {
        case .riichi: return .riichi
        case .ippatsu: return .ippatsu
        case .doubleRiichi: return .doubleRiichi
        case .kongReplacement: return .rinshan
        case .lastTileDraw: return .haitei
        case .lastTileClaim: return .houtei
        case .robbingTheKong: return .chankan
        case .blessingOfHeavenOrEarth: return .tenhou
        }
    }

    /// 勾选上这一项加几翻。
    public var fanPoints: Int { fan.points }

    /// 一句白话说明。
    public var plain: String {
        switch self {
        case .riichi: return tr("门前清听牌时宣布了立直", "門前清で聴牌しリーチを宣言", "Declared Riichi with a closed tenpai hand")
        case .ippatsu: return tr("立直后一巡内和牌，中间没人吃碰杠", "リーチ後1巡以内に和了（鳴きなし）", "Won within one turn after Riichi with no calls")
        case .doubleRiichi: return tr("第一巡还没人吃碰杠时就立直了", "鳴きのない第1巡目にリーチを宣言", "Declared Riichi on the first turn with no calls")
        case .kongReplacement: return tr("杠完摸岭上牌，正好自摸和了", "槓した後の嶺上牌でツモ和了", "Self-drawn win on the replacement tile after a kan")
        case .lastTileDraw: return tr("摸牌山最后一张牌时自摸和了", "牌山の最後の1枚でツモ和了", "Self-drawn win on the last tile of the wall")
        case .lastTileClaim: return tr("和的是别人打出的最后一张牌", "河の最後の打牌でロン和了", "Won by ron on the very last discard")
        case .robbingTheKong: return tr("别人加杠时，正好抢和他加的那张", "他家の加槓牌でロン和了", "Won off a tile another player added to an open pung")
        case .blessingOfHeavenOrEarth: return tr("第一巡还没人吃碰杠时直接自摸和牌（役满）", "第1ツモでそのままツモ和了（役満）", "First-turn self-drawn win with no prior calls (Yakuman)")
        }
    }

    /// 这手牌下能不能选；不能选时返回原因（界面用来置灰）。
    public func unavailableReason(hand: Hand, selfDrawn: Bool) -> String? {
        let isMenzen = hand.melds.allSatisfy { $0.kind == .kong && $0.isConcealed }
        switch self {
        case .riichi, .ippatsu, .doubleRiichi:
            guard isMenzen else { return tr("有吃、碰、明杠时不能立直", "鳴いている場合はリーチできません", "Cannot Riichi with an open hand") }
            return nil
        case .kongReplacement:
            guard selfDrawn else { return tr("岭上开花只能是自摸", "嶺上開花はツモのみです", "Rinshan Kaihou requires Tsumo") }
            guard hand.melds.contains(where: { $0.kind == .kong }) else { return tr("这手牌没有杠", "槓子がありません", "No kan in this hand") }
            return nil
        case .lastTileDraw:
            return selfDrawn ? nil : tr("海底摸月只能是自摸", "海底摸月はツモのみです", "Haitei requires Tsumo")
        case .lastTileClaim:
            return selfDrawn ? tr("河底捞鱼只能是点炮", "河底撈魚はロンのみです", "Houtei requires Ron") : nil
        case .robbingTheKong:
            guard !selfDrawn else { return tr("抢杠只能是点炮", "槍槓はロンのみです", "Chankan requires Ron") }
            let ownCopies = hand.allTiles.filter { $0 == hand.winningTile }.count
            return ownCopies > 1 ? tr(
                "手牌里已经有 \(ownCopies) 张 \(hand.winningTile.displayName)，别人没法加杠这张",
                "手牌に \(hand.winningTile.displayName) が \(ownCopies) 枚あるため加槓できません",
                "Already \(ownCopies) copies of \(hand.winningTile.displayName) in hand"
            ) : nil
        case .blessingOfHeavenOrEarth:
            guard selfDrawn && hand.melds.isEmpty else {
                return tr("天和 / 地和只能是门前清无杠自摸", "天和・地和は門前ツモ（槓なし）のみです", "Tenhou / Chiihou requires a closed Tsumo with no kans")
            }
            return nil
        }
    }

    /// 跟这一项不能同时选的（选了新的就把冲突的旧项替掉）。
    public var conflicts: Set<SpecialWin> {
        switch self {
        case .riichi: return [.doubleRiichi, .blessingOfHeavenOrEarth]
        case .doubleRiichi: return [.riichi, .blessingOfHeavenOrEarth]
        case .ippatsu: return [.kongReplacement, .blessingOfHeavenOrEarth]
        case .kongReplacement: return [.ippatsu, .lastTileDraw, .lastTileClaim, .robbingTheKong, .blessingOfHeavenOrEarth]
        case .lastTileDraw: return [.kongReplacement, .lastTileClaim, .robbingTheKong, .blessingOfHeavenOrEarth]
        case .lastTileClaim: return [.kongReplacement, .lastTileDraw, .robbingTheKong, .blessingOfHeavenOrEarth]
        case .robbingTheKong: return [.kongReplacement, .lastTileDraw, .lastTileClaim, .blessingOfHeavenOrEarth]
        case .blessingOfHeavenOrEarth: return [.riichi, .doubleRiichi, .ippatsu, .kongReplacement, .lastTileDraw, .lastTileClaim, .robbingTheKong]
        }
    }

    public static func apply(_ set: Set<SpecialWin>, to context: inout WinContext) {
        context.doubleRiichi = set.contains(.doubleRiichi)
        context.riichi = set.contains(.riichi) || (set.contains(.ippatsu) && !set.contains(.doubleRiichi))
        context.ippatsu = set.contains(.ippatsu)
        context.lastTileOfWall = set.contains(.lastTileDraw) || set.contains(.lastTileClaim)
        context.kongInvolved = set.contains(.kongReplacement) || set.contains(.robbingTheKong)
        context.firstTurnWin = set.contains(.blessingOfHeavenOrEarth)
    }

    public static func from(_ context: WinContext) -> Set<SpecialWin> {
        var result: Set<SpecialWin> = []
        if context.firstTurnWin {
            result.insert(.blessingOfHeavenOrEarth)
            return result
        }
        if context.doubleRiichi {
            result.insert(.doubleRiichi)
        } else if context.riichi {
            result.insert(.riichi)
        }
        if context.ippatsu { result.insert(.ippatsu) }
        if context.lastTileOfWall { result.insert(context.selfDrawn ? .lastTileDraw : .lastTileClaim) }
        if context.kongInvolved { result.insert(context.selfDrawn ? .kongReplacement : .robbingTheKong) }
        return result
    }
}

/// 改一张牌（或补一张漏读的牌）就能和的建议。
public struct FixSuggestion: Hashable, Sendable {
    /// `concealed` 里的下标；nil 表示不是改某一张，而是补一张。
    public let index: Int?
    public let from: Tile?
    public let to: Tile
    public let result: ScoringResult

    /// 拍照识别最容易把同花色点数看差一两点，排在前面。
    var distance: Int {
        guard let from else { return 0 }
        if from.suit == to.suit { return from.isHonor ? 3 : abs(from.rank - to.rank) }
        return 10
    }
}

public enum WinAssistant {
    /// 和不了时用人话告诉用户为什么。能和时返回 nil。
    public static func explain(_ hand: Hand, context: WinContext = WinContext(), minimumFan: Int = 1) -> String? {
        switch FanCalculator.score(hand, context: context) {
        case .success(let result):
            if result.meetsMinimum(minimumFan) { return nil }
            let doraNote = result.doraFan > 0 ? tr(
                "（宝牌 \(result.doraFan) 翻不算进起和役）",
                "（ドラ\(result.doraFan)翻は役に含まれません）",
                " (\(result.doraFan) Dora han do not count as yaku)"
            ) : ""
            if result.fanWithoutDora == 0 {
                return tr(
                    "无役\(doraNote)，立直麻将至少要有 \(minimumFan) 翻役才能和。",
                    "役なし\(doraNote)。和了には\(minimumFan)翻以上の役が必要です。",
                    "No yaku\(doraNote). At least \(minimumFan) han of yaku is required to win."
                )
            }
            return tr(
                "只有 \(result.fanWithoutDora) 翻役\(doraNote)，本场要 \(minimumFan) 翻才能和。",
                "\(result.fanWithoutDora)翻のみ\(doraNote)。この卓は\(minimumFan)翻縛りです。",
                "Only \(result.fanWithoutDora) han of yaku\(doraNote); \(minimumFan) han required."
            )
        case .failure(.wrongTileCount):
            let expected = 14 - hand.melds.count * 3
            return tr(
                "张数不对：立牌应该是 \(expected) 张，现在是 \(hand.concealed.count) 张。",
                "枚数が合いません：手牌は \(expected) 枚のはずですが、現在 \(hand.concealed.count) 枚です。",
                "Wrong tile count: expected \(expected) standing tiles, got \(hand.concealed.count)."
            )
        case .failure(.tileMoreThanFour):
            let names = hand.overusedTiles.map(\.displayName).joined(separator: tr("、", "・", ", "))
            return tr(
                "\(names) 超过了 4 张，一定有牌认错了。",
                "\(names) が5枚以上あります。読み取り間違いがあります。",
                "More than 4 copies of \(names); a tile was misread."
            )
        case .failure(.notAWin):
            return tr(
                "这副牌凑不成和牌（需要 4 面子加 1 雀头，或七对子、国士无双）。",
                "和了形になっていません（4面子1雀頭・七対子・国士無双のいずれかが必要）。",
                "Not a winning hand shape (needs 4 groups + 1 pair, Seven Pairs, or Thirteen Orphans)."
            )
        }
    }

    /// 识别差一张导致和不了时，找出改哪一张（或补哪一张）就能和。
    /// 如果牌型本身已经成立、只是无役，不给改牌建议（牌可能没认错，是漏选了立直或真的无役）。
    public static func fixSuggestions(for hand: Hand, context: WinContext = WinContext(),
                                      minimumFan: Int = 1, limit: Int = 4) -> [FixSuggestion] {
        guard hand.melds.allSatisfy(\.isValid) else { return [] }
        let expected = 14 - hand.melds.count * 3

        if hand.concealed.count == expected - 1 {
            return FanCalculator.waitingTiles(melds: hand.melds, standing: hand.concealed).compactMap { tile in
                let candidate = Hand(melds: hand.melds, concealed: hand.concealed + [tile], winningTile: tile)
                guard case .success(let result) = FanCalculator.score(candidate, context: context),
                      result.meetsMinimum(minimumFan) else { return nil }
                return FixSuggestion(index: nil, from: nil, to: tile, result: result)
            }
        }

        guard hand.concealed.count == expected else { return [] }
        if FanCalculator.isWinningShape(hand) { return [] }

        var suggestions: [FixSuggestion] = []
        let used = Dictionary(grouping: hand.allTiles, by: { $0 }).mapValues(\.count)
        let winIsLast = hand.concealed.last == hand.winningTile

        for i in hand.concealed.indices {
            let original = hand.concealed[i]
            for replacement in Tile.all where replacement != original {
                if (used[replacement] ?? 0) >= 4 { continue }
                var copy = hand.concealed
                copy[i] = replacement
                let win = (i == copy.count - 1 && winIsLast) ? replacement : hand.winningTile
                let candidate = Hand(melds: hand.melds, concealed: copy, winningTile: win)
                guard case .success(let result) = FanCalculator.score(candidate, context: context),
                      result.meetsMinimum(minimumFan) else { continue }
                suggestions.append(FixSuggestion(index: i, from: original, to: replacement, result: result))
            }
        }

        suggestions.sort { ($0.distance, $0.index ?? 0) < ($1.distance, $1.index ?? 0) }
        var seen = Set<Int>()
        return suggestions.filter { s in
            guard let i = s.index else { return true }
            return seen.insert(i).inserted
        }
        .prefix(limit)
        .map { $0 }
    }
}
