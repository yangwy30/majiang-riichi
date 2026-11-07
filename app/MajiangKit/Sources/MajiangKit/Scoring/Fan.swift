import Foundation

/// 立直麻将役种（含役满）。宝牌（含赤宝牌、里宝牌）不计入起和役，单独记在 `ScoringResult.doraFan`。
public enum Fan: Int, CaseIterable, Codable, Sendable {
    // 1 翻
    case riichi = 1
    case ippatsu
    case menzenTsumo
    case tanyao
    case pinfu
    case iipeiko
    case seatWind
    case prevalentWind
    case whiteDragon
    case greenDragon
    case redDragon
    case rinshan
    case chankan
    case haitei
    case houtei

    // 2 翻
    case doubleRiichi
    case sanshokuDoujun
    case ittsuu
    case chanta
    case chiitoitsu
    case toitoi
    case sanankou
    case sankantsu
    case sanshokuDoukou
    case honroutou
    case shousangen

    // 3 翻
    case ryanpeiko
    case junchan
    case honitsu

    // 6 翻
    case chinitsu

    // 役满（13 翻）
    case kokushi
    case suuankou
    case daisangen
    case shousuushii
    case daisuushii
    case tsuuiisou
    case chinroutou
    case ryuuiisou
    case chuurenPoutou
    case suukantsu
    case tenhou
    case chiihou

    /// 门前清时的标准翻数（役满按 13 翻计）。
    public var points: Int {
        switch self {
        case .riichi, .ippatsu, .menzenTsumo, .tanyao, .pinfu, .iipeiko,
             .seatWind, .prevalentWind, .whiteDragon, .greenDragon, .redDragon,
             .rinshan, .chankan, .haitei, .houtei:
            return 1
        case .doubleRiichi, .sanshokuDoujun, .ittsuu, .chanta, .chiitoitsu,
             .toitoi, .sanankou, .sankantsu, .sanshokuDoukou, .honroutou, .shousangen:
            return 2
        case .ryanpeiko, .junchan, .honitsu:
            return 3
        case .chinitsu:
            return 6
        case .kokushi, .suuankou, .daisangen, .shousuushii, .daisuushii,
             .tsuuiisou, .chinroutou, .ryuuiisou, .chuurenPoutou, .suukantsu,
             .tenhou, .chiihou:
            return 13
        }
    }

    /// 副露（吃、碰、明杠）时的翻数；门前限定役返回 nil。
    public var openPoints: Int? {
        switch self {
        case .riichi, .ippatsu, .menzenTsumo, .pinfu, .iipeiko, .doubleRiichi,
             .chiitoitsu, .ryanpeiko, .kokushi, .suuankou, .chuurenPoutou, .tenhou, .chiihou:
            return nil
        case .sanshokuDoujun, .ittsuu, .chanta:
            return 1
        case .junchan, .honitsu:
            return 2
        case .chinitsu:
            return 5
        default:
            return points
        }
    }

    public var isYakuman: Bool { points == 13 }

    /// 实际计入的翻数（考虑是否门前清）。
    public func effectivePoints(isMenzen: Bool) -> Int {
        isMenzen ? points : (openPoints ?? points)
    }

