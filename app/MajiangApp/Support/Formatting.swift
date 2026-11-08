import Foundation
import MajiangKit

extension HandRecord {
    /// 和牌的那一局才有。
    var win: WinRecord? {
        outcome.wins.first
    }

    var isWin: Bool { win != nil }

    /// 账本里的一行标题：「莉莉荣和 · 阿强放铳 · 满贯 5 翻」「这局流局」。
    func title(in game: Game) -> String {
        let name = { (i: Int) in game.players[i].name }
        let sep = tr(" · ", "・", " · ")
        if let special = specialTitle(in: game) { return special }
        switch outcome {
        case .win(let win):
            var parts = [
                win.discarder.map {
                    tr("\(name(win.winner))荣和 · \(name($0))放铳",
                       "\(name(win.winner)) ロン（\(name($0))放銃）",
                       "\(name(win.winner)) Ron (\(name($0)))")
                } ?? tr("\(name(win.winner))自摸", "\(name(win.winner)) ツモ", "\(name(win.winner)) Tsumo")
            ]
            if let top = win.fans.first, top.points >= 2 { parts.append(top.fan.name) }
            let paid = game.rules.paidFan(win)
            if let limit = Payment.limitName(han: paid, fu: win.fu, kiriageMangan: game.rules.kiriageMangan) {
                parts.append(tr("\(limit) \(paid) 翻", "\(limit) \(paid)翻", "\(limit) \(paid) han"))
            } else {
                parts.append(tr("\(paid) 翻 \(win.fu) 符", "\(paid)翻\(win.fu)符", "\(paid) han \(win.fu) fu"))
            }
            return parts.joined(separator: sep)
        case .drawn(let tenpai, _):
            let valid = tenpai.filter { (0..<4).contains($0) }.sorted()
            if valid.isEmpty { return tr("这局流局", "流局（全員不聴）", "Draw (All Noten)") }
            if valid.count == 4 { return tr("流局 · 四家听牌", "流局・全員聴牌", "Draw · All Tenpai") }
            let names = valid.map(name).joined(separator: tr("、", "・", ", "))
            return tr("流局 · \(names)听牌", "流局・\(names) 聴牌", "Draw · \(names) Tenpai")
        case .falseWin(let offender):
            return tr("\(name(offender))错和", "\(name(offender)) チョンボ", "\(name(offender)) Chombo")
        case .manual(_, let note):
            return note.isEmpty
                ? tr("直接改分", "スコア直接修正", "Manual adjustment")
                : tr("直接改分 · \(note)", "直接修正・\(note)", "Manual · \(note)")
        default:
            return ""
        }
    }

    /// 标题下面一行：谁付了多少。
    func detail(in game: Game) -> String {
        if case .drawn(let tenpai, _) = outcome {
            let dealerStay = tenpai.contains(game.dealer(ofHand: handIndex))
            if deltas == [0, 0, 0, 0] {
                return dealerStay
                    ? tr("不计点 · 庄家连庄", "収支なし・親連荘", "No payment · Dealer repeats")
                    : tr("不计点", "収支なし", "No payment")
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
            let names = group.players.map { game.players[$0].name }.joined(separator: tr("、", "・", ", "))
            return group.players.count > 1
                ? tr("\(names)各 \(Theme.signed(group.amount))", "\(names) 各\(Theme.signed(group.amount))", "\(names) \(Theme.signed(group.amount)) each")
                : "\(names) \(Theme.signed(group.amount))"
        }
        .joined(separator: tr("，", "、", "; "))
    }

    /// 右边的数字：和牌的人赢了多少；和错的人赔了多少；流局有人听牌时显示听牌每家收入。
    var headline: Int? {
        switch outcome {
        case .win(let win):
            return deltas[win.winner]
        case .falseWin(let offender):
            return deltas[offender]
        case .doubleRon(let wins):
            return wins.first.map { deltas[$0.winner] }
        case .drawn, .nagashi, .abortive:
            let top = deltas.max() ?? 0
            return top > 0 ? top : nil
        case .manual:
            return nil
        }
    }
}

extension Game {
    /// 每家开局的点数。账本里存的是净得失，界面上按日麻的习惯加上这个数显示。
    static let startingPoints = 25_000

    /// 现在手上的点数（净得失是 `scores`）。
    func currentPoints(of player: Int) -> Int { Game.startingPoints + scores[player] }

