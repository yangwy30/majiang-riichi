import XCTest
@testable import MajiangKit

/// 双响、流局满贯、途中流局、击飞和头名赏。规则取舍写在 AGENTS.md。
final class RiichiRulesTests: XCTestCase {
    private func players() -> [Player] { ["东", "南", "西", "北"].map { Player(name: $0) } }

    private func game(_ change: (inout GameRules) -> Void = { _ in }) -> Game {
        var rules = GameRules()
        change(&rules)
        return Game(players: players(), rules: rules)
    }

    /// 荣和一手 `han` 翻 30 符的牌。
    private func ron(_ winner: Int, from discarder: Int, han: Int = 3, riichi: Bool = false, others: Set<Int> = []) -> WinRecord {
        var context = WinContext()
        context.riichi = riichi
        return WinRecord(winner: winner, discarder: discarder, hand: nil, context: context,
                         fans: [FanEntry(fan: .tanyao, count: 1, han: han)], flowerFan: 0, fu: 30, riichiPlayers: others)
    }

    // MARK: 双响

    func testDoubleRonPaysEachWinnerSeparately() throws {
        var g = game()
        try g.recordWin(ron(2, from: 1))
        try g.addSecondRon(ron(3, from: 1, han: 2))
        // 3 翻 30 符 3900，2 翻 30 符 2000，都由 1 号付
        XCTAssertEqual(g.records.last?.deltas, [0, -5900, 3900, 2000])
        XCTAssertEqual(g.records.count, 1, "双响算一局")
    }

    func testDoubleRonHonbaAndSticksGoToNearestWinner() throws {
        var g = game()
        try g.recordDraw(riichi: [0])          // 桌上留 1000，1 本场，0 号听牌连庄
        try g.recordWin(ron(3, from: 1, han: 2, riichi: true))
        try g.addSecondRon(ron(2, from: 1, others: [0]))
        guard case .doubleRon(let wins)? = g.records.last?.outcome else { return XCTFail("应该是双响") }
        XCTAssertEqual(wins.map(\.winner), [2, 3], "2 号在点炮者下家，排前面")
        // 2 号：3900 + 本场 300 + 供托 1000 + 0 号立直棒 1000 + 3 号立直棒 1000
        // 3 号：2000 - 自己的立直棒 1000
        XCTAssertEqual(g.records.last?.deltas, [-1000, -6200, 7200, 1000])
    }

    func testDoubleRonNearestWrapsPastNorth() throws {
        var g = game()
        try g.recordWin(ron(0, from: 3))
        try g.addSecondRon(ron(2, from: 3))
        guard case .doubleRon(let wins)? = g.records.last?.outcome else { return XCTFail("应该是双响") }
        XCTAssertEqual(wins.map(\.winner), [0, 2], "3 号的下家是 0 号")
    }

    func testDoubleRonDealerAmongWinnersKeepsDealer() throws {
        var g = game()
        try g.recordWin(ron(0, from: 2))
        try g.addSecondRon(ron(1, from: 2))
        XCTAssertEqual(g.currentHandIndex, 0)
        XCTAssertEqual(g.currentHonba, 1)
    }

    func testDoubleRonWithoutDealerRotatesAndClearsHonba() throws {
        var g = game()
        try g.recordDraw(tenpai: [0])
        try g.recordWin(ron(2, from: 1))
        try g.addSecondRon(ron(3, from: 1))
        XCTAssertEqual(g.currentHandIndex, 1)
        XCTAssertEqual(g.currentHonba, 0)
        XCTAssertEqual(g.currentPot, 0)
    }

    func testDoubleRonRejectsDifferentDiscarderOrSameWinner() throws {
        var g = game()
        try g.recordWin(ron(2, from: 1))
        XCTAssertThrowsError(try g.addSecondRon(ron(3, from: 0)))
        XCTAssertThrowsError(try g.addSecondRon(ron(2, from: 1)))
    }

    func testDoubleRonSurvivesEncodingAndEditingEarlierHands() throws {
        var g = game()
        let first = try g.recordDraw(tenpai: [0])
        try g.recordWin(ron(2, from: 1))
        try g.addSecondRon(ron(3, from: 1))
        let decoded = try JSONDecoder().decode(Game.self, from: JSONEncoder().encode(g))
        XCTAssertEqual(decoded.records.last?.outcome, g.records.last?.outcome)
        XCTAssertEqual(decoded.records.last?.deltas, g.records.last?.deltas)

        g.remove(first.id)
        XCTAssertEqual(g.records.first?.honba, 0)
        XCTAssertEqual(g.records.first?.deltas, [0, -7800, 3900, 3900], "前面删掉一局后本场棒要重算")
    }

    // MARK: 流局满贯

    func testNagashiNonDealerPaysAsManganTsumo() throws {
        var g = game()
        try g.recordNagashi(players: [2])
        XCTAssertEqual(g.records.last?.deltas, [-4000, -2000, 8000, -2000])
    }

    func testNagashiDealerPaysFourThousandAll() throws {
        var g = game()
        try g.recordNagashi(players: [0], tenpai: [0])
        XCTAssertEqual(g.records.last?.deltas, [12000, -4000, -4000, -4000])
        XCTAssertEqual(g.currentHandIndex, 0, "庄家听牌连庄")
        XCTAssertEqual(g.currentHonba, 1)
    }

