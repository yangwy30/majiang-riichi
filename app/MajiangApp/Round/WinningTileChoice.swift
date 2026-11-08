import MajiangKit

/// 和的是哪张：不要求一定放在最右。每种牌各当一次和的那张算一遍，
/// 算出来翻符都一样就不用问；不一样才在绿毡上把这几张标出来让人点。
extension RoundFlow {
    struct WinningCandidate: Equatable {
        /// 这种牌在立牌里第一次出现的位置。
        var index: Int
        var han: Int
        var fu: Int
    }

    /// 能当和的那张、而且这样能和的牌（每种牌一次）。
    var winningCandidates: [WinningCandidate] {
        let concealed = tiles.map(\.tile)
        guard concealed.count > 1 else { return [] }
        var seen = Set<Tile>()
        var result: [WinningCandidate] = []
        for (index, tile) in concealed.enumerated() where seen.insert(tile).inserted {
            let candidate = Hand(melds: melds, concealed: concealed, winningTile: tile)
            guard case .success(let score) = FanCalculator.score(candidate, context: context),
                  score.meetsMinimum(game.rules.minimumFan) else { continue }
            result.append(WinningCandidate(index: index, han: score.totalFan, fu: score.fu))
        }
        return result
    }

    /// 和的是哪张会影响翻符，才需要问。
    var winningTileMatters: Bool {
        Set(winningCandidates.map { "\($0.han)/\($0.fu)" }).count > 1
    }

    /// 现在选的那张不能当和的那张（比如换了牌）时，挑一张最可能的：最右边那张能和就用它，不然用翻符最高的。
    func settleWinningTile() {
        let candidates = winningCandidates
        guard !candidates.isEmpty else { return }
        let concealed = tiles.map(\.tile)
        let current = winningIndex.flatMap { concealed.indices.contains($0) ? concealed[$0] : nil } ?? concealed.last
        if let current, candidates.contains(where: { concealed[$0.index] == current }) { return }
        if let last = concealed.last, candidates.contains(where: { concealed[$0.index] == last }) {
            winningIndex = concealed.indices.last
            return
        }
        let best = candidates.max { ($0.han, $0.fu) < ($1.han, $1.fu) }
        winningIndex = best.map { candidate in concealed.lastIndex(of: concealed[candidate.index]) ?? candidate.index }
    }
}