    public var name: String {
        switch self {
        case .riichi: return tr("立直", "リーチ", "Riichi")
        case .ippatsu: return tr("一发", "一発", "Ippatsu")
        case .menzenTsumo: return tr("门前清自摸和", "門前清自摸和", "Menzen Tsumo")
        case .tanyao: return tr("断幺九", "タンヤオ", "Tanyao (All Simples)")
        case .pinfu: return tr("平和", "平和（ピンフ）", "Pinfu")
        case .iipeiko: return tr("一杯口", "一盃口", "Iipeiko (Pure Double Chow)")
        case .seatWind: return tr("自风牌", "役牌・自風", "Seat Wind (Yakuhai)")
        case .prevalentWind: return tr("场风牌", "役牌・場風", "Round Wind (Yakuhai)")
        case .whiteDragon: return tr("役牌·白", "役牌・白", "Yakuhai (White Dragon)")
        case .greenDragon: return tr("役牌·发", "役牌・發", "Yakuhai (Green Dragon)")
        case .redDragon: return tr("役牌·中", "役牌・中", "Yakuhai (Red Dragon)")
        case .rinshan: return tr("岭上开花", "嶺上開花", "Rinshan Kaihou (After a Kan)")
        case .chankan: return tr("抢杠", "槍槓", "Chankan (Robbing a Kan)")
        case .haitei: return tr("海底摸月", "海底摸月", "Haitei (Under the Sea)")
        case .houtei: return tr("河底捞鱼", "河底撈魚", "Houtei (Under the River)")
        case .doubleRiichi: return tr("双立直", "ダブルリーチ", "Double Riichi")
        case .sanshokuDoujun: return tr("三色同顺", "三色同順", "Sanshoku Doujun (Mixed Triple Chow)")
        case .ittsuu: return tr("一气通贯", "一気通貫", "Ittsuu (Pure Straight)")
        case .chanta: return tr("混全带幺九", "混全帯么九（チャンタ）", "Chanta (Half Outside Hand)")
        case .chiitoitsu: return tr("七对子", "七対子", "Chiitoitsu (Seven Pairs)")
        case .toitoi: return tr("对对和", "対々和", "Toitoi (All Pungs)")
        case .sanankou: return tr("三暗刻", "三暗刻", "Sanankou (Three Concealed Pungs)")
        case .sankantsu: return tr("三杠子", "三槓子", "Sankantsu (Three Kans)")
        case .sanshokuDoukou: return tr("三色同刻", "三色同刻", "Sanshoku Doukou (Triple Pung)")
        case .honroutou: return tr("混老头", "混老頭", "Honroutou (All Terminals & Honors)")
        case .shousangen: return tr("小三元", "小三元", "Shousangen (Little Three Dragons)")
        case .ryanpeiko: return tr("二杯口", "二盃口", "Ryanpeiko (Twice Pure Double Chow)")
        case .junchan: return tr("纯全带幺九", "純全帯么九（純チャン）", "Junchan (Pure Outside Hand)")
        case .honitsu: return tr("混一色", "混一色（ホンイツ）", "Honitsu (Half Flush)")
        case .chinitsu: return tr("清一色", "清一色（チンイツ）", "Chinitsu (Full Flush)")
        case .kokushi: return tr("国士无双", "国士無双", "Kokushi Musou (Thirteen Orphans)")
        case .suuankou: return tr("四暗刻", "四暗刻", "Suuankou (Four Concealed Pungs)")
        case .daisangen: return tr("大三元", "大三元", "Daisangen (Big Three Dragons)")
        case .shousuushii: return tr("小四喜", "小四喜", "Shousuushii (Little Four Winds)")
        case .daisuushii: return tr("大四喜", "大四喜", "Daisuushii (Big Four Winds)")
        case .tsuuiisou: return tr("字一色", "字一色", "Tsuuiisou (All Honors)")
        case .chinroutou: return tr("清老头", "清老頭", "Chinroutou (All Terminals)")
        case .ryuuiisou: return tr("绿一色", "緑一色", "Ryuuiisou (All Green)")
        case .chuurenPoutou: return tr("九莲宝灯", "九蓮宝燈", "Chuuren Poutou (Nine Gates)")
        case .suukantsu: return tr("四杠子", "四槓子", "Suukantsu (Four Kans)")
        case .tenhou: return tr("天和", "天和", "Tenhou (Blessing of Heaven)")
        case .chiihou: return tr("地和", "地和", "Chiihou (Blessing of Earth)")
        }
    }

