import SwiftUI
import MajiangKit

enum RoundStep: Hashable {
    case check
}

/// 记一局的草稿：谁和了 → 拍照 → 核对（牌面 + 怎么和的）→ 结果。
@MainActor
@Observable
final class RoundFlow {
    let game: Game
    var steps: [RoundStep] = []

    /// 谁和了。没选之前先按庄家算番（门风要用），但不能记账。
    var winner: Int
    /// 拍照页或核对页上点过谁和了。不替人预先选，免得没留意就记到庄家头上。
    var winnerChosen = false
    var photo: UIImage?
    var isRecognizing = false
    /// 双读时端侧的结果已经显示在核对页，Gemini 还在复核（界面上叫「再认一遍」，不提 Gemini）。复核完之前牌面不能改。
    var isReviewing = false
    var recognitionError: String?
    var source = ""
    /// 识别时的说明，比如有牌没认出来。
    var notes: [String] = []

    /// 立牌（含和张），可逐张修改。
    var tiles: [RecognizedTile] = []
    var melds: [Meld] = []
    /// 和的是 `tiles` 里的哪一张。
    var winningIndex: Int?
    /// 需要确认的牌里，规则引擎推荐的读法。
    var recommended: [Int: Tile] = [:]
    /// 只有一边读到的牌里，规则引擎推荐删掉的。
    var recommendedRemovals: Set<Int> = []
    /// 刚识别完时有几张要确认（核对页标题上说两边读得一不一样）。
    var reviewAtLoad = 0

    var selfDrawn = true
    /// 点炮的人。不预先猜，让用户自己点，免得记错人。
    var discarder: Int?
    /// 点过「自摸」或某个人点炮。没点之前按自摸算番，但不能记账。
    var wayChosen = false
    /// 这手牌用户动手改过几次（换、加、删、确认拿不准的）。离线认牌改得多时，核对页提一句邀请码。
    var corrections = 0
    var specials: Set<SpecialWin> = []
    /// 手动增减的宝牌差额，加在自动数出来的张数上。
    var flowerCount = 0
    /// 翻出来的宝牌指示牌，含杠宝牌。
    var doraIndicators: [Tile] = []
    /// 翻出来的里宝牌指示牌，只有立直和牌才算。
    var uraIndicators: [Tile] = []
    /// 除和牌者外，本局也宣告立直并投出 1000 点立直棒的玩家。
    var riichiPlayers: Set<Int> = []
    var showResult = false

    /// 每次识别一个编号；中途重拍了，旧的结果回来时丢掉。
    @ObservationIgnored private var recognitionID = UUID()
    /// 端侧结果里的花牌数；复核期间用户改过花牌就不用 Gemini 的覆盖。
    @ObservationIgnored private var previewFlowerCount: Int?
    @ObservationIgnored private var suggestionCache: (hand: Hand, context: WinContext, value: [FixSuggestion])?

    init(game: Game, presetDiscarder: Int? = nil) {
        self.game = game
        self.winner = game.dealer
        if let presetDiscarder { pickDiscarder(presetDiscarder) }
    }

    // MARK: 手牌

    var hand: Hand {
        let concealed = tiles.map(\.tile)
        let index = winningIndex.flatMap { concealed.indices.contains($0) ? $0 : nil } ?? concealed.indices.last
        return Hand(melds: melds, concealed: concealed, winningTile: index.map { concealed[$0] })
    }

    var context: WinContext {
        var context = game.winContext(for: winner)
        context.selfDrawn = selfDrawn
        context.flowerCount = flowerCount
        context.doraIndicators = doraIndicators
        context.uraIndicators = uraIndicators
        SpecialWin.apply(specials.filter { isAvailable($0) }, to: &context)
        return context
    }

    var scoring: Result<ScoringResult, ScoringError> { FanCalculator.score(hand, context: context) }

    /// 牌型成立并且够起和番。
    var isValidWin: Bool {
        if case .success(let result) = scoring { return result.meetsMinimum(game.rules.minimumFan) }
        return false
    }

    // MARK: 宝牌

    var doraTotal: Int { context.doraBreakdown(for: hand).total }

    /// 核对页的加减号改的是总数，自动数的张数不动，差额记在 `flowerCount`。
    func stepDora(by delta: Int) {
        guard doraTotal + delta >= 0 else { return }
        flowerCount += delta
    }

    /// 这手牌里有 5 的花色，只有这些能标赤五。
    var redFiveSuits: [Suit] {
        [Suit.characters, .dots, .bamboo].filter { suit in hand.allTiles.contains { $0.suit == suit && $0.rank == 5 } }
    }

    func hasRedFive(_ suit: Suit) -> Bool {
        hand.allTiles.contains { $0.suit == suit && $0.isRed }
    }

    /// 打开时把这种花色的第一张 5 标成赤五；关掉时全部还原。
    func setRedFive(_ suit: Suit, on: Bool) {
        var pending = on
        for i in tiles.indices where tiles[i].tile.suit == suit && tiles[i].tile.rank == 5 {
            tiles[i].tile = tiles[i].tile.marked(red: pending)
            pending = false
        }
        for i in melds.indices where melds[i].tiles.contains(where: { $0.suit == suit && $0.rank == 5 }) {
            melds[i].redCount = pending ? 1 : 0
            pending = false
        }
    }