    /// 牌桌顶上的大字：「东 3 局」。打完了是「终局」。
    var handLabelShort: String {
        if isFinished { return tr("终局", "終局", "Final") }
        let wind = prevalentWind(ofHand: displayHand).name
        let kyoku = displayHand % 4 + 1
        return tr("\(wind) \(kyoku) 局", "\(wind)\(kyoku)局", "\(wind) \(kyoku)")
    }

    /// 大字下面一行：「半庄 · 还剩 6 局」「东风战 · 打了 4 局」。
    var progressLine: String {
        let mode = rules.totalHands == 4 ? tr("东风战", "東風戦", "East only") : tr("半庄", "半荘", "Hanchan")
        let rest = isFinished
            ? tr("打了 \(playedHandsCount) 局", "全\(playedHandsCount)局", "\(playedHandsCount) hands")
            : tr("还剩 \(remainingHands) 局", "残り\(remainingHands)局", "\(remainingHands) left")
        return mode + tr(" · ", "・", " · ") + rest
    }

    /// 「¥76」「−¥12.5」。
    func moneyText(_ points: Int) -> String {
        let value = money(forPoints: points)
        let text = abs(value).formatted(.number.precision(.fractionLength(0...2)))
        return value < 0 ? "−¥\(text)" : "¥\(text)"
    }

    /// 现在打到的那一局（打完以后停在最后一局）。
    var displayHand: Int { min(currentHandIndex, rules.totalHands - 1) }

    /// 「东场 · 第 1 局」或「东场 · 第 1 局 · 1 本场 · 供托 1000」。
    var handLabel: String {
        let wind = prevalentWind(ofHand: displayHand).name
        let kyoku = displayHand % 4 + 1
        var text = tr("\(wind)场 · 第 \(kyoku) 局", "\(wind)\(kyoku)局", "\(wind) \(kyoku)")
        if !isFinished {
            if currentHonba > 0 { text += tr(" · \(currentHonba) 本场", "・\(currentHonba)本場", " · \(currentHonba) Honba") }
            if currentPot > 0 { text += tr(" · 供托 \(currentPot)", "・供託\(currentPot)", " · Pot \(currentPot)") }
        }
        return text
    }

    /// 方桌中间场风大字下面的副标题。
    var tableCenterSubtitle: String {
        let kyoku = displayHand % 4 + 1
        var text = tr("场 · 第 \(kyoku) 局", "\(kyoku)局", "Hand \(kyoku)")
        if !isFinished {
            if currentHonba > 0 { text += tr(" · \(currentHonba) 本场", "・\(currentHonba)本場", " · \(currentHonba)H") }
            if currentPot > 0 { text += tr(" · 供托 \(currentPot)", "・供託\(currentPot)", " · Pot \(currentPot)") }
        }
        return text
    }

    /// 某一局的场次说明：「东场第 1 局 · 1 本场」。
    func handTitle(for record: HandRecord) -> String {
        let wind = prevalentWind(ofHand: record.handIndex).name
        let kyoku = record.handIndex % 4 + 1
        var base = tr("\(wind)场第 \(kyoku) 局", "\(wind)\(kyoku)局", "\(wind) \(kyoku)")
        if record.honba > 0 { base += tr(" · \(record.honba) 本场", "・\(record.honba)本場", " · \(record.honba) Honba") }
        if record.pot > 0 { base += tr(" · 供托 \(record.pot)", "・供託\(record.pot)", " · Pot \(record.pot)") }
        return base
    }

    /// 规则一行：「立直日麻 · 半庄 · 1000 点 = 1 元」。
    var rulesSummary: String { rules.summary }

