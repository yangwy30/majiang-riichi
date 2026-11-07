import Foundation

public struct Player: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var name: String

    public init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

/// 牌局规则。默认是立直麻将半庄规则（东南战 8 局、1 翻起和、计宝牌）；桌规不同的地方可以改。
public struct GameRules: Hashable, Codable, Sendable {
    /// 每 1000 点折合多少元（默认 1000 点 = 1 元）。
    public var yuanPerPoint: Double = 1
    /// 兼容旧字段。
    public var basePoints: Int = 0
    /// 起和翻数（立直麻将默认 1 翻起和，宝牌不计入）。
    public var minimumFan: Int = 1
    /// 是否计入宝牌（表宝牌、赤宝牌、里宝牌）。
    public var includeFlowers: Bool = true
    /// 切上满贯：30 符 4 翻、60 符 3 翻按满贯（8000 / 12000 点）算。
    public var kiriageMangan: Bool = false
    /// 每圈换座；朋友局一般不换。
    public var swapSeatsEachRound: Bool = false
    /// 错和罚符：赔另外三家各多少点（默认各 3000 点，共 9000 点）。
    public var falseWinPenalty: Int = 3000
    /// 一场几局（默认半庄战 8 局 = 东四局 + 南四局；东风战为 4 局）。
    public var totalHands: Int = 8
    /// 封顶：一把最多按几翻算（含宝牌），0 为不封顶（13 翻以上累计役满）。
    public var fanCap: Int = 0
    /// 副露断幺九（喰断）：默认 true（允许吃碰后断幺九）；false 时断幺九必须门前清。
    public var allowKuitan: Bool = true
    /// 终局顺位马（ウマ）：0 为不设，10 为 5-10（±10000 / ±5000），20 为 10-20（±20000 / ±10000），30 为 10-30（±30000 / ±10000）。
    public var uma: Int = 0
    /// 立直麻将荣和由放铳者一家包付。
    public var onlyDiscarderPays: Bool = true

    public init() {}

    /// 标准半庄（东南战 8 局）。
    public static let standard = GameRules()

    /// 东风战（4 局快局）。
    public static var beginner: GameRules {
        var rules = GameRules()
        rules.totalHands = 4
        return rules
    }

    /// 计分规则一样（不比 1000 点几元：汇率每桌自己定，换预设不动它）。
    public func scoresLike(_ other: GameRules) -> Bool {
        var copy = other
        copy.yuanPerPoint = yuanPerPoint
        return copy == self
    }

    /// 封顶以后这一把按几翻算。
    public func cappedFan(_ fan: Int) -> Int {
        fanCap > 0 ? min(fan, fanCap) : fan
    }

    /// 一把和牌按几翻计分：不计宝牌时去掉宝牌翻数，再按封顶算。
    public func paidFan(_ win: WinRecord) -> Int {
        let fan = cappedFan(includeFlowers ? win.totalFan : win.totalFan - win.flowerFan)
        // 累计役满最多算一倍；手动改翻时 `fans` 不可信，保留手填的翻数。
        guard win.fanOverride == nil, !win.fans.contains(where: { $0.fan.isYakuman }) else { return fan }
        return min(fan, 13)
    }

    enum CodingKeys: String, CodingKey {
        case yuanPerPoint, basePoints, minimumFan, includeFlowers, kiriageMangan
        case swapSeatsEachRound, falseWinPenalty, totalHands, fanCap, allowKuitan, uma, onlyDiscarderPays
    }

    /// 缺的字段用默认值，以后加规则不会让旧存档读不出来。
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = GameRules()
        yuanPerPoint = try c.decodeIfPresent(Double.self, forKey: .yuanPerPoint) ?? d.yuanPerPoint
        basePoints = try c.decodeIfPresent(Int.self, forKey: .basePoints) ?? d.basePoints
        minimumFan = try c.decodeIfPresent(Int.self, forKey: .minimumFan) ?? d.minimumFan
        includeFlowers = try c.decodeIfPresent(Bool.self, forKey: .includeFlowers) ?? d.includeFlowers
        kiriageMangan = try c.decodeIfPresent(Bool.self, forKey: .kiriageMangan) ?? d.kiriageMangan
        swapSeatsEachRound = try c.decodeIfPresent(Bool.self, forKey: .swapSeatsEachRound) ?? d.swapSeatsEachRound
        falseWinPenalty = try c.decodeIfPresent(Int.self, forKey: .falseWinPenalty) ?? d.falseWinPenalty
        totalHands = try c.decodeIfPresent(Int.self, forKey: .totalHands) ?? d.totalHands
        fanCap = try c.decodeIfPresent(Int.self, forKey: .fanCap) ?? d.fanCap
        allowKuitan = try c.decodeIfPresent(Bool.self, forKey: .allowKuitan) ?? d.allowKuitan
        uma = try c.decodeIfPresent(Int.self, forKey: .uma) ?? d.uma
        onlyDiscarderPays = try c.decodeIfPresent(Bool.self, forKey: .onlyDiscarderPays) ?? d.onlyDiscarderPays
    }
}

