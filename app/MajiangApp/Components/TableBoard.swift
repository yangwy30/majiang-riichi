import SwiftUI
import UIKit
import MajiangKit

/// 牌桌：俯视一张胡桃木框的绿毡麻将桌。四家按真实座次坐在四边（自己在下，下家在右，对家在上，上家在左），
/// 每家一张风牌、点数和名字，字都正着写。中间是电动桌的局顺面板，红条指着庄家；桌上的千点棒就是供托。
/// 点数变了会滚动，换庄时红条转到下一家。
struct TableBoard: View {
    struct Seat: Identifiable {
        var id: Int
        var wind: String
        var name: String
        var points: Int
        var isDealer = false
    }

    /// 顺序：下、右、上、左。
    var seats: [Seat]
    /// 中间面板的大字：「东 3」「终局」。
    var round: String
    /// 面板下面一行小字：「2 本场」。
    var honba: String?
    /// 桌上的千点棒（供托）几根。
    var sticks: Int
    var compact = false

    private var size: CGFloat { compact ? 268 : 296 }
    /// 庄家坐在哪一边（0 下、1 右、2 上、3 左），红条转过去。
    private var dealerSide: Int? { seats.firstIndex(where: \.isDealer) }

    var body: some View {
        ZStack {
            FeltTexture()
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(.black.opacity(0.3), lineWidth: 1)
                )

            panel
            if sticks > 0 {
                stickPile.offset(y: compact ? 50 : 56)
            }

            seat(seats[2], alignment: .center).frame(maxHeight: .infinity, alignment: .top).padding(.top, 14)
            seat(seats[0], alignment: .center).frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, 14)
            seat(seats[3], alignment: .leading).frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 12)
            seat(seats[1], alignment: .trailing).frame(maxWidth: .infinity, alignment: .trailing).padding(.trailing, 12)
        }
        .padding(11)
        .frame(width: size, height: size)
        .background(Walnut().clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous)))
        .shadow(color: Color(hex: 0x28190A).opacity(0.35), radius: 16, y: 12)
        .frame(maxWidth: .infinity)
        .animation(.snappy(duration: 0.45), value: seats.map(\.points))
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: dealerSide)
    }

    /// 电动桌中间的局顺面板：黑色玻璃，上面一道反光，红条指向庄家。
    private var panel: some View {
        let side: CGFloat = compact ? 70 : 78
        return ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x1E2321), Color(hex: 0x0C0E0D)], startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: [.white.opacity(0.14), .clear], startPoint: .topLeading, endPoint: .center))
            VStack(spacing: 2) {
                Text(round)
                    .font(.system(size: compact ? 14 : 15, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let honba {
                    Text(honba)
                        .font(.system(size: 9, weight: .medium))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            if let dealerSide {
                // 红条先放在下边，再按庄家的方向转过去
                Capsule()
                    .fill(Theme.tileRed)
                    .frame(width: 18, height: 3)
                    .shadow(color: Theme.tileRed.opacity(0.7), radius: 3)
                    .offset(y: side / 2 - 6)
                    .rotationEffect(.degrees(Double(dealerSide) * -90))
            }
        }
        .frame(width: side, height: side)
        .shadow(color: .black.opacity(0.35), radius: 7, y: 4)
        .accessibilityElement(children: .combine)
    }

    /// 供托：桌上摆几根千点棒，多了写个数。
    private var stickPile: some View {
        HStack(spacing: 6) {
            VStack(spacing: 4) {
                ForEach(0..<min(sticks, 3), id: \.self) { _ in
                    RiichiStickIcon(width: 58, height: 6, borderColor: .clear)
                        .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
                }
            }
            if sticks > 3 {
                Text("×\(sticks)").font(Theme.score(11)).foregroundStyle(.white.opacity(0.8))
            }
        }
        .accessibilityElement()
        .accessibilityLabel(tr("供托 \(sticks) 根", "供託 \(sticks)本", "\(sticks) riichi stick(s) on the table"))
    }

    @ViewBuilder
    private func seat(_ seat: Seat, alignment: HorizontalAlignment) -> some View {
        let tile = WindTile(text: seat.wind, isDealer: seat.isDealer, width: compact ? 22 : 24)
        let text = VStack(alignment: alignment, spacing: 1) {
            Text(Theme.grouped(seat.points))
                .font(Theme.score(compact ? 17 : 18))
                .contentTransition(.numericText(value: Double(seat.points)))
                .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
            Text(seat.name)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        Group {
            if alignment == .center {
                HStack(spacing: 9) { tile; text }
            } else {
                VStack(alignment: alignment, spacing: 6) { tile; text }
                    .frame(maxWidth: 80, alignment: alignment == .leading ? .leading : .trailing)
            }
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .combine)
    }
}

/// 绿毡：中间亮四周暗，加一层很细的绒面颗粒。
struct FeltTexture: View {
    var body: some View {
        ZStack {
            RadialGradient(colors: Theme.felt, center: UnitPoint(x: 0.5, y: 0.38), startRadius: 0, endRadius: 220)
            // 绒面颗粒是一小块图平铺的，只画一次；每次重画都撒几千个点会让牌桌出来得慢
            Image(uiImage: TextureTiles.feltGrain).resizable(resizingMode: .tile)
            // 毡面比木框低一点：边上压一圈阴影
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.black.opacity(0.35), lineWidth: 6)
                .blur(radius: 5)
        }
    }
}

/// 胡桃木框：斜着的木色渐变，一点细木纹，上边亮下边暗。
private struct Walnut: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: Theme.walnut, startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(uiImage: TextureTiles.woodGrain).resizable(resizingMode: .tile)
            LinearGradient(colors: [.white.opacity(0.18), .clear, .black.opacity(0.18)], startPoint: .top, endPoint: .bottom)
        }
    }
}

