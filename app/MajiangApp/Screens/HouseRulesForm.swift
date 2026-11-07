import SwiftUI
import MajiangKit

/// 桌规表单：一行一项，左边名字和一句白话，右边大数字。跟标准半庄一样的值是灰色细体，改过的是墨色。
struct HouseRulesForm: View {
    @Binding var rules: GameRules
    /// 已经打了几局：中途改规则时，总局数不能少于这个。
    var playedHands = 0
    /// 截图用：一打开就点开这一项。
    var opening: RuleItem?

    @State private var picking: RuleItem?
    @State private var showMore = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PresetTabs(rules: $rules)

            VStack(spacing: 0) {
                ForEach(RuleItem.main) { item in
                    RuleRow(item: item, rules: rules, large: true) { picking = item }
                }
            }
            .padding(.top, 4)

            Text(example)
                .font(.system(size: 14))
                .foregroundStyle(Theme.gray)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)

            Button {
                withAnimation(.easeOut(duration: 0.2)) { showMore.toggle() }
            } label: {
                HStack {
                    Text(moreLabel)
                    Spacer()
                    Text(showMore ? "收起" : "›")
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.text(size: 14))
            .padding(.top, 14)

            if showMore {
                VStack(spacing: 0) {
                    Hairline()
                    ForEach(RuleItem.more) { item in
                        RuleRow(item: item, rules: rules, large: false) { picking = item }
                    }
                }
            }
        }
        .sheet(item: $picking) { item in
            RulePicker(item: item, rules: $rules, playedHands: playedHands)
        }
        .onAppear {
            showMore = RuleItem.more.contains { !$0.isStandard(rules) }
            if let opening { picking = opening }
        }
    }

    private var moreLabel: String {
        let changed = RuleItem.more.filter { !$0.isStandard(rules) }.count
        return changed > 0
            ? tr("更多桌规 · 改过 \(changed) 项", "詳細ルール・\(changed)項目変更", "More Rules · \(changed) changed")
            : tr("更多桌规", "詳細ルール", "More Rules")
    }

    /// 随改随算的示例句。
    private var example: String {
        let han = rules.cappedFan(5)
        let deltas = Payment.winDeltas(winner: 1, discarder: 0, dealer: 0, totalFan: han, fu: 30, rules: rules)
        let points = deltas[1]
        let money = ((Double(points) / 1000.0) * rules.yuanPerPoint).formatted(.number.precision(.fractionLength(0...2)))
        return tr("比如闲家满贯（5 翻）：赢 \(points) 点，折合 \(money) 元。",
                  "例：子の満貫（5翻）＝ +\(points)点（\(money)相当）。",
                  "Example: Non-dealer Mangan (5 han) = +\(points) pts (¥\(money)).")
    }
}

// MARK: - 预设

/// 「标准半庄」「东风战」，改过就多出一个「自己定」。换预设不动千点汇率。
private struct PresetTabs: View {
    @Binding var rules: GameRules

    private var current: Int {
        rules.scoresLike(.standard) ? 0 : rules.scoresLike(.beginner) ? 1 : 2
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 22) {
                tab("标准半庄", index: 0, preset: .standard)
                tab("东风战", index: 1, preset: .beginner)
                if current == 2 { tab("自己定", index: 2, preset: nil) }
                Spacer()
            }
            Hairline()
        }
        .animation(.easeOut(duration: 0.15), value: current)
    }

    private func tab(_ label: String, index: Int, preset: GameRules?) -> some View {
        let on = current == index
        return Button {
            guard var preset else { return }
            preset.yuanPerPoint = rules.yuanPerPoint
            rules = preset
        } label: {
            Text(LocalizedStringKey(label))
                .font(.system(size: 15, weight: on ? .medium : .regular))
                .foregroundStyle(on ? Theme.ink : Theme.gray)
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(on ? Theme.ink : .clear).frame(height: 2)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

// MARK: - 一行

private struct RuleRow: View {
    var item: RuleItem
    var rules: GameRules
    var large: Bool
    var action: () -> Void

    var body: some View {
        let value = item.value(rules)
        let standard = item.isStandard(rules)
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title).font(.system(size: 16))
                        if large {
                            Text(item.hint)
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.gray)
                        }
                    }
                    Spacer(minLength: 8)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(value.text)
                            .font(large ? Theme.score(value.isNumber ? 28 : 18, weight: standard ? .regular : .semibold)
                                  : .system(size: 16, weight: standard ? .regular : .medium))
                        if !value.unit.isEmpty {
                            Text(value.unit).font(.system(size: 14))
                        }
                    }
                    .foregroundStyle(standard ? Theme.gray : Theme.ink)
                }
                .frame(minHeight: large ? 84 : 56)
                Hairline()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("点一下改")
    }
}