/// 一局的结果。
public enum HandOutcome: Hashable, Codable, Sendable {
    case win(WinRecord)
    /// 流局：记录哪几家听牌（0–3）及哪几家在本局宣告了立直（每家投出 1000 点留作桌面供托）。
    case drawn(tenpai: Set<Int> = [], riichi: Set<Int> = [])
    /// 错和（诈和）：赔另外三家罚符，不推进局数。
    case falseWin(offender: Int)
    /// 手动记分，四个数加起来为 0。
    case manual(deltas: [Int], note: String)

    /// 这一局打完了没有（错和之后这一局继续打）。
    public var advancesHand: Bool {
        if case .falseWin = self { return false }
        return true
    }

    private enum CodingKeys: String, CodingKey {
        case win, drawn, falseWin, manual
    }
    private enum WinKeys: String, CodingKey { case _0 }
    private enum DrawnKeys: String, CodingKey { case tenpai, riichi }
    private enum FalseWinKeys: String, CodingKey { case offender }
    private enum ManualKeys: String, CodingKey { case deltas, note }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if c.contains(.win) {
            let nested = try c.nestedContainer(keyedBy: WinKeys.self, forKey: .win)
            self = .win(try nested.decode(WinRecord.self, forKey: ._0))
        } else if c.contains(.drawn) {
            let nested = try c.nestedContainer(keyedBy: DrawnKeys.self, forKey: .drawn)
            let riichi = try nested.decodeIfPresent(Set<Int>.self, forKey: .riichi) ?? []
            let tenpai = (try nested.decodeIfPresent(Set<Int>.self, forKey: .tenpai) ?? []).union(riichi)
            self = .drawn(tenpai: tenpai, riichi: riichi)
        } else if c.contains(.falseWin) {
            let nested = try c.nestedContainer(keyedBy: FalseWinKeys.self, forKey: .falseWin)
            self = .falseWin(offender: try nested.decode(Int.self, forKey: .offender))
        } else if c.contains(.manual) {
            let nested = try c.nestedContainer(keyedBy: ManualKeys.self, forKey: .manual)
            self = .manual(deltas: try nested.decode([Int].self, forKey: .deltas),
                           note: try nested.decode(String.self, forKey: .note))
        } else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "未知的 HandOutcome"))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .win(let win):
            var nested = c.nestedContainer(keyedBy: WinKeys.self, forKey: .win)
            try nested.encode(win, forKey: ._0)
        case .drawn(let tenpai, let riichi):
            var nested = c.nestedContainer(keyedBy: DrawnKeys.self, forKey: .drawn)
            let effectiveTenpai = tenpai.union(riichi)
            if !effectiveTenpai.isEmpty {
                try nested.encode(effectiveTenpai, forKey: .tenpai)
            }
            if !riichi.isEmpty {
                try nested.encode(riichi, forKey: .riichi)
            }
        case .falseWin(let offender):
            var nested = c.nestedContainer(keyedBy: FalseWinKeys.self, forKey: .falseWin)
            try nested.encode(offender, forKey: .offender)
        case .manual(let deltas, let note):
            var nested = c.nestedContainer(keyedBy: ManualKeys.self, forKey: .manual)
            try nested.encode(deltas, forKey: .deltas)
            try nested.encode(note, forKey: .note)
        }
    }
}

