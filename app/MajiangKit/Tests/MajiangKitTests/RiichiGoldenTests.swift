import XCTest
@testable import MajiangKit

/// Golden cases in `Fixtures/riichi-golden-cases.json`. Expected values come from published rules, not this engine.
final class RiichiGoldenTests: XCTestCase {
    struct Fixture: Decodable {
        var hands: [GoldenHand]
        var pointTable: Table
        var limits: Table
    }

    struct GoldenHand: Decodable {
        var id: String
        var melds: [String]?
        var tiles: String
        var win: String
        var ctx: Ctx?
        var yaku: [String]?
        var han: Int?
        var dora: Int?
        var fu: Int?
        var ron: Int?
        var tsumoNon: Int?
        var tsumoDealer: Int?
        var tsumoAll: Int?
        var notWin: Bool?
    }

    struct Ctx: Decodable {
        var seat: String?
        var round: String?
        var tsumo: Bool?
        var riichi: Bool?
        var doubleRiichi: Bool?
        var ippatsu: Bool?
        var wall: Bool?
        var kong: Bool?
        var firstTurn: Bool?
        var dora: Int?
        var kuitan: Bool?
        var kiriage: Bool?
        var honba: Int?
        var indicators: [String]?
        var ura: [String]?
    }

    struct Table: Decodable {
        var rows: [Row]
    }

    struct Row: Decodable {
        var han: Int
        var fu: Int
        var kiriage: Bool?
        var dealerRon: Int?
        var dealerTsumo: Int?
        var ron: Int?
        var tsumoNon: Int?
        var tsumoDealer: Int?
    }