    /// 一句话说清这个役怎么来的，给用户核对结果时看。
    public var explanation: String {
        switch self {
        case .riichi: return tr("门前清听牌时宣布立直", "門前清で聴牌しリーチを宣言", "Declared Riichi with a closed tenpai hand")
        case .ippatsu: return tr("立直后一巡内和牌，中间没人吃碰杠", "リーチ後1巡以内に和了（鳴きなし）", "Won within one turn after Riichi with no calls")
        case .menzenTsumo: return tr("没吃碰明杠，自己摸到和牌", "鳴かずにツモ和了", "Self-drawn win with a closed hand")
        case .tanyao: return tr("整手牌全是 2–8 的数牌，没有一、九、字牌", "2〜8の数牌のみで構成（么九牌なし）", "Only simple tiles 2–8, no terminals or honors")
        case .pinfu: return tr("门前清四组顺子，雀头不是役牌，两面听牌", "門前清で4順子・役牌以外の雀頭・両面待ち", "Closed hand of 4 sequences, valueless pair, two-sided wait")
        case .iipeiko: return tr("门前清有两组一模一样的顺子", "門前清で同種同数の順子が2組", "Closed hand with two identical sequences")
        case .seatWind: return tr("自己门风的一组刻子或杠", "自風牌の刻子または槓子", "Triplet or kan of your seat wind")
        case .prevalentWind: return tr("本场风圈的一组刻子或杠", "場風牌の刻子または槓子", "Triplet or kan of the round wind")
        case .whiteDragon: return tr("白板的一组刻子或杠", "白の刻子または槓子", "Triplet or kan of White Dragon (Haku)")
        case .greenDragon: return tr("发财的一组刻子或杠", "發の刻子または槓子", "Triplet or kan of Green Dragon (Hatsu)")
        case .redDragon: return tr("红中的一组刻子或杠", "中の刻子または槓子", "Triplet or kan of Red Dragon (Chun)")
        case .rinshan: return tr("开杠后摸上来的岭上牌自摸和了", "槓した後の嶺上牌でツモ和了", "Self-drawn win on the replacement tile after a kan")
        case .chankan: return tr("别人加杠时，抢和那张牌", "他家の加槓牌でロン和了", "Won off a tile another player added to an open pung")
        case .haitei: return tr("摸牌山最后一张牌自摸和了", "牌山の最後の1枚でツモ和了", "Self-drawn win on the last tile of the wall")
        case .houtei: return tr("和别人打出的全桌最后一张牌", "河の最後の打牌でロン和了", "Won by ron on the very last discard of the hand")
        case .doubleRiichi: return tr("第一巡还没人吃碰杠时就宣布立直", "鳴きのない第1巡目にリーチを宣言", "Declared Riichi on the very first turn with no calls")
        case .sanshokuDoujun: return tr("万、饼、条各有同一数字的顺子（副露减 1 翻）", "萬・筒・索で同じ数字の順子（喰い下がり1翻）", "Same sequence in all 3 suits (1 han if open)")
        case .ittsuu: return tr("同一花色有 123、456、789 三组顺子（副露减 1 翻）", "同種数牌で123・456・789の順子（喰い下がり1翻）", "123, 456, and 789 of the same suit (1 han if open)")
        case .chanta: return tr("每组顺子、刻子和雀头都带一、九或字牌（副露减 1 翻）", "全ての面子と雀頭に么九牌を含む（喰い下がり1翻）", "Every group and pair contains a terminal or honor (1 han if open)")
        case .chiitoitsu: return tr("7 个不同的对子，固定 25 符", "異なる7組の対子（25符固定）", "7 distinct pairs (fixed 25 fu)")
        case .toitoi: return tr("4 组全是刻子或杠，没有顺子", "4面子すべてが刻子または槓子", "4 triplets or kans, no sequences")
        case .sanankou: return tr("3 组自己摸来的暗刻或暗杠", "暗刻または暗槓が3組", "3 concealed triplets or kans")
        case .sankantsu: return tr("开了 3 个杠", "槓子が3組", "3 kans in one hand")
        case .sanshokuDoukou: return tr("万、饼、条各有同一数字的刻子或杠", "萬・筒・索で同じ数字の刻子・槓子", "Same-rank triplet or kan in all 3 suits")
        case .honroutou: return tr("整手牌只有一、九和字牌", "老頭牌（1・9）と字牌のみで構成", "Hand composed entirely of terminals (1, 9) and honors")
        case .shousangen: return tr("中、发、白里有两组刻子、一对雀头", "三元牌の2刻子＋1雀頭", "Two dragon triplets plus a pair of the third dragon")
        case .ryanpeiko: return tr("门前清有两组一杯口（四组顺子两两相同）", "門前清で一盃口が2組", "Closed hand with two sets of identical sequences")
        case .junchan: return tr("每组顺子、刻子和雀头都带一或九，没有字牌（副露减 1 翻）", "全面子と雀頭に老頭牌（1・9）を含む（喰い下がり2翻）", "Every group and pair has a terminal 1 or 9, no honors (2 han if open)")
        case .honitsu: return tr("只有一种数牌加字牌（副露减 1 翻）", "1種類の数牌と字牌のみ（喰い下がり2翻）", "Single suit plus honor tiles (2 han if open)")
        case .chinitsu: return tr("全部是同一种数牌，没有字牌（副露减 1 翻）", "1種類の数牌のみ、字牌なし（喰い下がり5翻）", "All tiles of a single suit, no honors (5 han if open)")
        case .kokushi: return tr("13 种幺九字牌各一张，再加其中任意一张成对", "13種の么九牌を1枚ずつ＋いずれか1枚", "One of each of the 13 terminals and honors, plus one duplicate")
        case .suuankou: return tr("4 组全是自己摸来的暗刻或暗杠", "暗刻または暗槓が4組", "4 concealed triplets or kans")
        case .daisangen: return tr("中、发、白三组都是刻子或杠", "白・發・中の3組すべてが刻子・槓子", "Triplets or kans of all three dragons")
        case .shousuushii: return tr("东、南、西、北里有三组刻子、一对雀头", "風牌の3刻子＋1雀頭", "Three wind triplets plus a pair of the fourth wind")
        case .daisuushii: return tr("东、南、西、北四组都是刻子或杠", "東・南・西・北の4組すべてが刻子・槓子", "Triplets or kans of all four winds")
        case .tsuuiisou: return tr("全部是东南西北中发白字牌", "字牌のみで構成", "Hand composed entirely of honor tiles")
        case .chinroutou: return tr("全部是 1 和 9 的数牌，没有字牌", "老頭牌（1・9の数牌）のみで構成", "Hand composed entirely of terminal 1 and 9 tiles")
        case .ryuuiisou: return tr("全部由 2、3、4、6、8 条和发财组成", "索子の2・3・4・6・8と發のみで構成", "Composed entirely of 2, 3, 4, 6, 8 bamboo and Green Dragon")
        case .chuurenPoutou: return tr("门前清同花色 1112345678999 加同花色任意一张", "門前清で同種数牌1112345678999＋1枚", "Closed 1112345678999 in one suit plus any tile of that suit")
        case .suukantsu: return tr("开了 4 个杠", "槓子が4組", "4 kans in one hand")
        case .tenhou: return tr("庄家第一巡配牌直接自摸和牌", "親が配牌の時点で和了", "Dealer wins on the initial 14-tile deal")
        case .chiihou: return tr("闲家第一巡还没人吃碰杠时自摸和牌", "子が鳴きのない第1ツモで和了", "Non-dealer wins on their first draw with no prior calls")
        }
    }
}

public struct FanEntry: Hashable, Codable, Sendable {
    public let fan: Fan
    public let count: Int
    /// 副露减翻时记录实际翻数；nil 时按 `fan.points * count`。
    public var han: Int?

    public init(fan: Fan, count: Int = 1, han: Int? = nil) {
        self.fan = fan
        self.count = count
        self.han = han
    }

    public var points: Int { han ?? (fan.points * count) }
}