public struct WinRecord: Hashable, Codable, Sendable {
    /// 和牌者（玩家下标，0–3）。
    public var winner: Int
    /// 点炮者；nil 为自摸。
    public var discarder: Int?
    /// 确认后的手牌；手动输入翻数时可以为空。
    public var hand: Hand?
    public var context: WinContext
    public var fans: [FanEntry]
    /// 宝牌翻数。
    public var flowerFan: Int
    /// 符数（默认 30 符）。
    public var fu: Int
    /// 本局也宣告了立直的其他玩家（每人投出 1000 点立直棒，由和牌者收取）。
    public var riichiPlayers: Set<Int>
    /// 事后在账本里直接改了翻数（含宝牌）。有它时 `fans` 不再可信，界面清空明细，改局时也不重新算翻。
    public var fanOverride: Int?

    public init(winner: Int, discarder: Int?, hand: Hand?, context: WinContext, fans: [FanEntry], flowerFan: Int,
                fu: Int = 30, riichiPlayers: Set<Int> = [], fanOverride: Int? = nil) {
        self.winner = winner
        self.discarder = discarder
        self.hand = hand
        self.context = context
        self.fans = fans
        self.flowerFan = flowerFan
        self.fu = fu
        self.riichiPlayers = riichiPlayers.subtracting([winner])
        self.fanOverride = fanOverride
    }

    public init(winner: Int, discarder: Int?, hand: Hand, context: WinContext, result: ScoringResult,
                riichiPlayers: Set<Int> = []) {
        self.init(winner: winner, discarder: discarder, hand: hand, context: context,
                  fans: result.fans, flowerFan: result.flowerFan, fu: result.fu, riichiPlayers: riichiPlayers)
    }

    enum CodingKeys: String, CodingKey {
        case winner, discarder, hand, context, fans, flowerFan, fu, riichiPlayers, fanOverride
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        winner = try c.decode(Int.self, forKey: .winner)
        discarder = try c.decodeIfPresent(Int.self, forKey: .discarder)
        hand = try c.decodeIfPresent(Hand.self, forKey: .hand)
        context = try c.decode(WinContext.self, forKey: .context)
        fans = try c.decode([FanEntry].self, forKey: .fans)
        flowerFan = try c.decodeIfPresent(Int.self, forKey: .flowerFan) ?? 0
        fu = try c.decodeIfPresent(Int.self, forKey: .fu) ?? 30
        riichiPlayers = (try c.decodeIfPresent(Set<Int>.self, forKey: .riichiPlayers) ?? []).subtracting([winner])
        fanOverride = try c.decodeIfPresent(Int.self, forKey: .fanOverride)
    }

    public var totalFan: Int { fanOverride ?? fans.reduce(0) { $0 + $1.points } + flowerFan }
    public var isSelfDrawn: Bool { discarder == nil }
}

public struct HandRecord: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    /// 第几局（0 起：0–3 为东一至东四，4–7 为南一至南四），错和记在当前局上。
    public var handIndex: Int
    /// 第几本场（0 起：庄家连庄或流局时递增）。
    public var honba: Int
    /// 本局开始时桌面上累积的立直供托点数（此前流局遗留的立直棒，每根 1000 点）。
    public var pot: Int
    public var outcome: HandOutcome
    /// 四个玩家本局的得失点数，下标同 `Game.players`。
    public var deltas: [Int]
    public var date: Date

    public init(id: UUID = UUID(), handIndex: Int, honba: Int = 0, pot: Int = 0, outcome: HandOutcome, deltas: [Int], date: Date = Date()) {
        self.id = id
        self.handIndex = handIndex
        self.honba = honba
        self.pot = pot
        self.outcome = outcome
        self.deltas = deltas
        self.date = date
    }

    enum CodingKeys: String, CodingKey {
        case id, handIndex, honba, pot, outcome, deltas, date
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        handIndex = try c.decode(Int.self, forKey: .handIndex)
        honba = try c.decodeIfPresent(Int.self, forKey: .honba) ?? 0
        pot = try c.decodeIfPresent(Int.self, forKey: .pot) ?? 0
        outcome = try c.decode(HandOutcome.self, forKey: .outcome)
        deltas = try c.decode([Int].self, forKey: .deltas)
        date = try c.decode(Date.self, forKey: .date)
    }
}

public enum GameError: Error, Hashable, Sendable {
    case finished
    case invalidPlayer
    case discarderIsWinner
    case belowMinimumFan(Int)
    case deltasMustSumToZero
    case recordNotFound
    case tooManyHands(Int)

