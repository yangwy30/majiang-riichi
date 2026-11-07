import SwiftUI
import MajiangKit

/// 结果：从下往上弹出的一层。翻符和点数大字，役种一行一个，这局谁付多少。
struct ResultSheet: View {
    var flow: RoundFlow
    var finish: (HandOutcome) -> Void

    var body: some View {
        Group {
            if let record = flow.winRecord, let deltas = flow.deltas {
                content(record, deltas)
            } else {
                ContentUnavailableView("这手牌还和不了", systemImage: "exclamationmark.circle")
            }
        }
        .foregroundStyle(Theme.ink)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(16)
        .presentationBackground(Theme.paper)
    }

    private func content(_ record: WinRecord, _ deltas: [Int]) -> some View {
        let game = flow.game
        let name = { (i: Int) in game.players[i].name }
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 谁和、怎么和的是记错最常见的地方：墨色写清楚，点一下收起结果回核对页改
                Button { flow.showResult = false } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(record.discarder.map {
                            tr("\(name(record.winner)) · \(name($0))点炮",
                               "\(name(record.winner))・\(name($0))放銃",
                               "\(name(record.winner)) · Ron (\(name($0)))")
                        } ?? tr("\(name(record.winner)) · 自摸", "\(name(record.winner))・ツモ", "\(name(record.winner)) · Tsumo"))
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(Theme.ink)
                        Text(tr("改 ›", "修正 ›", "Edit ›"))
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.gray)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("回到核对页改谁和了、怎么和的")
                .padding(.top, 20)
                let paid = game.rules.paidFan(record)
                let limit = Payment.limitName(han: paid, fu: record.fu, kiriageMangan: game.rules.kiriageMangan)
                // 这手值多少：翻符一行，点数最大
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .center, spacing: 10) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(record.totalFan)").font(Theme.score(30, weight: .semibold))
                            Text(tr("翻", "翻", "han")).font(Theme.serif(16))
                            Text("\(record.fu)")
                                .font(Theme.score(30, weight: .semibold))
                                .padding(.leading, 10)
                            Text(tr("符", "符", "fu")).font(Theme.serif(16))
                        }
                        Spacer()
                        if let limit {
                            LimitStamp(text: limit, size: 16)
                        }
                    }
                    if record.winner < deltas.count {
                        Text(Theme.signed(deltas[record.winner]))
                            .font(Theme.score(60, weight: .semibold))
                            .foregroundStyle(Theme.vermilion)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                }
                .padding(.vertical, 16)
                .block()
                .padding(.top, 4)
                .accessibilityElement(children: .combine)
                if paid < record.totalFan {
                    Text(tr("桌规封顶 \(game.rules.fanCap) 翻：\(record.totalFan) 翻按 \(game.rules.fanCap) 算",
                            "ルール上限 \(game.rules.fanCap)翻：\(record.totalFan)翻を\(game.rules.fanCap)翻として計算",
                            "Capped at \(game.rules.fanCap) han (\(record.totalFan) han counted as \(game.rules.fanCap))"))
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.gray)
                        .padding(.top, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                SectionLabel("役种与宝牌")
                    .padding(.top, 22)
                    .padding(.bottom, 6)
                FanList(win: record)

                SectionLabel("这局谁付多少")
                    .padding(.top, 22)
                    .padding(.bottom, 6)
                DeltaGrid(game: game, deltas: deltas)
                Text(game.paymentExplanation(record, honba: game.currentHonba, pot: game.currentPot, deltas: deltas))
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.gray)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            }
            .padding(.horizontal, 20)
        }
        .bottomBar {
            Button("记下") { finish(.win(record)) }
                .buttonStyle(.primary)
        }
    }
}
