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
        let paid = game.rules.paidFan(record)
        let limit = Payment.limitName(han: paid, fu: record.fu, kiriageMangan: game.rules.kiriageMangan)
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 顶上一块绿毡：谁怎么和的（点一下回核对页改）、赢多少、几翻几符
                FeltBanner {
                    VStack(spacing: 4) {
                        Button { flow.showResult = false } label: {
                            HStack(spacing: 6) {
                                Text(record.discarder.map {
                                    tr("\(name(record.winner)) · \(name($0))放铳",
                                       "\(name(record.winner))・\(name($0))放銃",
                                       "\(name(record.winner)) · Ron (\(name($0)))")
                                } ?? tr("\(name(record.winner)) · 自摸", "\(name(record.winner))・ツモ", "\(name(record.winner)) · Tsumo"))
                                Text(tr("改 ›", "修正 ›", "Edit ›")).opacity(0.6)
                            }
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("回到核对页改谁和了、怎么和的")
                        if record.winner < deltas.count {
                            Text(Theme.signed(deltas[record.winner]))
                                .font(Theme.score(60, weight: .bold))
                                .tracking(-1.5)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
                        }
                        HStack(spacing: 10) {
                            if let limit { LimitStamp(text: limit, size: 15, color: .white) }
                            Text(tr("\(record.totalFan) 翻 · \(record.fu) 符", "\(record.totalFan)翻・\(record.fu)符", "\(record.totalFan) han · \(record.fu) fu"))
                                .font(Theme.score(15, weight: .regular))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    }
                    .padding(.top, 28)
                    .padding(.bottom, 32)
                    .padding(.horizontal, 20)
                }
                .padding(.horizontal, -20)

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
                DeltaGrid(game: game, deltas: deltas, hand: game.displayHand)
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