    public var message: String {
        switch self {
        case .finished: return tr("这场牌局已经打完了", "この対局はすでに終了しています", "This game has already finished")
        case .invalidPlayer: return tr("玩家不对", "プレイヤーが正しくありません", "Invalid player")
        case .discarderIsWinner: return tr("点炮的人不能是和牌的人", "放銃者と和了者は同じにできません", "Discarder cannot be the winner")
        case .belowMinimumFan(let fan):
            return fan == 0
                ? tr("无役，不能和牌（宝牌不算起和役）", "役なしでは和了できません（ドラは役に含まれません）", "No yaku (Dora does not count as yaku)")
                : tr("只有 \(fan) 翻役，不够起和", "\(fan)翻のみのため縛りを満たしていません", "Only \(fan) han of yaku, below minimum")
        case .deltasMustSumToZero: return tr("四个人的得失点加起来要等于 0", "4人の収支合計は0にしてください", "The 4 players' point changes must sum to 0")
        case .recordNotFound: return tr("找不到这一局", "この局が見つかりません", "Hand record not found")
        case .tooManyHands(let total): return tr("这样改就超过 \(total) 局了", "\(total)局を超えてしまいます", "Exceeds \(total) hands")
        }
    }
}

/// 一场牌局：四个人、规则、每一局的记录。场风、自风、庄家都从局数推出来，不用存。
public struct Game: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var startedAt: Date
    public var endedAt: Date?
    /// 开局时的座位：下标 0 东、1 南、2 西、3 北。东家是第一局的庄。
    public var players: [Player]
    /// 用这台手机的人是 `players` 里的第几个（牌桌图上画在最下面，首页历史显示他的输赢）。
    public var me: Int
    public var rules: GameRules
    public private(set) var records: [HandRecord]

    public init(id: UUID = UUID(), players: [Player], me: Int = 0, rules: GameRules = GameRules(), startedAt: Date = Date()) {
        precondition(players.count == 4, "立直麻将固定 4 人")
        precondition((0..<4).contains(me), "我必须是四个人之一")
        self.id = id
        self.players = players
        self.me = me
        self.rules = rules
        self.records = []
        self.startedAt = startedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, startedAt, endedAt, players, me, rules, records
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        startedAt = try c.decode(Date.self, forKey: .startedAt)
        endedAt = try c.decodeIfPresent(Date.self, forKey: .endedAt)
        players = try c.decode([Player].self, forKey: .players)
        let me = try c.decodeIfPresent(Int.self, forKey: .me) ?? 0
        self.me = (0..<4).contains(me) ? me : 0
        rules = try c.decodeIfPresent(GameRules.self, forKey: .rules) ?? GameRules()
        records = try c.decodeIfPresent([HandRecord].self, forKey: .records) ?? []
    }

    // MARK: 局数、本场、供托、场风、自风

    /// 已经打完的实际局数（不含错和，含庄家连庄的本场）。
    public var playedHandsCount: Int { records.filter(\.outcome.advancesHand).count }

    private func nextProgression(after outcome: HandOutcome, inHand hand: Int, honba: Int, pot: Int) -> (hand: Int, honba: Int, pot: Int) {
        let currentDealer = dealer(ofHand: hand)
        switch outcome {
        case .win(let win):
            if win.winner == currentDealer {
                return (hand, honba + 1, 0)
            } else {
                return (hand + 1, 0, 0)
            }
        case .drawn(let tenpai, let riichi):
            let validRiichi = riichi.filter { (0..<4).contains($0) }
            let effectiveTenpai = tenpai.union(validRiichi)
            let nextPot = pot + validRiichi.count * 1000
            if effectiveTenpai.contains(currentDealer) {
                return (hand, honba + 1, nextPot)
            } else {
                return (hand + 1, honba + 1, nextPot)
            }
        case .falseWin:
            return (hand, honba, pot)
        case .manual:
            return (hand + 1, 0, pot)
        }
    }

    private var currentProgression: (hand: Int, honba: Int, pot: Int) {
        var state = (hand: 0, honba: 0, pot: 0)
        for record in records {
            state = nextProgression(after: record.outcome, inHand: state.hand, honba: state.honba, pot: state.pot)
        }
        return state
    }

    /// 当前是第几局（0 起：0–3 东一至东四，4–7 南一至南四）。庄家和牌或流局听牌时连庄不进位。
    public var currentHandIndex: Int { currentProgression.hand }

    /// 当前是第几本场（0 起：庄家连庄或流局时 +1，闲家和牌归零）。
    public var currentHonba: Int { currentProgression.honba }

    /// 当前桌面上累积的立直供托点数（流局遗留的立直棒，每根 1000 点；下次有人和牌时由和牌者全收）。
    public var currentPot: Int { currentProgression.pot }

    public var isFinished: Bool { endedAt != nil || currentHandIndex >= rules.totalHands }

    public var remainingHands: Int { max(0, rules.totalHands - currentHandIndex) }

    /// 第几圈（0 东场、1 南场……），超过 4 圈按北场算。
    public func roundIndex(ofHand hand: Int) -> Int { min(hand / 4, 3) }

    public func prevalentWind(ofHand hand: Int) -> Wind { Wind(rawValue: roundIndex(ofHand: hand))! }

    public var prevalentWind: Wind { prevalentWind(ofHand: currentHandIndex) }

    /// 这一场风里，桌子东南西北四个位置上坐的是谁（玩家下标）。
    public func seating(ofRound round: Int) -> [Int] {
        guard rules.swapSeatsEachRound else { return [0, 1, 2, 3] }
        let table = [[0, 1, 2, 3], [1, 0, 3, 2], [2, 3, 1, 0], [3, 2, 0, 1]]
        return table[min(max(round, 0), 3)]
    }

    /// 某局里玩家坐在哪个位置（0 东位 … 3 北位）。
    public func position(of player: Int, inHand hand: Int) -> Int {
        seating(ofRound: roundIndex(ofHand: hand)).firstIndex(of: player)!
    }

    /// 某局的庄家（玩家下标）。
    public func dealer(ofHand hand: Int) -> Int {
        seating(ofRound: roundIndex(ofHand: hand))[hand % 4]
    }

    public var dealer: Int { dealer(ofHand: currentHandIndex) }

    /// 某局玩家的自风：庄家是东，下家是南，依此类推。
    public func seatWind(of player: Int, inHand hand: Int) -> Wind {
        let offset = (position(of: player, inHand: hand) - hand % 4 + 4) % 4
        return Wind(rawValue: offset)!
    }

    public func seatWind(of player: Int) -> Wind { seatWind(of: player, inHand: currentHandIndex) }

    /// 当前局某个玩家和牌时的 WinContext（场风、自风、喰断已经填好）。
    public func winContext(for winner: Int) -> WinContext {
        WinContext(prevalentWind: prevalentWind, seatWind: seatWind(of: winner), allowKuitan: rules.allowKuitan)
    }

    // MARK: 分数

    /// 每个人的累计净得失点。终局时若桌面仍有未收走的立直供托棒，按日麻标准规则（トップ取り）归第一名；若设有顺位马（ウマ），终局时按名次加减。
    public var scores: [Int] {
        var total = records.reduce(into: [0, 0, 0, 0]) { acc, record in
            for i in 0..<4 { acc[i] += record.deltas[i] }
        }
        if isFinished {
            if currentPot > 0, let top = Settlement.ranking(scores: total).first {
                total[top] += currentPot
            }
            if rules.uma > 0 {
                let ranked = Settlement.ranking(scores: total)
                let topBonus = rules.uma * 1000
                let secondBonus = (rules.uma == 10 ? 5 : 10) * 1000
                let bonuses = [topBonus, secondBonus, -secondBonus, -topBonus]
                for (rank, player) in ranked.enumerated() where rank < 4 {
                    total[player] += bonuses[rank]
                }
            }
        }
        return total
    }

    /// 点数折合多少元（按 `yuanPerPoint` = 每 1000 点几元计算）。
    public func money(forPoints points: Int) -> Double {
        (Double(points) / 1000.0) * rules.yuanPerPoint
    }

    /// 本场最大的一手和牌。
    public var biggestWin: (record: HandRecord, win: WinRecord)? {
        records.compactMap { record -> (HandRecord, WinRecord)? in
            if case .win(let win) = record.outcome { return (record, win) }
            return nil
        }
        .max { ($0.0.deltas[$0.1.winner], $0.1.totalFan) < ($1.0.deltas[$1.1.winner], $1.1.totalFan) }
    }

    // MARK: 记分

    @discardableResult
    public mutating func recordWin(_ win: WinRecord) throws -> HandRecord {
        guard !isFinished else { throw GameError.finished }
        try validate(.win(win))
        let state = currentProgression
        let outcome = HandOutcome.win(win)
        return append(outcome, inHand: state.hand, honba: state.honba, pot: state.pot,
                      deltas: deltas(for: outcome, inHand: state.hand, honba: state.honba, pot: state.pot))
    }

    @discardableResult
    public mutating func recordDraw(tenpai: Set<Int> = [], riichi: Set<Int> = []) throws -> HandRecord {
        guard !isFinished else { throw GameError.finished }
        let validRiichi = riichi.filter { (0..<4).contains($0) }
        let validTenpai = tenpai.filter { (0..<4).contains($0) }.union(validRiichi)
        let state = currentProgression
        let outcome = HandOutcome.drawn(tenpai: validTenpai, riichi: validRiichi)
        return append(outcome, inHand: state.hand, honba: state.honba, pot: state.pot,
                      deltas: deltas(for: outcome, inHand: state.hand, honba: state.honba, pot: state.pot))
    }

    @discardableResult
    public mutating func recordFalseWin(offender: Int) throws -> HandRecord {
        guard !isFinished else { throw GameError.finished }
        try validate(.falseWin(offender: offender))
        let state = currentProgression
        let outcome = HandOutcome.falseWin(offender: offender)
        return append(outcome, inHand: state.hand, honba: state.honba, pot: state.pot,
                      deltas: deltas(for: outcome, inHand: state.hand, honba: state.honba, pot: state.pot))
    }

    @discardableResult
    public mutating func recordManual(deltas: [Int], note: String = "") throws -> HandRecord {
        guard !isFinished else { throw GameError.finished }
        try validate(.manual(deltas: deltas, note: note))
        let state = currentProgression
        return append(.manual(deltas: deltas, note: note), inHand: state.hand, honba: state.honba, pot: state.pot, deltas: deltas)
    }

    /// 撤销最后一条记录。
    @discardableResult
    public mutating func undoLast() -> HandRecord? {
        guard !records.isEmpty else { return nil }
        endedAt = nil
        return records.removeLast()
    }

    public mutating func end(at date: Date = Date()) {
        endedAt = date
    }

    // MARK: 改以前的局

    public mutating func replace(_ id: UUID, with outcome: HandOutcome) throws {
        self = try replacing(id, with: outcome)
    }

    public func replacing(_ id: UUID, with outcome: HandOutcome) throws -> Game {
        guard let index = records.firstIndex(where: { $0.id == id }) else { throw GameError.recordNotFound }
        var copy = self
        copy.records[index].outcome = outcome
        try copy.reflow(edited: id)
        return copy
    }

    public mutating func changeRules(_ newRules: GameRules) throws {
        self = try changingRules(newRules)
    }

    public func changingRules(_ newRules: GameRules) throws -> Game {
        var copy = self
        copy.rules = newRules
        try copy.reflow(edited: nil)
        return copy
    }

    /// 按现在的起和翻数，役翻不够的和牌（中途调高了起和翻数时会有）。
    public var winsBelowMinimum: [HandRecord] {
        records.filter { record in
            guard case .win(let win) = record.outcome else { return false }
            return win.totalFan - win.flowerFan < rules.minimumFan
        }
    }

    /// 删掉某一局，后面的跟着重算。
    public mutating func remove(_ id: UUID) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        records.remove(at: index)
        try? reflow(edited: nil)
    }

    private mutating func reflow(edited: UUID?) throws {
        var state = (hand: 0, honba: 0, pot: 0)
        for i in records.indices {
            let hand = state.hand
            let honba = state.honba
            let pot = state.pot
            records[i].handIndex = hand
            records[i].honba = honba
            records[i].pot = pot
            let isEdited = records[i].id == edited
            if case .win(let win) = records[i].outcome {
                records[i].outcome = .win(reconciled(win, inHand: hand, edited: isEdited))
            } else if case .drawn(let tenpai, let riichi) = records[i].outcome {
                records[i].outcome = .drawn(tenpai: tenpai.union(riichi), riichi: riichi)
            }
            if isEdited { try validate(records[i].outcome) }
            records[i].deltas = deltas(for: records[i].outcome, inHand: hand, honba: honba, pot: pot)
            state = nextProgression(after: records[i].outcome, inHand: hand, honba: honba, pot: pot)
        }
        guard state.hand <= rules.totalHands else { throw GameError.tooManyHands(rules.totalHands) }
    }

    private func reconciled(_ win: WinRecord, inHand hand: Int, edited: Bool) -> WinRecord {
        var context = win.context
        context.prevalentWind = prevalentWind(ofHand: hand)
        context.seatWind = seatWind(of: win.winner, inHand: hand)
        context.selfDrawn = win.isSelfDrawn
        context.allowKuitan = rules.allowKuitan
        if context.selfDrawn != win.context.selfDrawn {
            context.kongInvolved = false
            context.lastTileOfWall = false
        }
        guard edited || context != win.context else { return win }

        var updated = win
        updated.context = context
        updated.riichiPlayers.remove(win.winner)
        if let tiles = win.hand, win.fanOverride == nil,
           case .success(let result) = FanCalculator.score(tiles, context: context),
           edited || result.meetsMinimum(rules.minimumFan) {
            updated.fans = result.fans
            updated.flowerFan = result.flowerFan
            updated.fu = result.fu
        }
        return updated
    }

    private func validate(_ outcome: HandOutcome) throws {
        switch outcome {
        case .win(let win):
            guard (0..<4).contains(win.winner) else { throw GameError.invalidPlayer }
            if let discarder = win.discarder {
                guard (0..<4).contains(discarder) else { throw GameError.invalidPlayer }
                guard discarder != win.winner else { throw GameError.discarderIsWinner }
            }
            let fanWithoutFlowers = win.totalFan - win.flowerFan
            guard fanWithoutFlowers >= rules.minimumFan else { throw GameError.belowMinimumFan(fanWithoutFlowers) }
        case .drawn(let tenpai, let riichi):
            guard tenpai.allSatisfy({ (0..<4).contains($0) }), riichi.allSatisfy({ (0..<4).contains($0) }) else {
                throw GameError.invalidPlayer
            }
        case .falseWin(let offender):
            guard (0..<4).contains(offender) else { throw GameError.invalidPlayer }
        case .manual(let deltas, _):
            guard deltas.count == 4, deltas.reduce(0, +) == 0 else { throw GameError.deltasMustSumToZero }
        }
    }

    private func deltas(for outcome: HandOutcome, inHand handIndex: Int, honba: Int = 0, pot: Int = 0) -> [Int] {
        switch outcome {
        case .win(let win):
            return Payment.winDeltas(
                winner: win.winner,
                discarder: win.discarder,
                dealer: dealer(ofHand: handIndex),
                totalFan: rules.paidFan(win),
                fu: win.fu,
                honba: honba,
                pot: pot,
                riichiPlayers: win.riichiPlayers,
                rules: rules
            )
        case .drawn(let tenpai, let riichi):
            return Payment.drawDeltas(tenpai: tenpai, riichi: riichi)
        case .falseWin(let offender):
            return Payment.falseWinDeltas(offender: offender, penalty: rules.falseWinPenalty)
        case .manual(let deltas, _):
            return deltas
        }
    }

    private mutating func append(_ outcome: HandOutcome, inHand handIndex: Int, honba: Int, pot: Int, deltas: [Int]) -> HandRecord {
        let record = HandRecord(handIndex: handIndex, honba: honba, pot: pot, outcome: outcome, deltas: deltas)
        records.append(record)
        return record
    }
}

