import Foundation

/// 一手牌的宝牌来源。指示牌和赤五自动数，`manual` 是用户手动增减的差额，算不准时用它兜底。
public struct DoraBreakdown: Hashable, Sendable {
    public var indicator: Int
    public var ura: Int
    public var red: Int
    public var manual: Int

    public var total: Int { max(0, indicator + ura + red + manual) }
    /// 不含手动差额的张数。
    public var automatic: Int { indicator + ura + red }
}

public enum Dora {
    /// 指示牌指向的宝牌：数牌 9 之后是 1，风牌东南西北循环，三元牌白 → 发 → 中 → 白。
    public static func next(after indicator: Tile) -> Tile {
        if indicator.isNumbered { return Tile(indicator.suit, indicator.rank % 9 + 1) }
        if indicator.isWind { return Tile(.honors, indicator.rank % 4 + 1) }
        // 字牌编号：5 中、6 发、7 白。
        switch indicator.rank {
        case 7: return Tile(.honors, 6)
        case 6: return Tile(.honors, 5)
        default: return Tile(.honors, 7)
        }
    }

    /// 这些指示牌在牌里一共指中几张（同一种指示牌翻出两张就算两遍）。
    public static func count(in tiles: [Tile], indicators: [Tile]) -> Int {
        indicators.reduce(0) { total, indicator in
            let dora = next(after: indicator)
            return total + tiles.filter { $0 == dora }.count
        }
    }

    /// 赤五张数。默认万、饼、条各一张，所以每种花色最多算一张。
    public static func redCount(in tiles: [Tile]) -> Int {
        Set(tiles.filter(\.isRed).map(\.suit)).count
    }
}
