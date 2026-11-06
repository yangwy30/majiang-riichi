# majiang-riichi

立直日麻拍照算点与牌桌记账 iOS App。

打完一手把牌推倒拍一张，端侧 Core ML（YOLOv8n）与 Gemini 双读认出牌面，纯 Swift 立直麻将引擎按高点法算出役种、翻数、符数与四家收付点数（满贯 / 跳满 / 倍满 / 三倍满 / 役满、庄闲自摸与荣和进百位），一键记入半庄 / 东风战账本，打完算出最少转账笔数。

## 目录结构

- `app/MajiangKit`：纯 Swift 核心库（牌面表示、端侧 + Gemini 双读管线、立直麻将役种/翻/符/点数引擎、半庄/东风战牌局账本与最小转账结算）
- `app/MajiangApp`：SwiftUI iOS 客户端（相机取景、逐张翻牌复核、核对改牌、立直与宝牌设置、牌桌方桌与微信账本分享图）

## 运行测试与构建

```bash
cd app/MajiangKit
swift test
```