/// 立直麻将点数与收付计算。
public enum Payment {
    /// 按百位向上进位（如 `1920 -> 2000`，`3840 -> 3900`）。
    public static func ceil100(_ value: Int) -> Int {
        guard value > 0 else { return 0 }
        return ((value + 99) / 100) * 100
    }

    /// 基本点（$B = \text{符} \times 2^{\text{翻}+2}$，满贯封顶 2000，6 翻起跳满/倍满/三倍满/役满）。
    public static func basePoints(han: Int, fu: Int = 30, kiriageMangan: Bool = false) -> Int {
        guard han > 0 else { return 0 }
        if han >= 13 { return 8000 * (han / 13) }
        if han >= 11 { return 6000 }
        if han >= 8 { return 4000 }
        if han >= 6 { return 3000 }
        if han == 5 || (han == 4 && fu >= 40) || (han == 3 && fu >= 70) {
            return 2000
        }
        if kiriageMangan && ((han == 4 && fu == 30) || (han == 3 && fu == 60)) {
            return 2000
        }
        return min(2000, fu * (1 << (han + 2)))
    }

    /// 满贯及以上的段位名称（未达满贯返回 nil）。
    public static func limitName(han: Int, fu: Int = 30, kiriageMangan: Bool = false) -> String? {
        if han >= 39 { return tr("三倍役满", "トリプル役満", "Triple Yakuman") }
        if han >= 26 { return tr("双倍役满", "ダブル役満", "Double Yakuman") }
        if han >= 13 { return tr("役满", "役満", "Yakuman") }
        if han >= 11 { return tr("三倍满", "三倍満", "Sanbaiman") }
        if han >= 8 { return tr("倍满", "倍満", "Baiman") }
        if han >= 6 { return tr("跳满", "跳満", "Haneman") }
        if basePoints(han: han, fu: fu, kiriageMangan: kiriageMangan) == 2000 { return tr("满贯", "満貫", "Mangan") }
        return nil
    }

