import SwiftUI
import UIKit
import MajiangKit

/// 发到微信群的账本图：打完了就是结算（名次 + 最省事的转账），没打完就是现在的分数 + 最近几局。
/// 宽 360 点、按 3 倍渲染，在微信里点开是 1080 宽的清楚图片。
struct ShareCard: View {
    var game: Game

    private var scores: [Int] { game.scores }
    private var ranking: [Int] { Settlement.ranking(scores: scores) }
    private var transfers: [Transfer] { Settlement.minimalTransfers(scores: scores) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            VStack(alignment: .leading, spacing: 0) {
                standings
                if game.isFinished {
                    transferList.padding(.top, 24)
                    if let line = game.biggestWinLine {
                        Text(line)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.gray)
                            .padding(.top, 18)
                    }
                } else {
                    recent.padding(.top, 24)
                }
                HStack(spacing: 8) {
                    RiichiStickIcon(width: 24, height: 5)
                    Text(tr("日麻算番 · 拍一下，翻符和点数都算好",
                            "麻雀カメラ計算・撮るだけで翻符と点数を計算",
                            "Riichi Scorer · Han, fu and points from a photo"))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.gray)
                }
                .padding(.top, 24)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .frame(width: 360, alignment: .leading)
        .background(Theme.paper)
        .foregroundStyle(Theme.ink)
        // 发到群里的图不跟手机的深色模式走
        .environment(\.colorScheme, .light)
    }

    /// 绿毡抬头（底边一条胡桃木）：局况大字，日期和规则小字。
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(game.startedAt.dayLabel)
                Spacer()
                Text(game.rulesSummary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.75))
            let title = game.isFinished ? tr("终局", "対局終了", "Final") : (game.handLabel)
            Text(title)
                .font(Theme.heading(title, size: 26))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.top, 6)
            Text(game.isFinished
                 ? tr("一共 \(game.playedHandsCount) 局", "全\(game.playedHandsCount)局", "\(game.playedHandsCount) hands total")
                 : tr("打了 \(game.playedHandsCount) 局 · 还剩 \(game.remainingHands) 局",
                      "\(game.playedHandsCount)局消化・残り\(game.remainingHands)局",
                      "\(game.playedHandsCount) played · \(game.remainingHands) left"))
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(FeltHeader())
    }

    private var standings: some View {
        VStack(spacing: 0) {
            ForEach(Array(ranking.enumerated()), id: \.element) { place, player in
                HStack(spacing: 14) {
                    Text("\(place + 1)")
                        .font(Theme.glyph(13))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(place == 0 ? Theme.felt[1] : Color(hex: 0x6E7370), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    Text(game.players[player].name)
                        .font(.system(size: 17, weight: .medium))
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(game.moneyText(scores[player]))
                        .font(.system(size: 13).monospacedDigit())
                        .foregroundStyle(Theme.gray)
                    Text(Theme.signed(scores[player]))
                        .font(Theme.score(20))
                        .foregroundStyle(Theme.scoreColor(scores[player]))
                        .lineLimit(1)
                        .fixedSize()
                }
                .frame(height: 54)
                Hairline()
            }
        }
    }

    private var transferList: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel("这样转账最省事").padding(.bottom, 6)
            if transfers.isEmpty {
                Text("不用转账，正好打平。")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.gray)
                    .padding(.vertical, 8)
            }
            ForEach(Array(transfers.enumerated()), id: \.offset) { _, t in
                HStack(spacing: 8) {
                    Text(game.players[t.from].name)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.faint)
                    Text(game.players[t.to].name)
                    Spacer()
                    Text(game.moneyText(t.points))
                        .font(.system(size: 16, weight: .semibold).monospacedDigit())
                }
                .font(.system(size: 15))
                .frame(height: 36)
            }
        }
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel("最近几局").padding(.bottom, 4)
            if game.records.isEmpty {
                Text("还没有记录。")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.gray)
                    .padding(.vertical, 8)
            }
            ForEach(Array(game.records.enumerated().reversed().prefix(4)), id: \.element.id) { number, record in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(number + 1)")
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundStyle(Theme.gray)
                        .frame(width: 16, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.title(in: game)).font(.system(size: 14))
                        Text(record.detail(in: game))
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.gray)
                    }
                    Spacer(minLength: 6)
                    if let value = record.headline {
                        Text(Theme.signed(value))
                            .font(Theme.score(15))
                            .foregroundStyle(Theme.scoreColor(value))
                    }
                }
                .padding(.vertical, 7)
            }
        }
    }
}