// MARK: - 选项

private struct RulePicker: View {
    @Environment(\.dismiss) private var dismiss
    var item: RuleItem
    @Binding var rules: GameRules
    var playedHands: Int
    @State private var customYuan = ""

    var body: some View {
        let options = item.options(playedHands: playedHands, current: rules)
        VStack(alignment: .leading, spacing: 0) {
            Text(item.title)
                .font(.system(size: 17, weight: .semibold))
                .padding(.top, 30)
            Text(item.note)
                .font(.system(size: 14))
                .foregroundStyle(Theme.gray)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .padding(.bottom, 10)

            ForEach(options) { option in
                let selected = option.isSelected(rules)
                Button {
                    option.apply(&rules)
                    dismiss()
                } label: {
                    HStack(spacing: 10) {
                        Text(option.label)
                            .font(.system(size: 17, weight: selected ? .semibold : .regular))
                        Spacer()
                        if let tag = option.tag {
                            Text(tag).font(.system(size: 14)).foregroundStyle(Theme.gray)
                        }
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                            .opacity(selected ? 1 : 0)
                    }
                    .frame(height: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!option.enabled)
                .opacity(option.enabled ? 1 : 0.35)
                .accessibilityAddTraits(selected ? .isSelected : [])
                Hairline(color: Theme.lineSoft)
            }

            if item == .rate {
                HStack {
                    Text("其他").font(.system(size: 17))
                    Spacer()
                    TextField("填一个数", text: $customYuan)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                    Text("元").foregroundStyle(Theme.gray)
                }
                .frame(height: 52)
            }
        }
        .padding(.horizontal, 24)
        .frame(maxHeight: .infinity, alignment: .top)
        .foregroundStyle(Theme.ink)
        .presentationDetents([.height(height(options.count))])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(16)
        .presentationBackground(Theme.card)
        .onChange(of: customYuan) { _, text in
            if let value = Double(text.replacingOccurrences(of: ",", with: ".")), value > 0 {
                rules.yuanPerPoint = value
            }
        }
    }

    private func height(_ count: Int) -> CGFloat {
        CGFloat(110 + (count + (item == .rate ? 1 : 0)) * 53)
    }
}

// MARK: - 规则项

enum RuleItem: String, Identifiable, CaseIterable {
    case rate, rounds, minimum, flowers, base
    case uma, kuitan, cap, penalty, swap

    var id: String { rawValue }

    static let main: [RuleItem] = [.rate, .rounds, .minimum, .flowers, .base]
    static let more: [RuleItem] = [.uma, .kuitan, .cap, .penalty, .swap]

    var title: String {
        switch self {
        case .rate: return tr("1000 点算", "1000点レート", "Per 1,000 Pts")
        case .rounds: return tr("局制", "対局形式", "Game Length")
        case .minimum: return tr("起和", "翻縛り", "Min Yaku Han")
        case .flowers: return tr("宝牌", "ドラ", "Dora")
        case .base: return tr("切上满贯", "切り上げ満貫", "Kiriage Mangan")
        case .uma: return tr("顺位马（ウマ）", "順位戦ウマ", "Placement Uma")
        case .kuitan: return tr("副露断幺九（喰断）", "喰いタン", "Open Tanyao (Kuitan)")
        case .cap: return tr("封顶", "翻数上限", "Han Cap")
        case .penalty: return tr("错和罚符", "チョンボ罰符", "Chombo Penalty")
        case .swap: return tr("每圈换座", "場風ごと席替え", "Swap Seats")
        }
    }

