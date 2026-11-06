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
  - `Game/Game.swift`：立直麻将基本点公式 $B = \text{符} \times 2^{\text{翻}+2}$、满贯/跳满/倍满/三倍满/役满段位、庄闲自摸与荣和百位进位收付、**庄家连庄/轮庄状态机**、**本场棒（1 本场荣和 +300 点 / 自摸各 +100 点）**、**荒牌流局听牌罚符（不听罚 3000 点，庄家听牌连庄/不听流庄）**、**他家立直供托棒（每家 1000 点）**、半庄 8 局 / 东风战 4 局、切上满贯选项、错和罚符（默认每家 3000 点）与千点折算汇率。
  - `Recognition/`：端侧 Core ML YOLOv8n（`MahjongTileDetector.mlpackage`）+ Gemini 双读管线（支持赤宝牌红五万/红五饼/红五条自动计数与 `0m/0p/0s` 记法解析），共用 `https://majiang.acrossus.app/recognize` 中转服务。
- **`app/MajiangApp`（SwiftUI iOS 客户端）**：
  - 延续「墨与朱」（纸白底 `#F6F4EE`、墨黑 `#141413`、朱印红 `#C83E2B`）视觉审美。
  - 核对页外露「立直 + 一发」一键快捷开关、宝牌加减器、他家立直棒选择；牌桌页支持流局听牌多选弹窗与本场数显示。
  - 已完成日麻化改造，`cd app/MajiangKit && swift test`（68 项测试）与 `xcodebuild` 模拟器构建均 100% 通过。

## 3. 待推进方向
1. **多语言国际化（CN / JP / EN）**：使用 `Localizable.xcstrings` 支持中文、日文（`リーチ / 役牌 / ドラ / 満貫`）、英文（`Riichi / Yakuhai / Dora / Mangan`）。
2. **真机/模拟器走查与 App Store 截图生成**。
3. **App 命名、独立 Bundle ID 与图标（后期再做）**：先专注核心功能与交互编程。
