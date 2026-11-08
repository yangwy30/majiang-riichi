import SwiftUI
import MajiangKit

/// 结算：名次、最省事的转账、本场最大的一手。进到这里时牌局已经结束了。
struct SettleView: View {
    @Environment(AppModel.self) private var model
    let gameID: UUID
    @State private var copied = false

    var body: some View {
        if let game = model.game(gameID) {
            content(game)
        }
    }

    /// 「+¥76」「−¥12.5」「¥0」。
    private func signedMoney(_ game: Game, _ points: Int) -> String {
        points > 0 ? "+" + game.moneyText(points) : game.moneyText(points)
    }

    private func content(_ game: Game) -> some View {
        let scores = game.scores
        let ranking = Settlement.ranking(scores: scores)
        let transfers = Settlement.minimalTransfers(scores: scores)
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 跟结果页、这一局一样的绿毡头：终局、第一名、日期和规则
                FeltBanner {
                    VStack(spacing: 4) {
                        Text("\(game.startedAt.dayLabel) · " + tr("\(game.playedHandsCount) 局", "全\(game.playedHandsCount)局", "\(game.playedHandsCount) hands"))
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.7))
                        Text(tr("终局", "終局", "Final"))
                            .font(.system(size: 34, weight: .bold))
                            .padding(.top, 4)
                        if let top = ranking.first {
                            Text(tr("第一 · \(game.players[top].name) \(signedMoney(game, scores[top]))",
                                    "トップ・\(game.players[top].name) \(signedMoney(game, scores[top]))",
                                    "Top · \(game.players[top].name) \(signedMoney(game, scores[top]))"))
                                .font(Theme.score(15, weight: .regular))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                        Text(game.rulesSummary)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.top, 2)
                    }
                    .padding(.top, 18)
                    .padding(.bottom, 22)
                    .padding(.horizontal, 20)
                }
                .padding(.horizontal, -20)

                VStack(spacing: 0) {
                    ForEach(Array(ranking.enumerated()), id: \.element) { place, player in
                        HStack(spacing: 16) {
                            Text("\(place + 1)")
                                .font(Theme.glyph(14))
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(place == 0 ? Theme.fill : Theme.gray, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                            Text(game.players[player].name).font(.system(size: 17, weight: .medium))
                            Spacer()
                            // 结算是拿来转钱的：大字写钱，1 分不是 1 元时旁边小字写分，跟下面的转账对得上
                            if game.rules.yuanPerPoint != 1 {
                                Text(tr("\(Theme.signed(scores[player])) 点", "\(Theme.signed(scores[player]))点", "\(Theme.signed(scores[player])) pts"))
                                    .font(.system(size: 14).monospacedDigit())
                                    .foregroundStyle(Theme.gray)
                            }
                            Text(signedMoney(game, scores[player]))
                                .font(Theme.score(26))
                                .foregroundStyle(Theme.scoreColor(scores[player]))
                        }
                        .frame(height: 60)
                        Hairline()
                    }
                }
                .padding(.top, 14)

                SectionLabel("这样转账最省事")
                    .padding(.top, 32)
                    .padding(.bottom, 10)
                VStack(spacing: 0) {
                    if transfers.isEmpty {
                        Text("不用转账，正好打平。")
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.gray)
                            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                    }
                    ForEach(Array(transfers.enumerated()), id: \.offset) { index, t in
                        HStack {
                            HStack(spacing: 10) {
                                Text(game.players[t.from].name)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Theme.faint)
                                    .accessibilityLabel("转给")
                                Text(game.players[t.to].name)
                            }
                            .font(.system(size: 16))
                            Spacer()
                            Text(game.moneyText(t.points))
                                .font(.system(size: 17, weight: .semibold).monospacedDigit())
                        }
                        .frame(height: 54)
                        if index < transfers.count - 1 { Hairline(color: Theme.lineSoft) }
                    }
                }
                .padding(.vertical, 4)
                .block()

                if let line = game.biggestWinLine {
                    Text(line)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.gray)
                        .padding(.top, 24)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 0)
        }
        .bottomBar {
            // 发图：微信里大家一眼看清；要文字的复制一下贴进群里
            Button("发到微信群") { ShareSheet.share(game) }
                .buttonStyle(.primary)
            // 两个次要操作并排放，免得底部栏太高
            HStack(spacing: 28) {
                Button(copied ? "已复制，去微信粘贴" : "复制文字版") {
                    UIPasteboard.general.string = game.shareText
                    copied = true
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        copied = false
                    }
                }
                // 结算是按账本算的；记错了回到账本改，回来就是新的结果
                Button("看每一局，改记错的") { model.path.append(.table(game.id)) }
            }
            .buttonStyle(.text(size: 14))
        }
        .page()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            NavBack(tr("返回", "戻る", "Back")) { model.path = [] }
        }
    }
}
