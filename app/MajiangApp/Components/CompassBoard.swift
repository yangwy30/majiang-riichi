import SwiftUI
import MajiangKit

/// 牌桌罗盘：四家按真实座次围着中间的藍色菱形（自己在下，下家在右，对家在上，上家在左）。
/// 每家写风位、名字、现在的点数和累计得失；菱形里是局顺、本场数和桌面的立直棒。
struct CompassBoard: View {
    struct Seat: Identifiable {
        var id: Int
        var wind: String
        var name: String
        var points: String
        var delta: Int?
        var isDealer = false
    }

    /// 顺序：下、右、上、左。
    var seats: [Seat]
    var title: String
    var honba: String?
    var sticks: Int?
    var caption: String
    var detail: String?
    var compact = false

    private var side: CGFloat { compact ? 100 : 118 }
    private var height: CGFloat { compact ? 284 : 312 }

    var body: some View {
        ZStack {
            diamond

            seat(seats[2], alignment: .center).frame(maxHeight: .infinity, alignment: .top)
            seat(seats[0], alignment: .center).frame(maxHeight: .infinity, alignment: .bottom)
            seat(seats[3], alignment: .leading).frame(maxWidth: .infinity, alignment: .leading)
            seat(seats[1], alignment: .trailing).frame(maxWidth: .infinity, alignment: .trailing)

            HStack(alignment: .top) {
                Text(caption)
                Spacer()
                if let detail { Text(detail) }
            }
            .font(.system(size: 12))
            .foregroundStyle(Theme.gray)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(14)
        .frame(height: height)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(Theme.line, lineWidth: 0.5))
    }

    private var diamond: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .fill(Theme.indigo)
                .frame(width: side, height: side)
                .rotationEffect(.degrees(45))
            VStack(spacing: compact ? 4 : 6) {
                Text(honba ?? " ")
                    .font(Theme.score(12))
                    .foregroundStyle(.white.opacity(0.85))
                Text(title)
                    .font(Theme.serif(compact ? 22 : 26, semibold: true))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: side * 1.1)
                HStack(spacing: 4) {
                    RiichiStickIcon(width: 20, height: 5, borderColor: .clear)
                        .opacity((sticks ?? 0) > 0 ? 1 : 0.55)
                    Text("×\(sticks ?? 0)")
                        .font(Theme.score(12))
                        .foregroundStyle(.white.opacity((sticks ?? 0) > 0 ? 1 : 0.7))
                }
                .opacity(sticks == nil ? 0 : 1)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func seat(_ seat: Seat, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 1) {
            HStack(spacing: 5) {
                Text(seat.wind)
                    .font(Theme.serif(13))
                    .foregroundStyle(seat.isDealer ? Theme.vermilion : Theme.gray)
                Text(seat.name)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if seat.isDealer { DealerStamp(size: 16) }
            }
            Text(seat.points)
                .font(Theme.score(compact ? 20 : 22))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let delta = seat.delta {
                Text(Theme.signed(delta))
                    .font(Theme.score(12))
                    .foregroundStyle(delta > 0 ? Theme.vermilion : Theme.gray)
            }
        }
        // 左右两家夹在菱形和卡片边之间
        .frame(maxWidth: alignment == .center ? nil : 84,
               alignment: alignment == .leading ? .leading : alignment == .trailing ? .trailing : .center)
        .accessibilityElement(children: .combine)
    }
}

extension CompassBoard {
    init(game: Game, compact: Bool = false) {
        let hand = game.displayHand
        let order = game.seating(ofRound: game.roundIndex(ofHand: hand))
        let me = game.position(of: game.me, inHand: hand)
        let kyoku = hand % 4 + 1
        let numeral = ["一", "二", "三", "四"][hand % 4]
        let wind = game.prevalentWind(ofHand: hand).name
        self.seats = (0..<4).map { offset in
            let player = order[(me + offset) % 4]
            return Seat(id: player,
                        wind: Theme.windGlyph(game.seatWind(of: player, inHand: hand).name),
                        name: game.players[player].name,
                        points: Theme.grouped(game.currentPoints(of: player)),
                        delta: game.scores[player],
                        isDealer: !game.isFinished && game.dealer(ofHand: hand) == player)
        }
        self.title = game.isFinished
            ? tr("终局", "終局", "Final")
            : tr("\(wind)\(numeral)局", "\(wind)\(numeral)局", "\(wind) \(kyoku)")
        self.honba = game.isFinished ? nil : tr("\(game.currentHonba)本场", "\(game.currentHonba)本場", "\(game.currentHonba) Honba")
        self.sticks = game.isFinished ? nil : game.currentPot / 1000
        self.caption = game.rules.totalHands == 4 ? tr("东风战", "東風戦", "East only") : tr("半庄战", "半荘戦", "Hanchan")
        self.detail = game.isFinished
            ? tr("打了 \(game.playedHandsCount) 局", "全\(game.playedHandsCount)局", "\(game.playedHandsCount) hands")
            : tr("还剩 \(game.remainingHands) 局", "残り\(game.remainingHands)局", "\(game.remainingHands) left")
        self.compact = compact
    }

    /// 还没开局时的空桌：东南西北四个空位。
    static var empty: CompassBoard {
        let start = Theme.grouped(Game.startingPoints)
        let winds = [tr("东", "東", "E"), tr("南", "南", "S"), tr("西", "西", "W"), tr("北", "北", "N")]
        let names = [tr("你", "あなた", "You"), tr("下家", "下家", "Right"), tr("对家", "対面", "Across"), tr("上家", "上家", "Left")]
        return CompassBoard(
            seats: (0..<4).map { Seat(id: $0, wind: winds[$0], name: names[$0], points: start, delta: nil, isDealer: $0 == 0) },
            title: tr("东一局", "東一局", "East 1"),
            honba: tr("0本场", "0本場", "0 Honba"),
            sticks: 0,
            caption: tr("半庄战", "半荘戦", "Hanchan"),
            detail: nil)
    }
}