/// 毡面颗粒和木纹的小图，App 里只画一次，用的时候平铺。
private enum TextureTiles {
    static let feltGrain: UIImage = {
        let size = CGSize(width: 96, height: 96)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            var rng = SeededRandom(seed: 7)
            for _ in 0..<Int(size.width * size.height / 14) {
                UIColor(white: 1, alpha: 0.05 + rng.next() * 0.05).setFill()
                ctx.fill(CGRect(x: rng.next() * size.width, y: rng.next() * size.height, width: 0.7, height: 0.7))
            }
        }
    }()

    static let woodGrain: UIImage = {
        let size = CGSize(width: 120, height: 8)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            var rng = SeededRandom(seed: 3)
            var x: CGFloat = 0
            UIColor(white: 1, alpha: 0.035).setFill()
            while x < size.width {
                ctx.fill(CGRect(x: x, y: 0, width: 1, height: size.height))
                x += 4 + rng.next() * 5
            }
        }
    }()
}

/// 固定种子的随机数，毡面颗粒和木纹每次画出来都一样。
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E3779B97F4A7C15 }
    mutating func next() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat(state >> 33) / CGFloat(UInt64(1) << 31)
    }
}

/// 结果页、分享图顶上的一块绿毡，底边一条胡桃木。
struct FeltBanner<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .background(FeltTexture())
            Walnut().frame(height: 9)
        }
    }
}

extension TableBoard {
    init(game: Game, compact: Bool = false) {
        let hand = game.displayHand
        let order = game.seating(ofRound: game.roundIndex(ofHand: hand))
        let me = game.position(of: game.me, inHand: hand)
        let wind = Theme.windGlyph(game.prevalentWind(ofHand: hand).name)
        self.seats = (0..<4).map { offset in
            let player = order[(me + offset) % 4]
            var name = game.players[player].name
            if player == game.me { name += tr(" · 你", "・あなた", " · you") }
            return Seat(id: player,
                        wind: Theme.tileGlyph(game.seatWind(of: player, inHand: hand)),
                        name: name,
                        points: game.currentPoints(of: player),
                        isDealer: !game.isFinished && game.dealer(ofHand: hand) == player)
        }
        self.round = game.isFinished ? tr("终局", "終局", "Final") : "\(wind) \(hand % 4 + 1)"
        self.honba = game.isFinished ? nil : tr("\(game.currentHonba) 本场", "\(game.currentHonba) 本場", "\(game.currentHonba) honba")
        self.sticks = game.isFinished ? 0 : game.currentPot / 1000
        self.compact = compact
    }

    /// 还没开局时的空桌：东南西北四个空位，你坐东。
    static var empty: TableBoard {
        let winds = (0..<4).map { Theme.tileGlyph(Wind(rawValue: $0)!) }
        let names = [tr("你", "あなた", "You"), tr("下家", "下家", "Right"), tr("对家", "対面", "Across"), tr("上家", "上家", "Left")]
        return TableBoard(
            seats: (0..<4).map { Seat(id: $0, wind: winds[$0], name: names[$0], points: Game.startingPoints, isDealer: $0 == 0) },
            round: tr("东 1", "東 1", "E 1"),
            honba: tr("0 本场", "0 本場", "0 honba"),
            sticks: 0)
    }
}