    var hint: String {
        switch self {
        case .rate: return tr("结算时每 1000 点折合多少元", "精算時の1000点あたりの換算額", "Settlement value per 1,000 points")
        case .rounds: return tr("半庄 8 局，东风战 4 局", "半荘8局・東風4局", "Hanchan (8 hands) or East Only (4 hands)")
        case .minimum: return tr("至少几翻役才能和（宝牌不算）", "和了に必要な役の翻数（ドラ除く）", "Minimum yaku han required to win (excl. Dora)")
        case .flowers: return tr("表宝、赤宝、里宝每张 1 翻", "表ドラ・赤ドラ・裏ドラ各1翻", "Dora, Red 5 & Ura-dora add +1 han each")
        case .base: return tr("30 符 4 翻、60 符 3 翻按满贯算", "30符4翻・60符3翻を満貫とする", "Round 30 fu 4 han & 60 fu 3 han up to Mangan")
        case .uma, .kuitan, .cap, .penalty, .swap: return ""
        }
    }

    var note: String {
        switch self {
        case .rate: return tr("每桌自己定，换预设不会动这一项。比如千点 1 元时，满贯 8000 点就是 8 元。",
                              "プリセットを変えてもこの設定は維持されます。1000点＝1の場合、満貫8000点は8になります。",
                              "Kept when switching presets. At 1 per 1,000 pts, a Mangan (8,000 pts) is 8.")
        case .rounds: return tr("标准半庄打东场 4 局 + 南场 4 局共 8 局；时间紧可以打东风战 4 局。",
                                "標準の半荘戦は東場4局＋南場4局の計8局。短時間なら東風戦4局も選べます。",
                                "Standard Hanchan plays East 1–4 + South 1–4 (8 hands). Choose East Only for a quick 4-hand game.")
        case .minimum: return tr("立直麻将标准为 1 翻起和（宝牌不算役）。少数桌规要求 2 翻起和。",
                                 "リーチ麻雀の標準は1翻縛り（ドラは役に含まない）です。",
                                 "Standard Riichi Mahjong requires 1 han of yaku (Dora excluded).")
        case .flowers: return tr("计入宝牌时，表宝牌、赤宝牌、里宝牌每张加 1 翻，但不计入 1 翻起和条件。",
                                 "表ドラ・赤ドラ・裏ドラが各1翻加算されます（1翻縛りの役には含まれません）。",
                                 "Dora, Red 5, and Ura-dora add +1 han each, but do not count toward the 1-han yaku minimum.")
        case .base: return tr("标准规则下 30 符 4 翻和 60 符 3 翻是 7700 / 11600 点；开启切上满贯后直接按满贯 8000 / 12000 点算。",
                              "通常30符4翻・60符3翻は7700/11600点ですが、切り上げ満貫をオンにすると8000/12000点になります。",
                              "Normally 30 fu 4 han and 60 fu 3 han pay 7,700 / 11,600 pts; Kiriage Mangan rounds them up to 8,000 / 12,000.")
        case .uma: return tr("终局结算时按 1–4 名加减顺位奖惩点（如 10-20 即一位 +20000、二位 +10000、三位 −10000、四位 −20000）。",
                             "終局時に1〜4位の順位に応じて加減算される点数です（10-20なら1位+20000・2位+10000・3位−10000・4位−20000）。",
                             "Placement bonus/penalty applied at final settlement (e.g. 10-20 gives +20k / +10k / −10k / −20k).")
        case .kuitan: return tr("主流日麻规则允许吃、碰后做断幺九（1 翻）；关掉则只有门前清才算断幺九。",
                                "一般的なルールでは鳴いてもタンヤオが成立します（あり）。なしにすると門前限定になります。",
                                "Standard rules allow Tanyao on open hands. Turn off to require a closed hand.")
        case .cap: return tr("默认 13 翻及以上算累计役满。怕一把输太多可以设倍满（8 翻）或满贯（5 翻）封顶。",
                             "標準では13翻以上は数え役満です。上限を設ける場合は倍満（8翻）や満貫（5翻）を選べます。",
                             "By default, 13+ han is Kazoe Yakuman. You can cap hands at Baiman (8 han) or Mangan (5 han).")
        case .penalty: return tr("推倒了却无役或凑不成和牌，赔另外三家各这么多点，这一局接着打。",
                                 "誤って手牌を倒した場合、他家3人にそれぞれこの点数を支払い、同局をやり直します。",
                                 "Paid to each of the other 3 players on a false win; the hand is replayed.")
        case .swap: return tr("朋友局一般不换座。", "友人同士の対局では通常席替えしません。", "Casual games usually keep fixed seats.")
        }
    }

