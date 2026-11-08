import Foundation

/// 一组吃、碰、杠。暗杠也放在这里（它在照片里摆在旁边，并且决定张数）。
public struct Meld: Hashable, Codable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        case chow   // 吃
        case pung   // 碰
        case kong   // 杠
    }

    public var kind: Kind
    /// 顺子写最小的那张（`567饼` 写 5饼）；刻子和杠写那张牌。
    public var tile: Tile
    /// 只对杠有意义：true 为暗杠。吃和碰一定是明的。
    public var isConcealed: Bool
    /// 这组里有几张赤五（吃的顺子含 5、或 5 的刻子和杠才可能有）。
    public var redCount: Int

    public var isValid: Bool {
        kind != .chow || (tile.isNumbered && tile.rank <= 7)
    }

    public init?(kind: Kind, tile: Tile, isConcealed: Bool = false, redCount: Int = 0) {
        if kind == .chow {
            guard tile.isNumbered, tile.rank <= 7 else { return nil }
        }
        self.kind = kind
        self.tile = tile.marked(red: false)
        self.isConcealed = kind == .kong ? isConcealed : false
        self.redCount = max(redCount, tile.isRed ? 1 : 0)
    }

    enum CodingKeys: String, CodingKey {
        case kind, tile, isConcealed, redCount
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = try c.decode(Kind.self, forKey: .kind)
        tile = try c.decode(Tile.self, forKey: .tile)
        isConcealed = try c.decodeIfPresent(Bool.self, forKey: .isConcealed) ?? false
        redCount = try c.decodeIfPresent(Int.self, forKey: .redCount) ?? 0
    }

    public static func chow(_ lowest: Tile) -> Meld? { Meld(kind: .chow, tile: lowest) }
    public static func pung(_ tile: Tile) -> Meld { Meld(kind: .pung, tile: tile)! }
    public static func kong(_ tile: Tile, concealed: Bool) -> Meld { Meld(kind: .kong, tile: tile, isConcealed: concealed)! }

    public var tiles: [Tile] {
        let plain: [Tile]
        switch kind {
        case .chow:
            plain = [tile, Tile(tile.suit, tile.rank + 1), Tile(tile.suit, tile.rank + 2)]
        case .pung:
            plain = [tile, tile, tile]
        case .kong:
            plain = [tile, tile, tile, tile]
        }
        var reds = redCount
        return plain.map { t in
            guard reds > 0, t.rank == 5, t.isNumbered else { return t }
            reds -= 1
            return t.marked(red: true)
        }
    }

    public var kindName: String {
        switch kind {
        case .chow: tr("吃", "チー", "Chi")
        case .pung: tr("碰", "ポン", "Pon")
        case .kong: isConcealed ? tr("暗杠", "暗槓", "Closed Kan") : tr("明杠", "明槓", "Open Kan")
        }
    }

    /// 例如「吃 567饼」「碰 东」「暗杠 9万」。
    public var displayText: String {
        switch kind {
        case .chow: "\(kindName) \(tiles.displayText)"
        default: "\(kindName) \(tile.displayName)"
        }
    }

    /// 由 3 或 4 张牌推出一组副露；4 张一定是杠。
    public static func from(tiles: [Tile], concealedKong: Bool = false) -> Meld? {
        let sorted = tiles.sorted()
        let reds = tiles.filter(\.isRed).count
        switch sorted.count {
        case 4 where Set(sorted).count == 1:
            return Meld(kind: .kong, tile: sorted[0], isConcealed: concealedKong, redCount: reds)
        case 3 where Set(sorted).count == 1:
            return Meld(kind: .pung, tile: sorted[0], redCount: reds)
        case 3:
            guard sorted[0].isNumbered,
                  sorted[1] == sorted[0].next,
                  sorted[2] == sorted[1].next else { return nil }
            return Meld(kind: .chow, tile: sorted[0], redCount: reds)
        default:
            return nil
        }
    }
}

/// 风：圈风和门风。
public enum Wind: Int, Codable, CaseIterable, Sendable {
    case east = 0, south, west, north

    public var name: String {
        switch AppLang.current {
        case .zh: return ["东", "南", "西", "北"][rawValue]
        case .ja: return ["東", "南", "西", "北"][rawValue]
        case .en: return ["East", "South", "West", "North"][rawValue]
        }
    }
    public var tile: Tile { Tile(.honors, rawValue + 1) }

    /// 逆时针下一个（东 → 南 → 西 → 北 → 东）。
    public var next: Wind { Wind(rawValue: (rawValue + 1) % 4)! }
}

/// 一手和牌：副露 + 立牌（含和的那张）。
public struct Hand: Hashable, Codable, Sendable {
    public var melds: [Meld]
    /// 立牌，包括和的那张。照片里从左到右的顺序。
    public var concealed: [Tile]
    public var winningTile: Tile

    public init(melds: [Meld] = [], concealed: [Tile], winningTile: Tile? = nil) {
        self.melds = melds
        self.concealed = concealed
        self.winningTile = winningTile ?? concealed.last ?? Tile(.characters, 1)
    }

    /// 所有牌（杠算 4 张）。
    public var allTiles: [Tile] { melds.flatMap(\.tiles) + concealed }

    public var kongCount: Int { melds.filter { $0.kind == .kong }.count }

    /// 立牌张数是否正确：3 × 副露组数 + 立牌 = 14。
    public var hasValidTileCount: Bool { concealed.count + 3 * melds.count == 14 }

    /// 超过 4 张的牌。
    public var overusedTiles: [Tile] {
        Dictionary(grouping: allTiles, by: { $0 }).filter { $0.value.count > 4 }.keys.sorted()
    }

    public var isConcealedHand: Bool { melds.allSatisfy { $0.kind == .kong && $0.isConcealed } }
}
