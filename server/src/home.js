// /：有人在浏览器里直接打开 riichi.acrossus.app 时看到的一页。一句话说这是什么，帮助和隐私。
// 上架以后：加回 App Store 下载按钮和 <meta name="apple-itunes-app">（国标版 majiang-ppc/server/src/home.js 里有现成的样式）。
// 样式跟 /support、/privacy 一样。按浏览器语言给简体、繁体、英文、日文。

const TEXT = {
  "zh-Hans": {
    name: "日麻算番", tagline: "日本麻将算点记账",
    description: "日本麻将（立直麻将）算点记账。和了拍一下，自动认牌、算番符和点数，四个人的点棒一局一局记好。完全免费，没有广告，不用注册。",
    lead: "日本麻将（立直麻将）算点记账。和了拍一下，自动认牌、算番符和点数，四个人的点棒一局一局记好，打完按顺位马和返点算出最终成绩。",
    free: "完全免费，没有广告，不用注册。iPhone 上用，即将上架 App Store。",
    help: "帮助", privacy: "隐私说明",
    sans: `-apple-system, "PingFang SC", "Noto Sans SC", sans-serif`,
  },
  "zh-Hant": {
    name: "日麻算番", tagline: "日本麻將算點記帳",
    description: "日本麻將（立直麻將）算點記帳。和了拍一下，自動認牌、算番符和點數，四個人的點棒一局一局記好。完全免費，沒有廣告，不用註冊。",
    lead: "日本麻將（立直麻將）算點記帳。和了拍一下，自動認牌、算番符和點數，四個人的點棒一局一局記好，打完按順位馬和返點算出最終成績。",
    free: "完全免費，沒有廣告，不用註冊。iPhone 上用，即將上架 App Store。",
    help: "說明", privacy: "隱私說明",
    sans: `-apple-system, "PingFang TC", "Noto Sans TC", sans-serif`,
  },
  en: {
    name: "Riichi Scorer", tagline: "Riichi mahjong scorer",
    description: "Score Japanese (riichi) mahjong from a photo. Snap the winning hand to read the tiles, count han and fu, and keep the score sheet. Free, no ads, no sign-up.",
    lead: "Score Japanese (riichi) mahjong. Snap the winning hand and the app reads the tiles, counts han and fu, keeps all four players\u2019 points hand by hand, and works out the final standings with uma and oka.",
    free: "Completely free, no ads, no sign-up. For iPhone, coming soon to the App Store.",
    help: "Help", privacy: "Privacy",
    sans: `-apple-system, "Helvetica Neue", sans-serif`,
  },
  ja: {
    name: "麻雀カメラ計算", tagline: "リーチ麻雀の点数計算",
    description: "リーチ麻雀の点数計算と記録。和了したら撮るだけで、牌を読み取り、翻と符を数え、点数を記録します。完全無料、広告なし、登録不要。",
    lead: "リーチ麻雀の点数計算と記録。和了したら撮るだけで、牌を読み取って翻と符を数え、4 人の点数を局ごとに記録し、最後にウマ・オカ込みの成績を出します。",
    free: "完全無料、広告なし、登録不要。iPhone 用、まもなく App Store で公開。",
    help: "ヘルプ", privacy: "プライバシー",
    sans: `-apple-system, "Hiragino Sans", "Noto Sans JP", sans-serif`,
  },
};

function homePage(lang) {
  const t = TEXT[lang];
  const q = lang === "zh-Hans" ? "" : `?lang=${lang}`;
  return `<!doctype html>
<html lang="${lang}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${t.name} · ${t.tagline}</title>
<meta name="description" content="${t.description}">
<style>
  :root { color-scheme: light; }
  body { margin: 0; background: #F7F6F2; color: #16150F;
    font: 16px/1.75 ${t.sans}; }
  main { max-width: 640px; margin: 0 auto; padding: 96px 20px 80px; }
  .seal { display: inline-flex; align-items: center; justify-content: center; width: 56px; height: 56px;
    background: #1E5B3A; color: #fff; border-radius: 13px;
    font: 700 34px/1 "Songti SC", "Noto Serif SC", serif; }
  h1 { font: 600 34px/1.3 "Songti SC", "Noto Serif SC", serif; margin: 28px 0 8px; letter-spacing: .04em; }
  .lead { color: #3A3933; font-size: 17px; margin: 0 0 8px; }
  .free { color: #6E6C64; font-size: 15px; margin: 0 0 40px; }
  nav { margin-top: 56px; padding-top: 20px; border-top: 1px solid #E7E4DC; font-size: 15px; }
  nav a { color: #6E6C64; text-decoration: none; margin-right: 24px; }
</style>
</head>
<body>
<main>
<span class="seal">立</span>
<h1>${t.name}</h1>
<p class="lead">${t.lead}</p>
<p class="free">${t.free}</p>
<nav><a href="/support${q}">${t.help}</a><a href="/privacy${q}">${t.privacy}</a></nav>
</main>
</body>
</html>
`;
}

export const HOME_PAGES = Object.fromEntries(Object.keys(TEXT).map((lang) => [lang, homePage(lang)]));
