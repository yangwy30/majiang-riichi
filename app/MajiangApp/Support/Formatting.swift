import Foundation
import MajiangKit

extension HandRecord {
    /// 和牌的那一局才有。
    var win: WinRecord? {
        if case .win(let win) = outcome { return win }
        return nil
    }

    var isWin: Bool { win != nil }

    /// 账本里的一行标题：「莉莉荣和 · 阿强点炮 · 满贯 5 翻」「这局流局」。
    func title(in game: Game) -> String {
        let name = { (i: Int) in game.players[i].name }
        switch outcome {
        case .win(let win):
            var parts = [win.discarder.map { "\(name(win.winner))和 · \(name($0))点炮" } ?? "\(name(win.winner))自摸"]
            if let top = win.fans.first, top.points >= 2 { parts.append(top.fan.name) }
            let paid = game.rules.paidFan(win)
            if let limit = Payment.limitName(han: paid, fu: win.fu, kiriageMangan: game.rules.kiriageMangan) {
                parts.append("\(limit) \(paid) 翻")
            } else {
                parts.append("\(paid) 翻 \(win.fu) 符")
            }
            return parts.joined(separator: " · ")
        case .drawn(let tenpai):
            let valid = tenpai.filter { (0..<4).contains($0) }.sorted()
            if valid.isEmpty { return "这局流局" }
            if valid.count == 4 { return "流局 · 四家听牌" }
            let names = valid.map(name).joined(separator: "、")
            return "流局 · \(names)听牌"
        case .falseWin(let offender):
            return "\(name(offender))错和"
        case .manual(_, let note):
            return note.isEmpty ? "直接改分" : "直接改分 · \(note)"
        }
    }

    /// 标题下面一行：谁付了多少。
    func detail(in game: Game) -> String {
        if case .drawn(let tenpai) = outcome {
            let dealerStay = tenpai.contains(game.dealer(ofHand: handIndex))
            if deltas == [0, 0, 0, 0] {
                return dealerStay ? "不计点 · 庄家连庄" : "不计点"
            }
        }
        let losers = deltas.indices.filter { deltas[$0] < 0 }
        var groups: [(amount: Int, players: [Int])] = []
        for i in losers {
            if let g = groups.firstIndex(where: { $0.amount == deltas[i] }) {
                groups[g].players.append(i)
            } else {
                groups.append((deltas[i], [i]))
            }
        }
        groups.sort { $0.amount < $1.amount }
        return groups.map { group in
            let names = group.players.map { game.players[$0].name }.joined(separator: "、")
            return group.players.count > 1 ? "\(names)各 \(Theme.signed(group.amount))" : "\(names) \(Theme.signed(group.amount))"
        }
        .joined(separator: "，")
    }

    /// 右边的数字：和牌的人赢了多少；和错的人赔了多少；流局有人听牌时显示听牌每家收入。
    var headline: Int? {
        switch outcome {
        case .win(let win):
            return deltas[win.winner]
        case .falseWin(let offender):
            return deltas[offender]
        case .drawn:
            let top = deltas.max() ?? 0
            return top > 0 ? top : nil
        case .manual:
            return nil
        }
    }
}

extension Game {
    /// 「¥76」「−¥12.5」。
    func moneyText(_ points: Int) -> String {
        let value = money(forPoints: points)
        let text = abs(value).formatted(.number.precision(.fractionLength(0...2)))
        return value < 0 ? "−¥\(text)" : "¥\(text)"
    }

    /// 现在打到的那一局（打完以后停在最后一局）。
    var displayHand: Int { min(currentHandIndex, rules.totalHands - 1) }

    /// 「东场 · 第 1 局」或「东场 · 第 1 局 · 1 本场」。
    var handLabel: String {
        let base = "\(prevalentWind(ofHand: displayHand).name)场 · 第 \(displayHand % 4 + 1) 局"
        return currentHonba > 0 && !isFinished ? "\(base) · \(currentHonba) 本场" : base
    }

    /// 方桌中间场风大字下面的副标题。
    var tableCenterSubtitle: String {
        let base = "场 · 第 \(displayHand % 4 + 1) 局"
        return currentHonba > 0 && !isFinished ? "\(base) · \(currentHonba) 本场" : base
    }

    /// 某一局的场次说明：「东场第 1 局 · 1 本场」。
    func handTitle(for record: HandRecord) -> String {
        let base = "\(prevalentWind(ofHand: record.handIndex).name)场第 \(record.handIndex % 4 + 1) 局"
        return record.honba > 0 ? "\(base) · \(record.honba) 本场" : base
    }

    /// 规则一行：「立直日麻 · 半庄 · 1000 点 = 1 元」。
    var rulesSummary: String { rules.summary }