    /// 结果页和「这一局」底下的点数收付说明。
    func paymentExplanation(_ win: WinRecord, honba: Int = 0, pot: Int = 0, deltas: [Int]) -> String {
        let han = rules.paidFan(win)
        let base = Payment.basePoints(han: han, fu: win.fu, kiriageMangan: rules.kiriageMangan)
        let limit = Payment.limitName(han: han, fu: win.fu, kiriageMangan: rules.kiriageMangan)
        let summary = limit.map {
            tr("\($0)（\(han) 翻 \(win.fu) 符，基本点 \(base)）",
               "\($0)（\(han)翻\(win.fu)符・基本点\(base)）",
               "\($0) (\(han) han \(win.fu) fu, base \(base))")
        } ?? tr("\(han) 翻 \(win.fu) 符（基本点 \(base)）",
                "\(han)翻\(win.fu)符（基本点\(base)）",
                "\(han) han \(win.fu) fu (base \(base))")
        let isDealer = win.context.seatWind == .east
        let honbaText = honba > 0 ? tr("（含 \(honba) 本场 +\(honba * 300) 点）", "（\(honba)本場 +\(honba * 300)点含む）", " (incl. \(honba) honba +\(honba * 300))") : ""
        let tsumoHonbaText = honba > 0 ? tr("（每家含 \(honba) 本场 +\(honba * 100) 点）", "（各家\(honba)本場 +\(honba * 100)点含む）", " (incl. \(honba) honba +\(honba * 100) each)") : ""

        var lines: [String] = []
        if let discarder = win.discarder {
            let mult = isDealer
                ? tr("庄家和牌按 6 倍基本点", "親ロンは基本点×6", "dealer Ron 6× base")
                : tr("闲家和牌按 4 倍基本点", "子ロンは基本点×4", "non-dealer Ron 4× base")
            let handPay = Payment.ceil100(base * (isDealer ? 6 : 4)) + honba * 300
            lines.append(tr(
                "荣和：\(summary)，\(mult)进百位\(honbaText)，由放铳的\(players[discarder].name)付 \(handPay) 点。",
                "ロン和了：\(summary)、\(mult)（百点単位切り上げ）\(honbaText)。放銃した\(players[discarder].name)が \(handPay) 点を支払います。",
                "Ron: \(summary), \(mult) rounded up to 100\(honbaText). \(players[discarder].name) pays \(handPay) pts."
            ))
        } else if isDealer {
            let each = Payment.ceil100(base * 2) + honba * 100
            lines.append(tr(
                "庄家自摸：\(summary)，三家闲家各付 \(each) 点\(tsumoHonbaText)。",
                "親ツモ：\(summary)、子3人が各 \(each) 点を支払います\(tsumoHonbaText)。",
                "Dealer Tsumo: \(summary), all 3 non-dealers pay \(each) pts each\(tsumoHonbaText)."
            ))
        } else {
            let dealerPay = Payment.ceil100(base * 2) + honba * 100
            let childPay = Payment.ceil100(base) + honba * 100
            lines.append(tr(
                "闲家自摸：\(summary)，庄家付 \(dealerPay) 点、另外两家闲家各付 \(childPay) 点\(tsumoHonbaText)。",
                "子ツモ：\(summary)、親が \(dealerPay) 点・子2人が各 \(childPay) 点を支払います\(tsumoHonbaText)。",
                "Non-dealer Tsumo: \(summary), dealer pays \(dealerPay) pts and other 2 non-dealers pay \(childPay) pts each\(tsumoHonbaText)."
            ))
        }
        let othersRiichi = win.riichiPlayers.subtracting([win.winner]).filter { (0..<4).contains($0) }.sorted()
        if !othersRiichi.isEmpty || pot > 0 {
            let totalPot = othersRiichi.count * 1000 + pot
            lines.append(tr(
                "立直供托棒：共收 +\(totalPot) 点供托棒。",
                "供託リーチ棒：計 +\(totalPot) 点を獲得。",
                "Riichi sticks: collects +\(totalPot) pts from the pot."
            ))
        }
        lines.append(tr(
            "按 1000 点 = \(rules.yuanPerPoint.yuanText) 元，\(players[win.winner].name)这局赢 \(moneyText(deltas[win.winner]))。",
            "1000点＝\(rules.yuanPerPoint.yuanText)換算で、\(players[win.winner].name)は \(moneyText(deltas[win.winner])) のプラスです。",
            "At 1000 pts = \(rules.yuanPerPoint.yuanText), \(players[win.winner].name) wins \(moneyText(deltas[win.winner]))."
        ))
        return lines.joined(separator: "\n")
    }