    private func loadFixture() throws -> Fixture {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "riichi-golden-cases", withExtension: "json", subdirectory: "Fixtures"))
        return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
    }

    private static let winds: [String: Wind] = ["east": .east, "south": .south, "west": .west, "north": .north]

    private func meld(_ text: String) throws -> Meld {
        let parts = text.split(separator: ":").map(String.init)
        let tiles = Tile.parseList(parts[1])
        let first = try XCTUnwrap(tiles.first, text)
        switch parts[0] {
        case "chi": return try XCTUnwrap(Meld.from(tiles: tiles), text)
        case "pon": return tiles.count == 3 ? try XCTUnwrap(Meld.from(tiles: tiles), text) : .pung(first)
        case "kan": return try XCTUnwrap(Meld.from(tiles: tiles), text)
        case "ankan": return try XCTUnwrap(Meld.from(tiles: tiles, concealedKong: true), text)
        default: throw XCTSkip("unknown meld \(text)")
        }
    }

    func testGoldenHands() throws {
        let fixture = try loadFixture()
        XCTAssertEqual(Set(fixture.hands.map(\.id)).count, fixture.hands.count, "duplicate case id")
        for golden in fixture.hands {
            try check(golden)
        }
    }

    private func check(_ golden: GoldenHand) throws {
        let id = golden.id
        let ctx = golden.ctx ?? Ctx()
        let seat = try XCTUnwrap(Self.winds[ctx.seat ?? "south"], id)
        let round = try XCTUnwrap(Self.winds[ctx.round ?? "east"], id)
        let selfDrawn = ctx.tsumo ?? false
        let context = WinContext(
            prevalentWind: round,
            seatWind: seat,
            selfDrawn: selfDrawn,
            riichi: ctx.riichi ?? false,
            doubleRiichi: ctx.doubleRiichi ?? false,
            ippatsu: ctx.ippatsu ?? false,
            lastTileOfWall: ctx.wall ?? false,
            firstTurnWin: ctx.firstTurn ?? false,
            kongInvolved: ctx.kong ?? false,
            doraCount: ctx.dora ?? 0,
            allowKuitan: ctx.kuitan ?? true,
            doraIndicators: (ctx.indicators ?? []).flatMap(Tile.parseList),
            uraIndicators: (ctx.ura ?? []).flatMap(Tile.parseList)
        )
        let winTile = try XCTUnwrap(Tile(notation: golden.win), id)
        let hand = Hand(melds: try (golden.melds ?? []).map(meld), concealed: Tile.parseList(golden.tiles), winningTile: winTile)
        XCTAssertTrue(hand.hasValidTileCount, "\(id): fixture has \(hand.concealed.count) concealed tiles")
        XCTAssertTrue(hand.concealed.contains(winTile), "\(id): winning tile is not in the hand")

        let scored = FanCalculator.score(hand, context: context)
        if golden.notWin == true {
            XCTAssertEqual(scored.failure, .notAWin, id)
            return
        }
        guard case .success(let result) = scored else {
            XCTFail("\(id): expected a win, got \(scored)")
            return
        }

        if let yaku = golden.yaku {
            let actual = Set(result.fans.map { String(describing: $0.fan) })
            XCTAssertEqual(actual, Set(yaku), "\(id): yaku")
        }
        if let han = golden.han { XCTAssertEqual(result.totalFan, han, "\(id): han") }
        if let dora = golden.dora { XCTAssertEqual(result.doraFan, dora, "\(id): dora") }
        if let fu = golden.fu { XCTAssertEqual(result.fu, fu, "\(id): fu") }

        // Payments go through the same path as the ledger: WinRecord, then rules.paidFan, then winDeltas.
        var rules = GameRules()
        rules.kiriageMangan = ctx.kiriage ?? false
        let dealer = 0
        let winner = seat.rawValue
        let discarder = selfDrawn ? nil : (winner + 1) % 4
        let record = WinRecord(winner: winner, discarder: discarder, hand: hand, context: context, result: result)
        let deltas = Payment.winDeltas(winner: winner, discarder: discarder, dealer: dealer,
                                       totalFan: rules.paidFan(record), fu: record.fu,
                                       honba: ctx.honba ?? 0, rules: rules)
        var expected = [0, 0, 0, 0]
        if let ron = golden.ron, let discarder {
            expected[discarder] = -ron
        } else if let all = golden.tsumoAll {
            for p in 0..<4 where p != winner { expected[p] = -all }
        } else if let non = golden.tsumoNon, let dealerPays = golden.tsumoDealer {
            for p in 0..<4 where p != winner { expected[p] = p == dealer ? -dealerPays : -non }
        } else {
            return
        }
        expected[winner] = -expected.reduce(0, +)
        XCTAssertEqual(deltas, expected, "\(id): payments")
    }

    func testPointTable() throws {
        for row in try loadFixture().pointTable.rows {
            var rules = GameRules()
            rules.kiriageMangan = true
            check(row, rules: rules)
        }
    }

    func testLimitsAndKiriage() throws {
        for row in try loadFixture().limits.rows {
            var rules = GameRules()
            rules.kiriageMangan = row.kiriage ?? false
            check(row, rules: rules)
        }
    }

    private func check(_ row: Row, rules: GameRules) {
        let name = "\(row.han) han \(row.fu) fu kiriage=\(rules.kiriageMangan)"
        func deltas(winner: Int, discarder: Int?) -> [Int] {
            Payment.winDeltas(winner: winner, discarder: discarder, dealer: 0, totalFan: row.han, fu: row.fu, rules: rules)
        }
        if let pay = row.dealerRon {
            XCTAssertEqual(deltas(winner: 0, discarder: 1), [pay, -pay, 0, 0], "\(name) dealer ron")
        }
        if let each = row.dealerTsumo {
            XCTAssertEqual(deltas(winner: 0, discarder: nil), [3 * each, -each, -each, -each], "\(name) dealer tsumo")
        }
        if let pay = row.ron {
            XCTAssertEqual(deltas(winner: 1, discarder: 2), [0, pay, -pay, 0], "\(name) non-dealer ron")
        }
        if let non = row.tsumoNon, let dealerPays = row.tsumoDealer {
            XCTAssertEqual(deltas(winner: 1, discarder: nil), [-dealerPays, dealerPays + 2 * non, -non, -non], "\(name) non-dealer tsumo")
        }
    }
}
