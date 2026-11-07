import SwiftUI
import MajiangKit

/// 四个 tab：牌局、记录、役表、更多。推进来的页（开局、结算、这一局）盖住 tab 栏。
struct MainTabs: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.selectedTab) {
            GameTab()
                .tabItem { Label(tr("牌局", "対局", "Table"), systemImage: "location.north.line") }
                .tag(AppTab.game)
            HistoryView()
                .tabItem { Label(tr("记录", "履歴", "History"), systemImage: "list.bullet.rectangle") }
                .tag(AppTab.history)
            RulesGuideView(embedded: true)
                .tabItem { Label(tr("役表", "役一覧", "Yaku"), systemImage: "character.book.closed") }
                .tag(AppTab.guide)
            MoreView()
                .tabItem { Label(tr("更多", "その他", "More"), systemImage: "slider.horizontal.3") }
                .tag(AppTab.more)
        }
        .tint(Theme.vermilion)
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// 第一个 tab：有没打完的牌局就是牌桌本身，没有就是开一局。
private struct GameTab: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let game = model.archive.activeGame {
            TableView(gameID: game.id, isRoot: true)
                .id(game.id)
        } else {
            EmptyGameView()
        }
    }
}

/// 第一次打开、或者打完一场之后：空桌加一个大按钮。
private struct EmptyGameView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PageTitle(title: tr("日麻算番", "麻雀カメラ計算", "Riichi Scorer"),
                          subtitle: tr("立直麻将 · 拍一下，翻符和点数都算好",
                                       "リーチ麻雀・撮るだけで翻符と点数を計算",
                                       "Snap the winning hand. Han, fu and points done."))
                CompassBoard.empty
                    .padding(.top, 20)
                ActionCard(symbol: "plus",
                           title: tr("开一局", "対局を始める", "Start a game"),
                           detail: tr("填好四个人的名字就能开始", "4人の名前を入れるだけ", "Just enter four names")) {
                    model.path.append(.newGame)
                }
                .padding(.top, 12)

                if let error = model.loadError {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.gray)
                        .padding(.top, 16)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
        .page()
    }
}

/// 主操作大卡片：藍底白字，左边一个符号，右边一个箭头。
struct ActionCard: View {
    var symbol: String
    var title: String
    var detail: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 26, weight: .regular))
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(Theme.heading(title, size: 20))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(detail)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 84)
            .background(Theme.indigo, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        }
        .buttonStyle(ActionCardPress())
    }
}

private struct ActionCardPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.82 : 1)
    }
}

/// 第二个 tab：打完的牌局。
struct HistoryView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PageTitle(title: tr("以前的牌局", "過去の対局", "Past games"), subtitle: nil)
                    .padding(.bottom, 12)
                if model.archive.finishedGames.isEmpty {
                    Text(tr("打完的牌局会放在这里，点开能看名次和转账。",
                            "終わった対局はここに残ります。順位と精算を確認できます。",
                            "Finished games appear here, with rankings and settlements."))
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.gray)
                        .padding(.top, 8)
                }
                ForEach(model.archive.finishedGames) { game in
                    Button {
                        model.path.append(.settle(game.id))
                    } label: {
                        HistoryRow(game: game)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
        .page()
    }
}

private struct HistoryRow: View {
    var game: Game

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(game.startedAt.dayLabel).font(.system(size: 16, weight: .medium))
                    Text(game.players.map(\.name).joined(separator: tr("、", "・", ", ")) + tr(" · \(game.playedHandsCount) 局", "・\(game.playedHandsCount)局", " · \(game.playedHandsCount) hands"))
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.gray)
                        .lineLimit(1)
                }
                Spacer()
                // 自己这场的输赢，前面写上名字，不用猜是谁的分
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(game.players[game.me].name)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.gray)
                        .lineLimit(1)
                    Text(Theme.signed(game.scores[game.me]))
                        .font(Theme.score(20))
                        .foregroundStyle(Theme.scoreColor(game.scores[game.me]))
                }
            }
            .padding(.vertical, 14)
            Hairline()
        }
        .contentShape(Rectangle())
    }
}

/// 第四个 tab：语言、备份、AI 认牌。
struct MoreView: View {
    @Environment(AppModel.self) private var model
    @State private var showBackup = false
    @State private var showInvite = false
    @State private var showSettings = false

    private var showsInvite: Bool { model.usesProxy || model.demoScreen == .invite || model.demoScreen == .more }

    private var language: Binding<AppLang> {
        Binding(get: { model.currentLang }, set: { model.appLanguage = $0.rawValue })
    }

    /// 「备份与换手机」那行下面的一句：iCloud 开没开。
    private var backupLine: String {
        model.cloud.enabled
            ? tr("iCloud 同步已打开", "iCloud同期オン", "iCloud Sync is on")
            : tr("导出、导入牌局，或者打开 iCloud 同步", "対局データの書き出し・読み込み・iCloud同期", "Export, import games, or enable iCloud Sync")
    }

    private var version: String {
        let info = Bundle.main.infoDictionary
        return "\(info?["CFBundleShortVersionString"] as? String ?? "1.0") (\(info?["CFBundleVersion"] as? String ?? "1"))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PageTitle(title: tr("更多", "その他", "More"), subtitle: nil)

                SectionLabel(tr("语言", "言語", "Language"))
                    .padding(.top, 24)
                    .padding(.bottom, 8)
                SegmentedSwitch(options: AppLang.allCases.map { ($0, $0.displayName) }, selection: language)

                VStack(spacing: 0) {
                    row(tr("备份与换手机", "バックアップ・機種変更", "Backup & Restore"), backupLine) { showBackup = true }
                    if showsInvite {
                        Hairline(color: Theme.lineSoft)
                        row(model.inviteCode != nil ? tr("AI 认牌 · 已开启", "AI牌認識・有効", "AI Recognition · Active") : tr("AI 认牌", "AI牌認識", "AI Recognition"),
                            model.inviteCode != nil ? tr("看邀请码，或者移除", "招待コードの確認・削除", "View or remove invite code") : tr("有邀请码就能开启，认牌更准", "招待コードでAI高精度認識を有効化", "Enter invite code for higher accuracy")) {
                            showInvite = true
                        }
                    }
                    #if DEBUG
                    Hairline(color: Theme.lineSoft)
                    // 开发版的设置（识别方式、API Key），正式版没有
                    row("开发设置", "识别方式、API Key") { showSettings = true }
                    #endif
                }
                .block()
                .padding(.top, 24)

                Text(tr("日麻算番 \(version) · 不用注册，没有广告",
                        "麻雀カメラ計算 \(version)・登録不要、広告なし",
                        "Riichi Scorer \(version) · No sign-up, no ads"))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.faint)
                    .padding(.top, 20)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
        .page()
        .sheet(isPresented: $showBackup) { BackupView() }
        .sheet(isPresented: $showInvite) { InviteView() }
        #if DEBUG
        .sheet(isPresented: $showSettings) { SettingsView() }
        #endif
        .onAppear {
            if model.demoScreen == .backup { showBackup = true }
            if model.demoScreen == .invite { showInvite = true }
        }
    }

    private func row(_ title: String, _ detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 16))
                    Text(detail)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.gray)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.faint)
            }
            .frame(minHeight: 66)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