    // MARK: 谁和了、怎么和的

    func pickWinner(_ player: Int) {
        winner = player
        winnerChosen = true
        riichiPlayers.remove(player)
        // 点炮的人不能是和牌的人：原来选的点炮者变成了和牌者，就得重新选
        if !selfDrawn && discarder == player {
            discarder = nil
            wayChosen = false
        }
    }

    func pickSelfDrawn() {
        selfDrawn = true
        discarder = nil
        wayChosen = true
    }

    func pickDiscarder(_ player: Int) {
        selfDrawn = false
        discarder = player
        wayChosen = true
    }

    var pendingReviewCount: Int { tiles.filter(\.needsReview).count }

    /// 第一张还拿不准的牌，核对页一次问一张。
    var firstPending: Int? { tiles.firstIndex(where: \.needsReview) }

    /// 底部按钮不能点时的原因；nil 表示可以看结果了。
    var blockedReason: String? {
        if isReviewing { return tr("稍等几秒", "確認中…", "Just a moment…") }
        if tiles.isEmpty { return tr("先把牌加上", "まず牌を追加してください", "Add tiles first") }
        if pendingReviewCount > 0 { return tr("还有 \(pendingReviewCount) 张没确认", "残り\(pendingReviewCount)枚の確認が必要です", "\(pendingReviewCount) tile(s) need confirmation") }
        switch scoring {
        case .failure:
            return tr("先把牌改对", "まず手牌を修正してください", "Fix the hand tiles first")
        case .success(let result) where !result.meetsMinimum(game.rules.minimumFan):
            return result.fanWithoutFlowers == 0
                ? tr("无役，和不了", "役なし（和了不可）", "No yaku (cannot win)")
                : tr("不够 \(game.rules.minimumFan) 翻役，和不了", "\(game.rules.minimumFan)翻縛りを満たしていません", "Below \(game.rules.minimumFan)-han minimum")
        case .success:
            break
        }
        if !winnerChosen { return tr("选一下谁和了", "和了した人を選んでください", "Select the winner") }
        if !wayChosen { return tr("选一下怎么和的", "ツモかロンか選んでください", "Select Tsumo or Ron") }
        if !selfDrawn && (discarder == nil || discarder == winner) { return tr("选一下是谁点的炮", "放銃した人を選んでください", "Select who dealt in") }
        return nil
    }

    /// 改牌建议（算一次要试几百种改法，按手牌缓存）。
    var suggestions: [FixSuggestion] {
        let hand = hand, context = context
        if let cache = suggestionCache, cache.hand == hand, cache.context == context { return cache.value }
        let value = WinAssistant.fixSuggestions(for: hand, context: context, minimumFan: game.rules.minimumFan)
        suggestionCache = (hand, context, value)
        return value
    }

    /// 把第 `index` 张换成 `tile` 以后能不能和（只看这一张，别的牌按现在的读法）。
    func wins(with tile: Tile, at index: Int) -> Bool {
        guard tiles.indices.contains(index) else { return false }
        var concealed = tiles.map(\.tile)
        concealed[index] = tile
        let winning = winningIndex.flatMap { concealed.indices.contains($0) ? concealed[$0] : nil } ?? concealed.last
        return wins(Hand(melds: melds, concealed: concealed, winningTile: winning))
    }

    /// 把第 `index` 张删掉以后能不能和（只有一边读到的牌，问「照片里有没有这张」时用）。
    func wins(removing index: Int) -> Bool {
        guard tiles.indices.contains(index) else { return false }
        var concealed = tiles.map(\.tile)
        let winning = winningIndex.flatMap { $0 != index && concealed.indices.contains($0) ? concealed[$0] : nil }
        concealed.remove(at: index)
        return wins(Hand(melds: melds, concealed: concealed, winningTile: winning ?? concealed.last))
    }

    private func wins(_ candidate: Hand) -> Bool {
        if case .success(let result) = FanCalculator.score(candidate, context: context) {
            return result.meetsMinimum(game.rules.minimumFan)
        }
        return false
    }

    func isAvailable(_ special: SpecialWin) -> Bool {
        special.unavailableReason(hand: hand, selfDrawn: selfDrawn) == nil
    }

    // MARK: 识别