    func isStandard(_ rules: GameRules) -> Bool {
        let standard = GameRules.standard
        switch self {
        case .rate: return rules.yuanPerPoint == standard.yuanPerPoint
        case .rounds: return rules.totalHands == standard.totalHands
        case .minimum: return rules.minimumFan == standard.minimumFan
        case .flowers: return rules.includeFlowers == standard.includeFlowers
        case .base: return rules.kiriageMangan == standard.kiriageMangan
        case .uma: return rules.uma == standard.uma
        case .kuitan: return rules.allowKuitan == standard.allowKuitan
        case .cap: return rules.fanCap == standard.fanCap
        case .penalty: return rules.falseWinPenalty == standard.falseWinPenalty
        case .swap: return rules.swapSeatsEachRound == standard.swapSeatsEachRound
        }
    }

    func value(_ rules: GameRules) -> (text: String, unit: String, isNumber: Bool) {
        switch self {
        case .rate: return (rules.yuanPerPoint.yuanText, tr("元", "", ""), true)
        case .rounds:
            if rules.totalHands == 8 { return (tr("半庄 8 局", "半荘8局", "Hanchan 8"), "", false) }
            if rules.totalHands == 4 { return (tr("东风 4 局", "東風4局", "East 4"), "", false) }
            return ("\(rules.totalHands)", tr("局", "局", "hands"), true)
        case .minimum: return ("\(rules.minimumFan)", tr("翻", "翻", "han"), true)
        case .flowers: return (rules.includeFlowers ? tr("计宝牌", "あり", "On") : tr("不计", "なし", "Off"), "", false)
        case .base: return (rules.kiriageMangan ? tr("开启", "あり", "On") : tr("不切上", "なし", "Off"), "", false)
        case .uma:
            if rules.uma == 0 { return (tr("不设", "なし", "None"), "", false) }
            let second = rules.uma == 10 ? 5 : 10
            return ("\(second)-\(rules.uma)", "", false)
        case .kuitan: return (rules.allowKuitan ? tr("允许", "あり", "Allowed") : tr("门前限定", "なし", "Closed Only"), "", false)
        case .cap: return rules.fanCap > 0 ? (tr("\(rules.fanCap) 翻", "\(rules.fanCap)翻", "\(rules.fanCap) han"), "", false) : (tr("不封顶", "上限なし", "No Cap"), "", false)
        case .penalty: return (tr("\(rules.falseWinPenalty) 点", "\(rules.falseWinPenalty)点", "\(rules.falseWinPenalty) pts"), "", false)
        case .swap: return (rules.swapSeatsEachRound ? tr("换", "あり", "On") : tr("不换", "なし", "Off"), "", false)
        }
    }