    func testNagashiHasNoTenpaiPaymentAndKeepsRiichiSticks() throws {
        var g = game()
        try g.recordNagashi(players: [2], tenpai: [3], riichi: [3])
        XCTAssertEqual(g.records.last?.deltas, [-4000, -2000, 8000, -3000])
        XCTAssertEqual(g.currentPot, 1000)
        XCTAssertEqual(g.currentHandIndex, 1, "庄家没听牌就轮庄")
        XCTAssertEqual(g.currentHonba, 1)
    }

    func testTwoNagashiPlayersBothCollect() throws {
        var g = game()
        try g.recordNagashi(players: [1, 2])
        XCTAssertEqual(g.records.last?.deltas, [-8000, 6000, 6000, -4000])
    }

    func testNagashiNeedsAPlayer() {
        var g = game()
        XCTAssertThrowsError(try g.recordNagashi(players: []))
    }

    // MARK: 途中流局

    func testEachAbortiveDrawHasNoPaymentAndKeepsDealer() throws {
        for kind in AbortiveDraw.allCases where kind != .suuchaRiichi {
            var g = game()
            try g.recordAbortiveDraw(kind)
            XCTAssertEqual(g.records.last?.deltas, [0, 0, 0, 0], kind.rawValue)
            XCTAssertEqual(g.currentHandIndex, 0, kind.rawValue)
            XCTAssertEqual(g.currentHonba, 1, kind.rawValue)
        }
    }

    func testFourRiichiLeavesAllSticksOnTheTable() throws {
        var g = game()
        try g.recordAbortiveDraw(.suuchaRiichi)
        XCTAssertEqual(g.records.last?.deltas, [-1000, -1000, -1000, -1000])
        XCTAssertEqual(g.currentPot, 4000)
        XCTAssertEqual(g.currentHonba, 1)
        try g.recordWin(ron(1, from: 2, han: 1))
        XCTAssertEqual(g.records.last?.deltas, [0, 5300, -1300, 0], "1000 点 + 1 本场 300 + 供托 4000")
    }

    func testAbortiveDrawRoundTrips() throws {
        var g = game()
        try g.recordAbortiveDraw(.sanchahou, riichi: [2])
        let decoded = try JSONDecoder().decode(Game.self, from: JSONEncoder().encode(g))
        XCTAssertEqual(decoded.records.last?.outcome, .abortive(.sanchahou, riichi: [2]))
        XCTAssertEqual(decoded.currentPot, 1000)
    }

    // MARK: 击飞

    func testGameEndsWhenAPlayerGoesBelowZero() throws {
        var g = game()
        try g.recordWin(ron(2, from: 1, han: 8))    // 倍满 16000，1 号剩 9000
        XCTAssertFalse(g.isFinished)
        try g.recordWin(ron(2, from: 1, han: 6))    // 跳满 12000，1 号 -3000
        XCTAssertEqual(g.currentPoints[1], -3000)
        XCTAssertTrue(g.isFinished)
        XCTAssertThrowsError(try g.recordDraw())
    }

    func testExactlyZeroPointsKeepsPlaying() throws {
        var g = game { $0.startingPoints = 8000; $0.returnPoints = 8000 }
        try g.recordWin(ron(2, from: 1, han: 5))
        XCTAssertEqual(g.currentPoints[1], 0)
        XCTAssertFalse(g.isFinished)
    }

    func testTobiCanBeTurnedOff() throws {
        var g = game { $0.tobi = false; $0.startingPoints = 5000; $0.returnPoints = 5000 }
        try g.recordWin(ron(2, from: 1, han: 5))
        XCTAssertLessThan(g.currentPoints[1], 0)
        XCTAssertFalse(g.isFinished)
    }

    // MARK: 头名赏和顺位马

    func testOkaGivesTopTwentyThousand() throws {
        var g = game()
        try g.recordWin(ron(2, from: 1))
        g.end()
        // 净得失 3900 / -3900，每人再扣 5000，第一名加 20000
        XCTAssertEqual(g.scores, [-5000, -8900, 18900, -5000])
        XCTAssertEqual(g.scores.reduce(0, +), 0)
    }

    func testNoOkaBeforeTheGameEnds() throws {
        var g = game()
        try g.recordWin(ron(2, from: 1))
        XCTAssertEqual(g.scores, [0, -3900, 3900, 0])
    }

    func testOkaCanBeTurnedOff() throws {
        var g = game { $0.oka = false }
        try g.recordWin(ron(2, from: 1))
        g.end()
        XCTAssertEqual(g.scores, [0, -3900, 3900, 0])
    }

    func testOkaAndUmaTogetherStayZeroSum() throws {
        var g = game { $0.uma = 20 }
        try g.recordWin(ron(2, from: 1))
        try g.recordDraw(riichi: [3])
        g.end()
        XCTAssertEqual(g.scores.reduce(0, +), 0)
        // 3 号流局听牌得 3000 再扣立直棒 1000，2 号第一名拿供托 1000
        XCTAssertEqual(g.scores[2], 3900 - 1000 + 1000 - 5000 + 20000 + 20000)
    }

    func testOldSavesGetDefaultRules() throws {
        let rules = try JSONDecoder().decode(GameRules.self, from: Data("{}".utf8))
        XCTAssertTrue(rules.oka)
        XCTAssertTrue(rules.tobi)
        XCTAssertEqual(rules.startingPoints, 25000)
    }
}
