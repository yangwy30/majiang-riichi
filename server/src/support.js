// /support：App Store 产品页的「App 支持」链接。常见问题和联系方式。
// 按浏览器语言给简体、繁体、英文、日文（?lang= 可以指定），说法跟 App 里的按钮一致。

import { page } from "./page.js";

const ZH_HANS = `
<h2>怎么用</h2>
<p>在「牌局」里点「开一局」，填四个人的名字和座位。有人和了就点「有人和了」，对着牌拍一张，核对牌面，选好谁和、谁放铳，再填宝牌指示牌和立直，就出番符、点数和这一局的点棒变动。流局点「记下流局」，选好谁听牌。半庄打完会自动结算，按顺位马和返点算出最终成绩；提前散场就在牌桌右上角「更多」里点「结束牌局」。</p>
<p>算点按日本麻将（立直麻将）的常见规则，跟天凤、雀魂一样：有食断、赤宝牌，25000 点起 30000 点返。开局时可以改这场的规则。</p>

<h2>AI 认牌要邀请码吗</h2>
<p>AI 认牌现在是邀请制，在底部「更多」里点「AI 认牌」，填 6 位邀请码。没有邀请码也能正常用：手机上的离线认牌照样能认，认不准的牌点一下就能改，也可以点「手动输入」自己选牌。赤五离线认牌分不出来，核对时点一下那张五换成赤五就行。</p>

<h2>认错了怎么办</h2>
<p>核对页上点那张牌，换成对的就行。看不清的牌会给两个候选，标出哪张能和。</p>

<h2>记错了一局</h2>
<p>在牌桌下面的账本里点那一局，能看那把是怎么和的，也能改，后面每一局的点数会跟着重算。</p>

<h2>换手机</h2>
<p>打开 iCloud 同步的话，换手机后用同一个 Apple ID 登录就会回来。也可以在底部「更多」里点「备份与换手机」导出文件，在新手机上导入。</p>

<h2>隐私</h2>
<p>不用注册、没有广告。详见<a href="/privacy">隐私说明</a>。</p>

<h2>联系</h2>
<p>有问题或建议，在 <a href="https://github.com/yangwy30/majiang-riichi/issues">GitHub</a> 上留言。</p>
`;

const ZH_HANT = `
<h2>怎麼用</h2>
<p>在「牌局」裡點「開一局」，填四個人的名字和座位。有人和了就點「有人和了」，對著牌拍一張，核對牌面，選好誰和、誰放銃，再填寶牌指示牌和立直，就出番符、點數和這一局的點棒變動。流局點「記下流局」，選好誰聽牌。半莊打完會自動結算，按順位馬和返點算出最終成績；提前散場就在牌桌右上角「更多」裡點「結束牌局」。</p>
<p>算點按日本麻將（立直麻將）的常見規則，跟天鳳、雀魂一樣：有食斷、赤寶牌，25000 點起 30000 點返。開局時可以改這場的規則。</p>

<h2>AI 認牌要邀請碼嗎</h2>
<p>AI 認牌現在是邀請制，在底部「更多」裡點「AI 認牌」，填 6 位邀請碼。沒有邀請碼也能正常用：手機上的離線認牌照樣能認，認不準的牌點一下就能改，也可以點「手動輸入」自己選牌。赤五離線認牌分不出來，核對時點一下那張五換成赤五就行。</p>

<h2>認錯了怎麼辦</h2>
<p>核對頁上點那張牌，換成對的就行。看不清的牌會給兩個候選，標出哪張能和。</p>

<h2>記錯了一局</h2>
<p>在牌桌下面的帳本裡點那一局，能看那把是怎麼和的，也能改，後面每一局的點數會跟著重算。</p>

<h2>換手機</h2>
<p>開啟 iCloud 同步的話，換手機後用同一個 Apple ID 登入就會回來。也可以在底部「更多」裡點「備份與換手機」匯出檔案，在新手機上匯入。</p>

<h2>隱私</h2>
<p>不用註冊、沒有廣告。詳見<a href="/privacy">隱私說明</a>。</p>

<h2>聯絡</h2>
<p>有問題或建議，在 <a href="https://github.com/yangwy30/majiang-riichi/issues">GitHub</a> 上留言。</p>
`;