    func options(playedHands: Int, current: GameRules) -> [RuleOption] {
        switch self {
        case .rate:
            var values = [0.5, 1, 2, 5, 10]
            if !values.contains(current.yuanPerPoint) { values.append(current.yuanPerPoint); values.sort() }
            return values.map { RuleOption.choice(\.yuanPerPoint, $0, "\($0.yuanText) 元", marksStandard: false) }
        case .rounds:
            return [(8, "半庄战（东南 8 局）"), (4, "东风战（4 局）"), (16, "一庄战（16 局）")].map { hands, label in
                var option = RuleOption.choice(\.totalHands, hands, label)
                option.enabled = hands >= playedHands
                return option
            }
        case .minimum:
            return [1, 2].map { RuleOption.choice(\.minimumFan, $0, "\($0) 翻起和") }
        case .flowers:
            return [true, false].map { RuleOption.choice(\.includeFlowers, $0, $0 ? "计宝牌" : "不计宝牌") }
        case .base:
            return [false, true].map {
                RuleOption.choice(\.kiriageMangan, $0, $0 ? "切上满贯（按 8000 / 12000 算）" : "按实算（7700 / 11600 点）")
            }
        case .uma:
            return [
                (0, tr("不设（只按素点结算）", "なし（素点のみ）", "None (Raw points only)")),
                (10, tr("5-10（一位 +10000 / 二位 +5000）", "ゴットー 5-10（+10000 / +5000）", "5-10 (+10k / +5k / −5k / −10k)")),
                (20, tr("10-20（一位 +20000 / 二位 +10000）", "ワンツー 10-20（+20000 / +10000）", "10-20 (+20k / +10k / −10k / −20k)")),
                (30, tr("10-30（一位 +30000 / 二位 +10000）", "ワンスリー 10-30（+30000 / +10000）", "10-30 (+30k / +10k / −10k / −30k)")),
            ].map { RuleOption.choice(\.uma, $0.0, $0.1) }
        case .kuitan:
            return [
                (true, tr("允许副露断幺九（喰断あり）", "喰いタンあり（鳴いても1翻）", "Allowed on open hands (Kuitan On)")),
                (false, tr("门前清限定（喰断なし）", "喰いタンなし（門前のみ）", "Closed hands only (Kuitan Off)")),
            ].map { RuleOption.choice(\.allowKuitan, $0.0, $0.1) }
        case .cap:
            return [(0, "不封顶（13 翻累计役满）"), (13, "13 翻（役满封顶）"), (8, "8 翻（倍满封顶）"), (5, "5 翻（满贯封顶）")].map {
                RuleOption.choice(\.fanCap, $0.0, $0.1)
            }
        case .penalty:
            var values = [3000, 2000, 4000]
            if !values.contains(current.falseWinPenalty) { values.append(current.falseWinPenalty) }
            return values.map { RuleOption.choice(\.falseWinPenalty, $0, "每家 \($0) 点") }
        case .swap:
            return [false, true].map { RuleOption.choice(\.swapSeatsEachRound, $0, $0 ? "换座" : "不换") }
        }
    }
}

struct RuleOption: Identifiable {
    var label: String
    var tag: String?
    var isSelected: (GameRules) -> Bool
    var apply: (inout GameRules) -> Void
    var enabled = true

    var id: String { label }

    static func choice<T: Equatable>(_ keyPath: WritableKeyPath<GameRules, T>, _ value: T, _ label: String,
                                     tag: String? = nil, marksStandard: Bool = true) -> RuleOption {
        let isStandard = marksStandard && GameRules.standard[keyPath: keyPath] == value
        return RuleOption(label: label, tag: isStandard ? "标准" : tag,
                          isSelected: { $0[keyPath: keyPath] == value },
                          apply: { $0[keyPath: keyPath] = value })
    }
}

extension Double {
    var yuanText: String { formatted(.number.precision(.fractionLength(0...2)).grouping(.never)) }
}
