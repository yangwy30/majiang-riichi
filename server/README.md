# 日麻算番的认牌中转站（Cloudflare Worker）

App 正式版不带 Gemini Key，认牌请求发到这里，由中转站带上 Key 转发给 Google。

**和国标版（拍照算番，`majiang-ppc/server`）分开**：代码是从那边复制过来的，但这是另一个 Worker（`majiang-riichi-relay`），
有自己的域名、自己的 Durable Object（邀请码、次数、意见都存在这里）和自己的管理密码。
两边的邀请码互不通用，限额分开算，部署这边不会动到国标版。国标版那边修了中转站的 bug，记得看看这边要不要跟着改。

- 地址：`https://riichi.acrossus.app`（域名 acrossus.app 是 Yang 在 Cloudflare 上已有的；没开 workers.dev 地址，中国大陆大多连不上）
  - `/recognize` 认牌，`/invite` 填码（见下面）
  - `/privacy` 隐私说明（`src/privacy.js`），`/support` 帮助页（`src/support.js`），上架时 App Store 产品页链这两页
  - `/` 在浏览器里直接打开域名时的介绍页（`src/home.js`）。还没上架，所以没有下载按钮；上架后加回去
  - `/admin` 邀请码管理网页，`/health` 回 `ok`
  - `/feedback`、`/misread` 是国标版「提意见」「认错了」用的，日麻 App 现在没有这两个功能，接口留着没用到
- 账号：Yang 的 Cloudflare（免费套餐够用）
- Key：Worker 密钥 `GEMINI_API_KEY`，不进代码、不进仓库。可以和国标版用同一个 Key，账单算在一起

## 第一次部署

在 Mac Mini 上，`server/` 目录里：

```sh
npm install
npx wrangler whoami                       # 确认登录的是 Yang 的 Cloudflare 账号（没登录就 npx wrangler login）
npm run deploy                            # 建 Worker、Durable Object，绑上 riichi.acrossus.app（第一次要等一两分钟证书）
tr -d '\n\r ' < ~/.config/gemini/api_key | npx wrangler secret put GEMINI_API_KEY
npm run admin-setup                       # 生成管理密码，打印管理网页地址
curl https://riichi.acrossus.app/health   # 回 ok 就好了
```

然后打开管理网页生成邀请码。

## 它做什么

1. App 把 Gemini `generateContent` 的请求体原样 POST 到 `/recognize`，带 `X-Majiang-Device`（手机的随机编号，存钥匙串）和 `X-Majiang-Invite`（邀请码，见下面）。
2. 检查：必须有设备编号；邀请码要对；请求体只能有 `contents`（1 到 3 轮，第一轮要有照片）和 `generationConfig`，不许带工具、系统提示词，最大 8 MB。这样别人拿到地址也没法当免费的通用 Gemini 用。
3. 计数（UTC 日期，一个 Durable Object 里的 SQLite）：每台手机每分钟 10 次、每天 150 次；每个 IP 每天 500 次；所有人加起来每天 1000 次。超了回 429。Google 出错（5xx、429）不扣每天的次数。
4. 转发给 `wrangler.toml` 里 `MODEL` 指定的模型，回答原样返回，响应头 `X-Majiang-Remaining` 是这台手机今天还剩几次。App 发来的 `X-Majiang-Model` 不算数。
5. 只放行 Flash / Flash-Lite（`src/models.js`），配置里写成 Pro 会直接报错，不会用。

## 邀请码

AI 认牌是邀请制：App 在请求头 `X-Majiang-Invite` 带上用户填的码，中转站查码，App 里的输入框只是入口，挡人靠这里。

- **码**：6 位，只用 `23456789ABCDEFGHJKLMNPQRSTUVWXYZ`（没有 0 O 1 I），不分大小写，空格和横线忽略。
- **填码**：App 先 POST `/invite`（`{"code":"…"}` + `X-Majiang-Device`），码对就把这台手机绑上，回 `{ok, code, dailyLimit, remaining}`。
- **限制**：每个码默认最多绑 2 台手机（`CODE_DEVICE_LIMIT`）、每天 50 次（`CODE_DAILY_LIMIT`），生成时可以单独改。原来按手机、IP、全站的限额照旧。同一个 IP 或手机每天输错 20 次（`INVITE_TRIES_PER_DAY`）以后，只认已经绑在这台手机上的码。
- **没码的请求**：一开始就要码（`INVITE_REQUIRED = "true"`），回 403。日麻 App 从第一版就有填码的地方，不用给旧版留过渡期。这个开关也能在管理网页上拨，不用重新部署。
- **码的问题**（没有、不对、停用了、手机绑满了）回 403，`error.invite` 是 `true`，App 收到就把存着的码清掉。次数用完回 429，不带 `invite`。

### 管理网页

`https://riichi.acrossus.app/admin`：生成码（可写「给谁」）、看每个码绑了几台手机、今天和一共用了几次、停用 / 重新启用、换手机时清掉绑定、拨「必须有邀请码」。

网页要管理密码，存在 Worker 密钥 `ADMIN_TOKEN` 里，和国标版的不是同一个。第一次设置（之后换密码也一样）：

```sh
npm run admin-setup   # 生成随机密码，存进 Worker 密钥和这台 Mac 的 ~/.config/majiang/riichi_admin_token，打印带密码的管理网页地址
```

打开打印出来的地址（`/admin#token=…`），密码会存进这个浏览器，以后直接开 `/admin` 就行。

上架审核：送审前生成一个「审核专用」码（比如 10 台手机、每天 200 次），写在 App Store Connect 的审核备注里，上架以后在网页上停用它。

中转站自己拒绝的请求回 `{"error":{"message":"…","majiang":true}}`，App 把 `message` 直接显示给用户。

计数和转发放在北美西部的 Durable Object 里（`LOCATION_HINT`），从那里调 Google，避开 Gemini 不支持的地区（比如香港机房）。

## 常用操作

都在 `server/` 目录里运行，第一次先 `npm install`。

```sh
npm test                 # 本地测试：假的 Gemini + wrangler dev
npm run deploy           # 部署（改了代码或 wrangler.toml 之后）
npx wrangler tail        # 看线上实时日志
```

- **换模型**：改 `wrangler.toml` 里的 `MODEL`，`npm run deploy`。App 不用更新。
- **改限额**：改 `wrangler.toml` 的 `[vars]`，`npm run deploy`。
- **发邀请码、停用**：管理网页 `/admin`，不用部署。
- **换 Key**：`tr -d '\n\r ' < ~/.config/gemini/api_key | npx wrangler secret put GEMINI_API_KEY`
