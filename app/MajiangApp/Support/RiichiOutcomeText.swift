import Foundation
import MajiangKit

/// 双响、流局满贯、途中流局在账本里怎么写。
extension HandRecord {
    func specialTitle(in game: Game) -> String? {
        let name = { (i: Int) in game.players[i].name }
        let join = { (players: [Int]) in players.map(name).joined(separator: tr("、", "・", ", ")) }
        switch outcome {
        case .doubleRon(let wins):
            let winners = join(wins.map(\.winner))
            let discarder = wins.first?.discarder.map(name) ?? ""
            return tr("双响 · \(winners)和 · \(discarder)点炮",
                      "ダブロン・\(winners)（\(discarder)放銃）",
                      "Double Ron · \(winners) (\(discarder))")
        case .nagashi(let players, _, _):
            return tr("流局满贯 · \(join(players.sorted()))", "流し満貫・\(join(players.sorted()))", "Nagashi Mangan · \(join(players.sorted()))")
        case .abortive(let kind, _):
            return tr("途中流局 · \(kind.name)", "途中流局・\(kind.name)", "Abortive Draw · \(kind.name)")
        default:
            return nil
        }
    }
}