    /// 「这一局」牌下面的一句话：「自己摸到 7饼，和了。」「阿强打出 6饼，莉莉和了。」
    func winSentence(_ win: WinRecord) -> String? {
        guard let tile = win.hand?.winningTile.displayName else { return nil }
        let winner = players[win.winner].name
        guard let discarder = win.discarder.map({ players[$0].name }) else {
            return win.context.kongInvolved
                ? tr("开杠摸岭上牌 \(tile)，自摸和了。", "嶺上牌の \(tile) をツモ和了。", "Self-drawn \(tile) off the dead wall after a kan.")
                : tr("自己摸到 \(tile)，自摸和了。", "\(tile) をツモ和了。", "Self-drawn win on \(tile).")
        }
        return win.context.kongInvolved
            ? tr("\(discarder)加杠的 \(tile) 被抢，\(winner)荣和。", "\(discarder)が加槓した \(tile) を槍槓ロン。", "\(winner) robbed \(discarder)'s added kan of \(tile).")
            : tr("\(discarder)打出 \(tile)，\(winner)荣和。", "\(discarder)の打 \(tile) で\(winner)がロン和了。", "\(winner) won by Ron off \(discarder)'s \(tile).")
    }
}

extension GameRules {
    /// 跟标准半庄不一样的地方，一项一个短语。
    var houseRuleParts: [String] {
        let standard = GameRules.standard
        var parts: [String] = []
        if totalHands != standard.totalHands {
            parts.append(totalHands == 4 ? tr("东风战", "東風戦", "East Only") : tr("\(totalHands) 局", "\(totalHands)局", "\(totalHands) Hands"))
        }
        if minimumFan != standard.minimumFan {
            parts.append(tr("\(minimumFan) 翻起和", "\(minimumFan)翻縛り", "\(minimumFan)-Han Min"))
        }
        if kiriageMangan {
            parts.append(tr("切上满贯", "切り上げ満貫", "Kiriage Mangan"))
        }
        if fanCap > 0 {
            parts.append(tr("封顶 \(fanCap) 翻", "\(fanCap)翻打ち止め", "\(fanCap)-Han Cap"))
        }
        if !allowKuitan {
            parts.append(tr("无喰断", "喰いタンなし", "Closed Tanyao"))
        }
        if uma > 0 {
            let second = uma == 10 ? 5 : 10
            parts.append(tr("顺位马 \(second)-\(uma)", "ウマ\(second)-\(uma)", "Uma \(second)-\(uma)"))
        }
        if !includeDora {
            parts.append(tr("不计宝牌", "ドラなし", "No Dora"))
        }
        if falseWinPenalty != standard.falseWinPenalty {
            parts.append(tr("错和赔 \(falseWinPenalty)", "チョンボ各\(falseWinPenalty)点", "Chombo \(falseWinPenalty)"))
        }
        if swapSeatsEachRound {
            parts.append(tr("每圈换座", "場風ごと席替え", "Swap Seats"))
        }
        return parts
    }

    /// 分享图、结算页：「立直日麻 · 半庄 · 1000 点 = 1 元」。
    var summary: String {
        let house = houseRuleParts
        let baseName = tr("立直日麻", "リーチ麻雀", "Riichi Mahjong")
        let defaultRound = tr("半庄", "半荘戦", "Hanchan")
        let rate = tr("1000 点 = \(yuanPerPoint.yuanText) 元", "1000点＝\(yuanPerPoint.yuanText)", "1000 pts = \(yuanPerPoint.yuanText)")
        return ([baseName] + (house.isEmpty ? [defaultRound] : house) + [rate])
            .joined(separator: " · ")
    }

    /// 开局页那一行：「标准半庄 · 千点 1 元」「东风战 · 千点 1 元」。
    var shortSummary: String {
        let name = scoresLike(.standard)
            ? tr("标准半庄", "標準半荘", "Hanchan (8 Hands)")
            : scoresLike(.beginner)
                ? tr("东风战", "東風戦", "East Only (4 Hands)")
                : houseRuleParts.joined(separator: " · ")
        let rate = tr("千点 \(yuanPerPoint.yuanText) 元", "1000点＝\(yuanPerPoint.yuanText)", "1000 pts = \(yuanPerPoint.yuanText)")
        return "\(name) · \(rate)"
    }

    /// 牌桌顶上那一行，只有桌规跟标准半庄不一样时才有。
    var houseRuleBadge: String? {
        let house = houseRuleParts
        guard !house.isEmpty else { return nil }
        let prefix = tr("桌规", "ルール", "Rules")
        let rate = tr("千点 \(yuanPerPoint.yuanText) 元", "1000点＝\(yuanPerPoint.yuanText)", "1000 pts = \(yuanPerPoint.yuanText)")
        return ([prefix] + house + [rate]).joined(separator: " · ")
    }
}

extension Date {
    /// 「10月25日 周六」。
    var dayLabel: String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = AppLang.current.locale
        let c = calendar.dateComponents([.month, .day, .weekday], from: self)
        let weekday = calendar.shortWeekdaySymbols[c.weekday! - 1]
        switch AppLang.current {
        case .zh: return "\(c.month!)月\(c.day!)日 \(weekday)"
        case .ja: return "\(c.month!)月\(c.day!)日(\(weekday))"
        case .en: return formatted(.dateTime.month(.abbreviated).day().weekday(.abbreviated).locale(Locale(identifier: "en_US")))
        }
    }
}