const EN = `
<h2>How to use it</h2>
<p>On the Table tab tap “New Game” and enter the four players and their seats. When someone wins, tap “Record Win”, take a photo of the winning hand, check the tiles, pick the winner and who dealt in, add the dora indicators and riichi, and the app shows han, fu, the points and how everyone’s points change. For an exhaustive draw, record the draw and mark who was tenpai. When the hanchan ends the game settles automatically, with uma and oka applied. To stop early, tap “More” at the top right of the table, then “End Game”.</p>
<p>Scoring follows common riichi mahjong rules, the same as Tenhou and Mahjong Soul: open tanyao, red fives, 25,000 start and 30,000 return. You can change the rules for a game when you start it.</p>

<h2>Does AI tile reading need an invite code?</h2>
<p>AI tile reading is invite-only for now. Open the More tab, tap “AI Recognition” and enter a 6-character invite code. The app works fine without one: photos are still read on the phone, offline, any misread tile can be fixed with a tap, and you can tap “Manual Entry” to pick the tiles yourself. Offline reading can’t tell red fives apart, so tap that five on the check screen and switch it to red.</p>

<h2>A tile was misread</h2>
<p>On the check screen, tap the tile and swap it for the right one. If a tile is unclear, the app offers two candidates and marks which one completes the hand.</p>

<h2>A hand was recorded wrong</h2>
<p>Tap that hand in the ledger below the table. You can see how it was won and edit it, and every later hand is rescored.</p>

<h2>Moving to a new phone</h2>
<p>With iCloud sync on, sign in with the same Apple ID on the new phone and your games come back. You can also open the More tab and tap “Backup &amp; Restore” to export a file and import it on the new phone.</p>

<h2>Privacy</h2>
<p>No sign-up and no ads. See the <a href="/privacy?lang=en">privacy policy</a>.</p>

<h2>Contact</h2>
<p>For questions or suggestions, open an issue on <a href="https://github.com/yangwy30/majiang-riichi/issues">GitHub</a>.</p>
`;

const JA = `
<h2>使い方</h2>
<p>「対局」タブで「対局を始める」をタップし、4 人の名前と席を入れます。誰かが和了したら「和了（あがり）」をタップして手牌を撮影し、牌を確認して、和了者と放銃者、ドラ表示牌とリーチを入れると、翻・符・点数とその局の点棒の移動が出ます。流局は流局として記録し、聴牌者を選びます。半荘が終わると自動で精算し、ウマ・オカ込みの成績を出します。途中でやめるときは、卓の右上「その他」から「対局を終了する」をタップします。</p>
<p>点数計算は天鳳・雀魂と同じ一般的なリーチ麻雀のルール（喰いタンあり、赤ドラあり、25000 点持ち 30000 点返し）に沿っています。対局を始めるときにルールを変えられます。</p>

<h2>AI 読み取りに招待コードは必要？</h2>
<p>AI 読み取りはいまのところ招待制です。「その他」タブから「AI牌認識」をタップし、6 桁の招待コードを入れてください。コードがなくても普通に使えます。写真は端末内（オフライン）で読み取り、読み違えた牌はタップで直せます。「手入力」で自分で牌を選ぶこともできます。オフライン読み取りでは赤五を見分けられないので、確認画面でその五をタップして赤五に替えてください。</p>

<h2>牌を読み違えたとき</h2>
<p>確認画面でその牌をタップし、正しい牌に替えてください。はっきりしない牌には候補が 2 つ出て、どちらで和了になるかが示されます。</p>

<h2>局の記録を間違えたとき</h2>
<p>卓の下のスコア表でその局をタップすると、どう和了したかを見たり直したりでき、それ以降の局の点数も計算し直されます。</p>

<h2>機種変更</h2>
<p>iCloud 同期をオンにしていれば、新しい端末で同じ Apple ID にサインインすると対局が戻ってきます。「その他」タブの「バックアップ・機種変更」でファイルを書き出し、新しい端末で読み込むこともできます。</p>

<h2>プライバシー</h2>
<p>登録不要、広告なし。詳しくは<a href="/privacy?lang=ja">プライバシーポリシー</a>をご覧ください。</p>

<h2>お問い合わせ</h2>
<p>ご質問やご要望は <a href="https://github.com/yangwy30/majiang-riichi/issues">GitHub</a> でお寄せください。</p>
`;

export const SUPPORT_PAGES = {
  "zh-Hans": page("zh-Hans", "日麻算番 · 帮助", "日本麻将算点记账", ZH_HANS),
  "zh-Hant": page("zh-Hant", "日麻算番 · 說明", "日本麻將算點記帳", ZH_HANT),
  en: page("en", "Riichi Scorer · Help", "Score riichi mahjong from a photo", EN),
  ja: page("ja", "麻雀カメラ計算 · ヘルプ", "リーチ麻雀の点数計算と記録", JA),
};