    /// 立直麻将一局和牌的四家得失点数：
    /// - 荣和（点炮）：放铳者一家付（庄家和 $6B$ 进百，闲家和 $4B$ 进百），每本场另加 300 点。
    /// - 自摸：庄家自摸三家各付 $2B$ 进百；闲家自摸庄家付 $2B$ 进百、另外两家闲家各付 $1B$ 进百；每本场三家各另付 100 点。
    /// - 立直供托棒：`riichiPlayers` 中除和牌者外的每家各扣 1000 点，连同桌面此前累积的 `pot` 供托点数一并归和牌者所有。
    public static func winDeltas(
        winner: Int,
        discarder: Int?,
        dealer: Int = 0,
        totalFan: Int,
        fu: Int = 30,
        honba: Int = 0,
        pot: Int = 0,
        riichiPlayers: Set<Int> = [],
        rules: GameRules = .standard
    ) -> [Int] {
        let han = rules.cappedFan(totalFan)
        let base = basePoints(han: han, fu: fu, kiriageMangan: rules.kiriageMangan)
        var deltas = [0, 0, 0, 0]
        guard base > 0 else { return deltas }
        let extraHonba = max(0, honba)

        if let discarder {
            let pay = ceil100(base * (winner == dealer ? 6 : 4)) + extraHonba * 300
            deltas[discarder] -= pay
            deltas[winner] += pay
        } else if winner == dealer {
            let each = ceil100(base * 2) + extraHonba * 100
            for p in 0..<4 where p != winner {
                deltas[p] -= each
                deltas[winner] += each
            }
        } else {
            let dealerPay = ceil100(base * 2) + extraHonba * 100
            let childPay = ceil100(base) + extraHonba * 100
            for p in 0..<4 where p != winner {
                let pay = (p == dealer) ? dealerPay : childPay
                deltas[p] -= pay
                deltas[winner] += pay
            }
        }

        for p in riichiPlayers where p != winner && (0..<4).contains(p) {
            deltas[p] -= 1000
            deltas[winner] += 1000
        }
        deltas[winner] += max(0, pot)
        return deltas
    }