    /// 结果页和「这一局」底下的点数收付说明。
    func paymentExplanation(_ win: WinRecord, honba: Int = 0, deltas: [Int]) -> String {
        let han = rules.paidFan(win)
        let base = Payment.basePoints(han: han, fu: win.fu, kiriageMangan: rules.kiriageMangan)
        let limit = Payment.limitName(han: han, fu: win.fu, kiriageMangan: rules.kiriageMangan)
        let summary = limit.map { "\($0)（\(han) 翻 \(win.fu) 符，基本点 \(base)）" } ?? "\(han) 翻 \(win.fu) 符（基本点 \(base)）"
        let isDealer = win.context.seatWind == .east
        let honbaText = honba > 0 ? "（含 \(honba) 本场 +\(honba * 300) 点）" : ""
        let tsumoHonbaText = honba > 0 ? "（每家含 \(honba) 本场 +\(honba * 100) 点）" : ""

        var lines: [String] = []
        if let discarder = win.discarder {
            let mult = isDealer ? "庄家和牌按 6 倍基本点" : "闲家和牌按 4 倍基本点"
            let handPay = Payment.ceil100(base * (isDealer ? 6 : 4)) + honba * 300
            lines.append("荣和：\(summary)，\(mult)进百位\(honbaText)，由点炮的\(players[discarder].name)付 \(handPay) 点。")
        } else if isDealer {
            let each = Payment.ceil100(base * 2) + honba * 100
            lines.append("庄家自摸：\(summary)，三家闲家各付 \(each) 点\(tsumoHonbaText)。")
        } else {
            let dealerPay = Payment.ceil100(base * 2) + honba * 100
            let childPay = Payment.ceil100(base) + honba * 100
            lines.append("闲家自摸：\(summary)，庄家付 \(dealerPay) 点、另外两家闲家各付 \(childPay) 点\(tsumoHonbaText)。")
        }
        let othersRiichi = win.riichiPlayers.subtracting([win.winner]).filter { (0..<4).contains($0) }.sorted()
        if !othersRiichi.isEmpty {
            let names = othersRiichi.map { players[$0].name }.joined(separator: "、")
            lines.append("立直供托棒：收取\(names)的立直棒各 1000 点（共 +\(othersRiichi.count * 1000) 点）。")
        }
        lines.append("按 1000 点 = \(rules.yuanPerPoint.yuanText) 元，\(players[win.winner].name)这局赢 \(moneyText(deltas[win.winner]))。")
        return lines.joined(separator: "\n")
    }

    /// 「这一局」牌下面的一句话：「自己摸到 7饼，和了。」「阿强打出 6饼，莉莉和了。」
    func winSentence(_ win: WinRecord) -> String? {
        guard let tile = win.hand?.winningTile.displayName else { return nil }
        let winner = players[win.winner].name
        guard let discarder = win.discarder.map({ players[$0].name }) else {
            return win.context.kongInvolved ? "开杠摸岭上牌 \(tile)，自摸和了。" : "自己摸到 \(tile)，自摸和了。"
        }
        return win.context.kongInvolved ? "\(discarder)加杠的 \(tile) 被抢，\(winner)荣和。" : "\(discarder)打出 \(tile)，\(winner)荣和。"
    }
}

extension GameRules {
    /// 跟标准半庄不一样的地方，一项一个短语。
    var houseRuleParts: [String] {
        let standard = GameRules.standard
        var parts: [String] = []
        if totalHands != standard.totalHands {
            parts.append(totalHands == 4 ? "东风战" : "\(totalHands) 局")
        }
        if minimumFan != standard.minimumFan {
            parts.append("\(minimumFan) 翻起和")
        }
        if kiriageMangan {
            parts.append("切上满贯")
        }
        if fanCap > 0 {
            parts.append("封顶 \(fanCap) 翻")
        }
        if !includeFlowers {
            parts.append("不计宝牌")
        }
        if falseWinPenalty != standard.falseWinPenalty {
            parts.append("错和赔 \(falseWinPenalty)")
        }
        if swapSeatsEachRound {
            parts.append("每圈换座")
        }
        return parts
    }

    /// 分享图、结算页：「立直日麻 · 半庄 · 1000 点 = 1 元」。
    var summary: String {
        let house = houseRuleParts
        return (["立直日麻"] + (house.isEmpty ? ["半庄"] : house) + ["1000 点 = \(yuanPerPoint.yuanText) 元"])
            .joined(separator: " · ")
    }

    /// 开局页那一行：「标准半庄 · 千点 1 元」「东风战 · 千点 1 元」。
    var shortSummary: String {
        let name = scoresLike(.standard) ? "标准半庄" : scoresLike(.beginner) ? "东风战" : houseRuleParts.joined(separator: " · ")
        return "\(name) · 千点 \(yuanPerPoint.yuanText) 元"
    }

    /// 牌桌顶上那一行，只有桌规跟标准半庄不一样时才有。
    var houseRuleBadge: String? {
        let house = houseRuleParts
        guard !house.isEmpty else { return nil }
        return (["桌规"] + house + ["千点 \(yuanPerPoint.yuanText) 元"]).joined(separator: " · ")
    }
}

extension Date {
    /// 「10月25日 周六」。
    var dayLabel: String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        let c = calendar.dateComponents([.month, .day, .weekday], from: self)
        return "\(c.month!)月\(c.day!)日 \(calendar.shortWeekdaySymbols[c.weekday! - 1])"
    }
}
