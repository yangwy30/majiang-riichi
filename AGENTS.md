# majiang-riichi Project Context & Agent Instructions

## 1. 项目定位
- **产品**：日本立直麻将（Riichi Mahjong）拍照算点 + 四人牌局记账 iOS App（面向中 / 日 / 英全球日麻玩家，免费无广告、无内购）。
- **代码仓库**：`https://github.com/yangwy30/majiang-riichi`（本地路径：`/Users/yangwang/majiang-riichi`）。
- **姊妹项目**：国标麻将版 `majiang-ppc`（`/Users/yangwang/majiang-ppc`，已上架 App Store ID `6827328659`）。
- **前序上下文对话**：如果在新的 Project 会话中需要查阅最初的调研与迁移记录，可参考对话 ID `244e8afb-9abd-4caf-a9bc-f0c2dc864937`（日志位于 `/Users/yangwang/.gemini/antigravity-insiders/brain/244e8afb-9abd-4caf-a9bc-f0c2dc864937/.system_generated/logs/transcript.jsonl`）。

## 2. 架构与已完成状态
- **`app/MajiangKit`（100% 纯 Swift，无 C++ 依赖）**：
  - `Scoring/Fan.swift`：完整日本立直麻将役种（1 翻、2 翻、3 翻、6 翻、13 翻役满），含门前清限定与副露减 1 翻（喰下り）及白话解释。
  - `Scoring/FanCalculator.swift`：纯 Swift 实现 `4 面子 + 1 雀头`、`七对子`（7 个不同对子，固定 25 符）、`国士无双` 拆解与高点法（自动取最高基本点/翻/符解释），精确计算符数（20 副底、门前荣和 +10、自摸 +2、役牌/连风雀头符、听牌符、明暗刻杠符、平和自摸 20 符、七对 25 符、进十位）。宝牌（`flowerCount` / `flowerFan`）每张 +1 翻，不计入 1 翻起和役。
  - `Scoring/WinAssistant.swift`：核对页特殊和牌条件（`立直`、`一发`、`双立直`、`岭上开花`、`海底摸月`、`河底捞鱼`、`抢杠`）与差一张时的智能改牌建议。
  - `Scoring/L10n.swift`：全局三语国际化支持（`zh-Hans` 中文、`ja` 日文、`en` 英文），支持跟随系统语言或 App 内一键切换。
  - `Game/Game.swift`：立直麻将基本点公式 $B = \text{符} \times 2^{\text{翻}+2}$、满贯/跳满/倍满/三倍满/役满段位、庄闲自摸与荣和百位进位收付、**庄家连庄/轮庄状态机**、**本场棒（1 本场荣和 +300 点 / 自摸各 +100 点）**、**荒牌流局听牌罚符（不听罚 3000 点，庄家听牌连庄/不听流庄）**、**立直供托棒跨流局累积（`currentPot`，流局立直者必听牌并留 1000 点供托归下次和牌者，终局未领归一位 `トップ取り`）**、**他家同局立直棒（每家 1000 点）**、半庄 8 局 / 东风战 4 局、**有喰断 / 门清断幺（`allowKuitan`）**、**终局顺位马（`uma`：无 / 5-10 / 10-20 / 10-30）**、切上满贯选项、错和罚符（默认每家 3000 点）与千点折算汇率。
  - `Recognition/`：端侧 Core ML YOLOv8n（`MahjongTileDetector.mlpackage`）+ Gemini 双读管线（支持赤宝牌红五万/红五饼/红五条自动计数与 `0m/0p/0s` 记法解析），共用 `https://majiang.acrossus.app/recognize` 中转服务。
- **`app/MajiangApp`（SwiftUI iOS 客户端，独立 Bundle ID `com.yangwy30.majiang.riichi`）**：
  - 采用专属 **「勝色与朱」**（三桠和纸底 `#F3F4F0`、深胜色靛蓝 `#16202E`、立直棒朱红 `#C9372C`）视觉体系，与国标版 `majiang-ppc` 彻底区分（防 Apple 4.3 重复应用拒审）：
    - **牌桌中控盘**：深胜色电投桌中控方盘展示「東三局」、本场数与千点立直棒（`RiichiStickIcon` `—•— ×1`）；
    - **结算与手牌详情**：独立白底计分横幅 + 朱红方框段位印章（`LimitStamp`：满贯 / 跳满 / 倍满 / 三倍满 / 役满）；
    - **渐进式折叠交互**：核对页默认仅露「立直 + 一发」与宝牌加减器，他家立直棒与罕见偶然役（双立直/岭上/海底/抢杠/天地和）收进「其他」；桌规默认仅露半庄/东风与汇率，顺位马、喰断、切上满贯等二级折叠在「更多桌规」。
  - 已完成 **中 / 日 / 英（CN / JP / EN）完整国际化**（`日麻算番` / `麻雀カメラ計算` / `Riichi Scorer`），`cd app/MajiangKit && swift test`（70 项测试）与 `xcodebuild` 模拟器构建均 100% 通过。

## 算点规则取舍（2026-11-06 定，不用再问 Yang）
Yang 的原则：和真实使用场景对标，对用户足够简洁。所以默认值跟玩家熟悉的日麻习惯走，不为少见分歧加开关。标准用例在 `app/MajiangKit/Tests/MajiangKitTests/Fixtures/riichi-golden-cases.json`。
- 连风雀头 4 符；累计役满（13 翻以上算一倍役满，最多一倍）；多个役满累加；国士十三面、四暗刻单骑、纯正九莲都算单倍；没有人和。这些都不设开关。
- 切上满贯默认关，保留现有开关，因为线下雀庄常开、线上常关，两种习惯都有人用。
- WRC / EMA 在连风雀头、切上满贯和累计役满上有不同规定，不作为默认。比赛规则以后真有人要，再做成一个「比赛规则」预设，不拆成多个开关。

## 3. 待推进方向
1. **进阶日麻桌规可选开关（按需迭代）**：如 25,000 点起始原点展示 vs 零和净分切换、终局顺位马（ウマ 10-20 / 10-30）与头名赏（オカ）、双响（ダブロン）等。
2. **真机/模拟器走查与 App Store 多语言截图生成**。
3. **App 命名、独立 Bundle ID 与图标（后期再做）**：先专注核心功能与交互编程。