    /// 识别。双读时端侧结果一出来就进核对页（牌面先锁住），Gemini 复核完再换成合并后的结果。
    func recognize(with recognizer: TileRecognizer) async {
        guard let photo, let data = photo.jpegData(compressionQuality: 0.85) else { return }
        let id = UUID()
        recognitionID = id
        isRecognizing = true
        recognitionError = nil
        defer {
            if recognitionID == id {
                isRecognizing = false
                isReviewing = false
            }
        }
        let request = RecognitionRequest(image: data)
        do {
            let recognition: Recognition
            if let progressive = recognizer as? ProgressiveTileRecognizer {
                recognition = try await progressive.recognize(request) { [weak self] preview in
                    await self?.showPreview(preview, id: id)
                }
            } else {
                recognition = try await recognizer.recognize(request)
            }
            guard recognitionID == id else { return }
            // 复核期间用户改过花牌数，就以用户的为准
            let userFlowers = previewFlowerCount.flatMap { $0 != flowerCount ? flowerCount : nil }
            load(recognition)
            if let userFlowers { flowerCount = userFlowers }
            steps = [.check]
        } catch {
            guard recognitionID == id else { return }
            recognitionError = (error as? RecognitionError)?.message ?? error.localizedDescription
        }
    }

    private func showPreview(_ preview: Recognition, id: UUID) {
        guard recognitionID == id else { return }
        load(preview)
        previewFlowerCount = preview.flowerCount
        isRecognizing = false
        isReviewing = true
        steps = [.check]
    }

    /// 回到拍照页重拍时调用：还没回来的识别结果不要了。
    func cancelRecognition() {
        recognitionID = UUID()
        isRecognizing = false
        isReviewing = false
    }

    func load(_ recognition: Recognition) {
        tiles = recognition.concealed
        melds = recognition.melds
        flowerCount = recognition.flowerCount
        source = recognition.source
        notes = recognition.notes
        winningIndex = tiles.indices.last
        previewFlowerCount = nil
        corrections = 0
        reviewAtLoad = recognition.reviewCount
        let resolution = RecognitionResolver.resolve(recognition, context: context, minimumFan: game.rules.minimumFan)
        recommended = resolution.recommended
        recommendedRemovals = resolution.removals
    }

    /// 跳过拍照：从空手牌开始手动输入。
    func startManualEntry() {
        load(Recognition(concealed: [RecognizedTile](), source: "手动输入"))
        steps = [.check]
    }

    // MARK: 修改

    func choose(_ tile: Tile, at index: Int) {
        guard tiles.indices.contains(index) else { return }
        tiles[index].tile = tile
        corrections += 1
        tiles[index].alternatives = []
        tiles[index].uncertain = false
        recommended[index] = nil
        recommendedRemovals.remove(index)
    }

    /// 补一张牌。补的是漏读的牌，和张不跟着跳；还没有和张时才用这张。
    func append(_ tile: Tile) {
        tiles.append(RecognizedTile(tile: tile))
        corrections += 1
        if winningIndex == nil { winningIndex = tiles.indices.last }
    }

    /// 在第 `index` 张后面插一张（漏读了中间的牌）。
    func insert(_ tile: Tile, after index: Int) {
        guard tiles.indices.contains(index) else { return append(tile) }
        tiles.insert(RecognizedTile(tile: tile), at: index + 1)
        corrections += 1
        if let w = winningIndex, w > index { winningIndex = w + 1 }
        shiftRecommendations(after: index, by: 1)
    }

    func remove(at index: Int) {
        guard tiles.indices.contains(index) else { return }
        tiles.remove(at: index)
        corrections += 1
        recommended[index] = nil
        recommendedRemovals.remove(index)
        shiftRecommendations(after: index, by: -1)
        // 和张在被删的牌后面时下标前移；删的就是和张时改用最右一张
        if let w = winningIndex {
            if w > index { winningIndex = w - 1 }
            else if w == index { winningIndex = tiles.indices.last }
        }
    }

    /// 推荐读法是按位置记的，插入或删掉一张后，后面的位置跟着挪。
    private func shiftRecommendations(after index: Int, by delta: Int) {
        func shifted(_ i: Int) -> Int { i > index ? i + delta : i }
        recommended = Dictionary(uniqueKeysWithValues: recommended.map { (shifted($0.key), $0.value) })
        recommendedRemovals = Set(recommendedRemovals.map(shifted))
    }

    func apply(_ suggestion: FixSuggestion) {
        if let index = suggestion.index {
            choose(suggestion.to, at: index)
        } else {
            append(suggestion.to)
        }
    }

    // MARK: 记账

    var winRecord: WinRecord? {
        guard winnerChosen, wayChosen,
              case .success(let result) = scoring, result.meetsMinimum(game.rules.minimumFan) else { return nil }
        // 拍照页回头改了和牌者时，之前选的点炮者可能就是和牌者本人，这时不能记账
        if !selfDrawn && (discarder == nil || discarder == winner) { return nil }
        return WinRecord(winner: winner, discarder: selfDrawn ? nil : discarder, hand: hand, context: context,
                         result: result, riichiPlayers: riichiPlayers.subtracting([winner]))
    }

    var deltas: [Int]? {
        guard let record = winRecord else { return nil }
        return Payment.winDeltas(
            winner: winner,
            discarder: record.discarder,
            dealer: game.dealer,
            totalFan: game.rules.paidFan(record),
            fu: record.fu,
            honba: game.currentHonba,
            pot: game.currentPot,
            riichiPlayers: record.riichiPlayers,
            rules: game.rules
        )
    }
}