extension Game {
    /// 「最大的一手：杨，清一色 8 翻（倍满）」。
    var biggestWinLine: String? {
        guard let biggest = biggestWin else { return nil }
        let paid = rules.paidFan(biggest.win)
        let limit = Payment.limitName(han: paid, fu: biggest.win.fu, kiriageMangan: rules.kiriageMangan)
        let suffix = limit.map { tr("\($0) \(paid) 翻", "\($0) \(paid)翻", "\($0) \(paid) han") }
            ?? tr("\(paid) 翻 \(biggest.win.fu) 符", "\(paid)翻\(biggest.win.fu)符", "\(paid) han \(biggest.win.fu) fu")
        return tr("最大的一手：\(players[biggest.win.winner].name)，",
                  "最高打点：\(players[biggest.win.winner].name)（",
                  "Biggest hand: \(players[biggest.win.winner].name), ")
            + (biggest.win.fans.first.map { "\($0.fan.name) · " } ?? "") + suffix + tr("", "）", "")
    }

    /// 文字版，复制到微信里直接能看。
    var shareText: String {
        let scores = self.scores
        var lines = [isFinished
                     ? tr("日麻算番 \(startedAt.dayLabel) · 打完了，一共 \(playedHandsCount) 局",
                          "麻雀カメラ計算 \(startedAt.dayLabel)・対局終了（全\(playedHandsCount)局）",
                          "Riichi Scorer \(startedAt.dayLabel) · Final, \(playedHandsCount) hands")
                     : tr("日麻算番 \(startedAt.dayLabel) · 打到\(handLabel)（打了 \(playedHandsCount) 局）",
                          "麻雀カメラ計算 \(startedAt.dayLabel)・\(handLabel)（\(playedHandsCount)局消化）",
                          "Riichi Scorer \(startedAt.dayLabel) · \(handLabel) (\(playedHandsCount) played)")]
        for player in Settlement.ranking(scores: scores) {
            lines.append("\(players[player].name) " + tr("\(Theme.signed(scores[player])) 点（\(moneyText(scores[player]))）",
                                                         "\(Theme.signed(scores[player]))点（\(moneyText(scores[player]))）",
                                                         "\(Theme.signed(scores[player])) pts (\(moneyText(scores[player])))"))
        }
        if isFinished {
            let transfers = Settlement.minimalTransfers(scores: scores)
            if !transfers.isEmpty {
                lines.append(tr("这样转账最省事：", "精算：", "Settle up:"))
                for t in transfers {
                    lines.append("\(players[t.from].name) → \(players[t.to].name) \(moneyText(t.points))")
                }
            }
            if let line = biggestWinLine { lines.append(line) }
        } else if let last = records.last {
            lines.append(tr("上一局：", "前局：", "Last hand: ") + last.title(in: self))
        }
        return lines.joined(separator: "\n")
    }

    /// 账本图。
    @MainActor
    func shareImage() -> UIImage? {
        let renderer = ImageRenderer(content: ShareCard(game: self))
        renderer.scale = 3
        renderer.isOpaque = true
        return renderer.uiImage
    }
}

/// 系统分享面板（微信、存图、隔空投送……）。从最上层的页面弹出，sheet 里也能用。
enum ShareSheet {
    @MainActor
    static func present(_ items: [Any]) {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first,
              var top = scene.keyWindow?.rootViewController else { return }
        while let presented = top.presentedViewController { top = presented }
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.popoverPresentationController?.sourceView = top.view
        controller.popoverPresentationController?.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.maxY, width: 0, height: 0)
        top.present(controller, animated: true)
    }

    /// 发账本图；渲染不出来就退回文字。
    @MainActor
    static func share(_ game: Game) {
        if let image = game.shareImage() {
            present([image])
        } else {
            present([game.shareText])
        }
    }
}

private struct FeltHeader: ViewModifier {
    func body(content: Content) -> some View {
        FeltBanner { content }
    }
}