    /// 荒牌流局听牌罚符（不听罚 3000 点）与流局立直棒供托：
    /// - 0 家或 4 家听牌：听牌罚符为 0；
    /// - 1 家听牌：听牌者 +3000，其余 3 家各 -1000；
    /// - 2 家听牌：听牌者各 +1500，其余 2 家各 -1500；
    /// - 3 家听牌：听牌者各 +1000，不听者 -3000；
    /// - 本局宣告立直的玩家（`riichi`）每家另扣 1000 点留作桌面供托。
    public static func drawDeltas(tenpai: Set<Int>, riichi: Set<Int> = []) -> [Int] {
        let validRiichi = riichi.filter { (0..<4).contains($0) }
        let valid = tenpai.filter { (0..<4).contains($0) }.union(validRiichi)
        var deltas: [Int]
        switch valid.count {
        case 1:
            deltas = (0..<4).map { valid.contains($0) ? 3000 : -1000 }
        case 2:
            deltas = (0..<4).map { valid.contains($0) ? 1500 : -1500 }
        case 3:
            deltas = (0..<4).map { valid.contains($0) ? 1000 : -3000 }
        default:
            deltas = [0, 0, 0, 0]
        }
        for p in validRiichi {
            deltas[p] -= 1000
        }
        return deltas
    }

    /// 错和罚符：赔另外三家各 `penalty` 点。
    public static func falseWinDeltas(offender: Int, penalty: Int) -> [Int] {
        (0..<4).map { $0 == offender ? -3 * penalty : penalty }
    }
}
