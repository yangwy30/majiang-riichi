import SwiftUI
import MajiangKit

/// 规则和役种说明：给打立直日麻的人看的白话速查表。
struct RulesGuideView: View {
    @Environment(\.dismiss) private var dismiss
    /// 在「役表」tab 里：不套导航栏，也没有关闭。
    var embedded = false

    private var basics: [(String, String)] {
        [
            (tr("怎么算点和钱", "点数と収支の計算方法", "How Points & Payments Work"),
             tr("按翻数和符数算出基本点：闲家荣和由放铳者付 4 倍基本点，闲家自摸由庄家付 2 倍、另外两家闲家各付 1 倍；庄家和牌是闲家的 1.5 倍（荣和 6 倍，自摸三家各付 2 倍），全部按百位向上进位。5 翻起固定为满贯（闲 8000 / 庄 12000）、跳满、倍满、三倍满、役满。",
                "翻数と符から基本点を算出します。子のロンは放銃者が基本点×4、子のツモは親が×2・子2人が×1を支払い、親の和了は子の1.5倍（ロン×6、ツモは子3人が各×2）で、すべて100点単位に切り上げます。5翻以上は満貫（子8000 / 親12000）・跳満・倍満・三倍満・役満となります。",
                "Base points are calculated from han and fu. For a non-dealer win, Ron is 4× base from the discarder, and Tsumo is 2× from the dealer and 1× from each non-dealer. Dealer wins are 1.5× larger (6× on Ron, 2× from each non-dealer on Tsumo), all rounded up to the nearest 100. 5+ han reach fixed limits: Mangan (8,000 / 12,000), Haneman, Baiman, Sanbaiman, and Yakuman.")),
            (tr("1 翻起和（无役不能和）", "1翻縛り（役なしは和了不可）", "1-Han Yaku Minimum"),
             tr("立直麻将至少要有 1 翻「役」才能和牌。表宝牌、赤宝牌、里宝牌每张加 1 翻，但不能当起和役。没吃碰明杠（门前清）听牌时宣布「立直」，就有 1 翻役。",
                "リーチ麻雀では最低1翻の「役」がないと和了できません。表ドラ・赤ドラ・裏ドラは1枚につき+1翻加算されますが、役としては認められません。門前清で聴牌した際に「リーチ」を宣言すれば1翻の役がつきます。",
                "At least 1 han from a valid Yaku is required to win. Dora, Red Fives, and Ura-dora add +1 han each after you have a yaku, but do not satisfy the 1-han requirement on their own. Declaring Riichi with a closed tenpai hand gives 1 han.")),
            (tr("连庄、本场与流局供托", "連荘・本場・流局と供託", "Dealer Repeats, Honba & Draws"),
             tr("庄家和牌或流局听牌时连庄，本场数 +1（每本场荣和 +300 点、自摸各 +100 点）。荒牌流局时，不听牌的家合计付 3000 点给听牌的家；流局中打出的 1000 点立直棒留在桌面作为供托，归下一位和牌者收取。",
                "親が和了または流局時に聴牌していれば連荘となり、1本場につきロン+300点（ツモは各+100点）が加算されます。荒牌流局時は不聴者が合計3000点を聴牌者に支払います。流局時に出た1000点リーチ棒は供託として次局の和了者が総取りします。",
                "The dealer repeats on a win or tenpai draw, adding +1 Honba (+300 pts on Ron, +100 pts each on Tsumo). On an exhaustive draw, noten players pay a total of 3,000 pts to tenpai players, and any 1,000-pt Riichi sticks remain in the pot for the next winner.")),
            (tr("副露减翻与门前限定", "喰い下がりと門前限定役", "Open Hand Reductions & Closed-Only Yaku"),
             tr("立直、一发、门前清自摸和、平和、一杯口、二杯口、七对子只能在门前清（没吃、没碰、没明杠）时成立；三色同顺、一气通贯、混全带幺九、纯全带幺九、混一色、清一色在吃碰明杠后减 1 翻。",
                "リーチ・一発・門前清自摸和・平和・一盃口・二盃口・七対子は門前清（鳴きなし）限定です。三色同順・一気通貫・チャンタ・純チャン・混一色・清一色は鳴くと1翻下がります。",
                "Riichi, Ippatsu, Menzen Tsumo, Pinfu, Iipeiko, Ryanpeiko, and Chiitoitsu require a closed hand. Sanshoku, Ittsuu, Chanta, Junchan, Honitsu, and Chinitsu lose 1 han when open.")),
            (tr("错和罚符", "チョンボ（錯和）罰符", "Chombo (False Win Penalty)"),
             tr("推倒了却无役或凑不成和牌，赔另外三家各 3000 点，这一局接着打。",
                "誤って手牌を倒した（役なし・不聴など）場合、他家3人に各3000点を支払い、その局をやり直します。",
                "Declaring an invalid win (no yaku or incomplete hand) costs 3,000 pts to each of the other 3 players, and the hand is replayed.")),
        ]
    }

    private var groups: [(points: Int, fans: [Fan])] {
        Dictionary(grouping: Fan.allCases, by: \.points)
            .map { ($0.key, $0.value) }
            .sorted { $0.points < $1.points }
    }

    var body: some View {
        if embedded {
            list
                .page()
        } else {
            NavigationStack {
                list
                    .page()
                    .navigationTitle("立直规则与役种")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        NavClose("关闭") { dismiss() }
                    }
            }
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if embedded {
                    PageTitle(title: tr("役表", "役一覧", "Yaku"), subtitle: nil)
                }
                ForEach(groups, id: \.points) { group in
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        if group.points == 13 {
                            Text(tr("役满", "役満", "Yakuman")).font(Theme.glyph(22, semibold: true))
                        } else {
                            Text("\(group.points)").font(Theme.score(24, weight: .semibold))
                            Text(tr("翻", "翻", "han")).font(Theme.glyph(15))
                        }
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 4)
                    Hairline()
                    ForEach(group.fans, id: \.self) { fan in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(fan.name).font(.system(size: 16, weight: .medium))
                            Text(fan.explanation)
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.gray)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                        .overlay(alignment: .bottom) { Hairline(color: Theme.lineSoft) }
                    }
                }

                let rulesTitle = tr("规则", "ルール", "Rules")
                Text(rulesTitle)
                    .font(Theme.heading(rulesTitle, size: 22))
                    .padding(.top, 32)
                    .padding(.bottom, 4)
                Hairline()
                ForEach(basics, id: \.0) { title, text in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title).font(.system(size: 16, weight: .semibold))
                        Text(text)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.gray)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, embedded ? 20 : 0)
            .padding(.bottom, 24)
        }
    }
}
