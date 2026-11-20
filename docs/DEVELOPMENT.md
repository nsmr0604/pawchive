# PawKemoViewer 開発ガイド

PawKemoViewer (v0.4.0) の開発者向けドキュメント。

- 対象読者: 開発参加者・ビルド担当者・コントリビューター
- ユーザー向け情報は [README.md](../README.md) を参照
- 関連: [BUILD.md](BUILD.md) (ビルド・CI)、[API.md](API.md) (API 仕様)、[LICENSES.md](LICENSES.md) (帰属)

## アーキテクチャ

```text
React 18.3.1 (TypeScript + Vite)
  ↓  invoke() (Tauri v2 コマンド)
Rust (reqwest / rustls)
  ↓  HTTPS
pawchive.pw / *.pawchive.pw
```

- **WebView は直接 fetch しない**。API・ログイン・アイコンはすべて Rust コマンド経由
  (端末 DNS ブロック・UA 偽装・Cloudflare 中継検出回避のためクライアント直叩き)
- 画像・動画は WebView が直接 CDN (`img/n1..n3/t1..t4.pawchive.pw`) を参照する。
  pkv:// プロキシの対象は FANBOX / Patreon 由来の画像のみ (pawchive 本体は迂回対象外・後述)
- **Cloudflare 系の中継 (Pages / Workers / Functions / Wrangler / Reverse Proxy) は禁止**。
  pawchive が中継を検出し Fake site を返すため (実測済み)

## 技術スタック

| 層 | 技术 | 備考 |
|---|---|---|
| UI | React 18.3.1 + TypeScript (strict) | 関数コンポーネント・hooks のみ |
| バンドラ | Vite 6 | PWA プラグイン不使用 |
| ランタイム | Tauri 2 | identifier `com.nsmr0604.pawkemoviewer` |
| バックエンド | Rust (edition 2024) + reqwest | `default-features = false` + rustls-tls (OpenSSL 不使用) |
| ストレージ | IndexedDB + localStorage | 詳細は後述 |

## ディレクトリ構成

```text
src/                    フロントエンド
  api.ts                API クライアント (スケジューラ・キャッシュ・URL 生成)
  db.ts                 IndexedDB (クリエイター索引パック・既読)
  icons.ts              クリエイターアイコンの多段キャッシュ
  follows.ts            フォロー (アカウント同期)
  favstate.ts           お気に入り投稿の共有状態
  backup.ts             バックアップ書き出し/読み込み
  log.ts                アプリ内ログ (リングバッファ)
  buildFlags.ts         ビルド時機能フラグ (VITE_DEBUG_DIAG)
  debug.ts              開発項目が有効な場合の Tauri ログ操作
  debug-log.ts          詳細ログ分割 (デバッグビルドのみ動的ロード)
  router.ts / hooks.ts / platform.ts / history.ts / types.ts / styles.css
  components.tsx        共通 UI (PostCard / PostRow / PostGrid / Thumb / CreatorAvatar / ErrorBox / fmtDate ほか)
  components/           FollowButton / NavigationRail / DeveloperDiagnostics (Lite) / DeveloperFullDiagnostics (Full: debug only)
  pages/                Home / Creators / CreatorPage / PostPage / Favorites / Login / Settings
src-tauri/
  src/lib.rs            Rust 実装 (コマンド・pkv:// プロキシ)
  src/main.rs           エントリポイント
  examples/probe_api.rs API 実測プローブ
  Cargo.toml            features: debug-diag
docs/                   本ドキュメント群
.github/workflows/      tauri.yml (PC) / android.yml (APK)
```

## 開発環境

- Node.js 24+ / npm 10+ / Rust 1.90+ (rustup) / Android SDK (実機テスト時)
- Windows の場合: VS BuildTools (C++) + Windows SDK
  - **注意: SDK の `um/x64` に dbghelp.lib が無い環境あり** → Windows SDK の該当ライブラリを補って対処する

```bash
npm install          # 依存
npm run dev          # Vite 開発サーバ (localhost:5173)
npm run tauri:dev    # Tauri 開発実行 (Cargo feature debug-diag)
npm run tauri:android:dev # Android 開発実行 (Cargo feature debug-diag)
npm run build        # 型検査 + 本番ビルド
cargo check --manifest-path src-tauri/Cargo.toml
cargo build --manifest-path src-tauri/Cargo.toml --features debug-diag   # 診断ビルド
```

## 重要な実装規約

### Tauri v2 コマンド引数は camelCase
Rust 側 snake_case → JS からは `sessionKey` 等。**snake_case で渡すと Option が常に None** になる (実害発生済み)。

### API 失敗のステータス復元
Rust は失敗時 `Err("STATUS=401 BODY=...")` 文字列を返し、JS 側は `ApiError(500)` で包む。
**ステータス分岐は必ず `apiStatus(err)` 経由** (`ApiError.status` は常に 500)。

### 既知の API 仕様癖 (実測)
- `GET .../revisions` は改訂なし投稿で **404 + `[]`** → 「改訂なし」扱いにする
- 詳細の `tags` は **PostgreSQL 配列リテラル文字列** (`"{\"one piece\"}"`) → `normalizeTags()` で正規化
- `account/favorites?type=post` は **PawPost 全フィールド** を返す (スリム形は artist のみ)
- 一覧のみ `substring` フィールドを持つ

### pkv:// プロキシ (`http://pkv.localhost/`)
WebView から Referer を設定できないため、リファラーチェックがある外部 URL を Rust 側で中継する。
`/file?u=<対象URL>&r=<リファラー>`。
対象は外部メディアホストのみ。pawchive 本体 (`pawchive.pw` / `*.pawchive.pw`) は除外し、常に WebView / Rust から直接取得する。
SSRF 対策 (内部アドレス拒否) あり。fanbox / patreon のホストは中継対象。
Referer は投稿の正規 URL (canonical) を優先して付与する。

### デバッグ診断コードはビルド時フラグ注入
`VITE_DEBUG_DIAG=1` (フロント) / Cargo feature `debug-diag` (Rust) をデバッグビルドで常に指定する。
通常の `tauri:dev` / `tauri:android:dev` と CI の debug ビルドで有効。正式リリースではフロントフラグを `0`、Cargo feature を指定しない。
Lite はセッションIDの手動入力・検証・保存で、製品版にも含めて設定トグルから利用可能。Full は詳細ログ・ログフォルダ操作・バックアップJSONダンプで、フロント DEBUG_DIAG と Rust `#[cfg(feature = "debug-diag")]` の双方により製品版からコンパイル除外する。
製品版に残すログは基本的な uncaught error / unhandled rejection / API 失敗の method・path・HTTP status のみ。レスポンス本文や詳細トレースは保存しない。

## ストレージ構成 (v0.3.0 のキー体系)

| 種別 | キー | 内容 |
|---|---|---|
| localStorage | `pawkemo-settings` / `pawkemo-follows` / `pawkemo-fav-tab` / `pawkemo-scroll` / `pawkemo-search-history` | 設定・フォロー・タブ状態・スクロール・履歴 |
| IndexedDB | `pawkemoviewer` (DB) | creators パック索引 / seen (既読) / meta |
| IndexedDB | `pawkemo-icons` (DB) | クリエイターアイコンの data URL キャッシュ |
| ファイル | `app_data/icons/` | Rust 側アイコンキャッシュ (`{service}_{id}.webp`) |
| バックアップ | type `pawkemoviewer-backup` | 設定+フォロー+既読 (旧 `pawchive-backup` は 0.2.x 系) |

- **0.2.x (旧 Pawchive Viewer) からの引継ぎはバックアップ書き出し→読み込み**が正式手順
  (identifier 変更によりデータディレクトリが別になるため)
- クリエイター索引は**単一パックレコード** (約 10 万行を 1 文字列化・decode 1 回でメモリ索引化)
- アイコンは メモリ → IndexedDB → Rust ディスク の 3 段キャッシュで再利用 (同一キーはリクエスト統合)

## パフォーマンス・負荷配慮

- API スケジューラ: 同時 3 / 最小間隔 250ms / GET キャッシュ TTL 60 秒 (最大 150 件)
- Favorites の新着チェックは 5 分クールダウン
- 画像は lazy loading + サムネ→本体の 2 段フォールバック (失敗時は非表示プレースホルダ)

## コーディング規約

- TypeScript `strict`。`any` 禁止 (`unknown` を使用)
- `unknown` / `any` を JSX の子にしない (boolean 化してから)
- IndexedDB への直書き禁止 (db.ts / icons.ts ヘルパー経由)
- コミットメッセージは端的に (規約は AGENTS.md 参照)

## トラブルシューティング

| 症状 | 対処 |
|---|---|
| `cargo metadata` 失敗 | `cargo --version` / `rustup update` |
| Windows リンクで dbghelp.lib 欠落 | 自作 lib (env.md の手順) |
| CI の Android が gradle 429 失敗 | Maven Central 一時障害。再実行で解消 (実測) |
| Android 実機で API・画像が出ない | 端末/ルーターの DNS フィルタ (AdGuard 等) が pawchive を sinkhole (偽 IP) に解決していないか確認 (`adb shell ping pawchive.pw`)。pawchive 本体は pkv:// 迂回の対象外のため、**DNS を通常の resolver へ変更するのが唯一の対処** |
| node_modules 破損 | `rm -rf node_modules package-lock.json && npm install` |
| Vite キャッシュ破損 | `rm -rf dist node_modules/.vite` |

## 参考資料

- Tauri 2: https://tauri.app
- Rust: https://www.rust-lang.org
- React: https://react.dev / Vite: https://vitejs.dev
- pawchive API 仕様: [API.md](API.md) および Swagger UI (https://pawchive.pw/api/schema)


### Lite / Full 開発機能
- Lite: セッションIDの手動入力・検証・保存。製品版にも含み、設定の開発項目トグルで表示する
- Full: 詳細ログ、ログフォルダ操作、バックアップJSONダンプ。フロント DEBUG_DIAG と Rust `#[cfg(feature = "debug-diag")]` によるデバッグビルド専用で、正式版にはコンパイルしない
- 詳細 API レスポンス本文のログも Full のみ。製品版では method / path / HTTP status の基本情報に限定する


### Android API logcat (Full only)
Android の Full デバッグビルドでは Rust の `api_request` がリクエスト開始・HTTP status・レスポンス本文を logcat に出す。本文は約 3 KB 単位で分割する。認証Cookie / session ID / Authorization / login form credentials は出力せず、ログイン処理は対象外。Tauri log plugin の Android Stdout target を使い、製品版では Cargo feature `debug-diag` 無しのため出力コード自体をコンパイルしない。


## Cross-platform foundation and adapter migration

See [PLATFORM_ABSTRACTION.md](PLATFORM_ABSTRACTION.md) for the target architecture, common contracts, Primary/Secondary semantics and phased migration. Platform-specific filesystem, logging sinks, DB persistence, HTTP execution, permissions and export/share operations should be behind adapters; common/domain code must depend only on common contracts. The migration is not yet implemented and must preserve current data and behavior.


## Platform-family architecture migration

The desired target is common UI/domain and services -> common contracts -> Desktop (Windows/macOS/Linux) or Mobile (Android/iOS) intermediate processing layer -> OS-specific adapter. The current code only has partial responsive/UI branching and a basic platform helper; it does not yet provide consistent intermediate service layers. The entire codebase is in scope (storage, logging, database/cache, networking, permission, export/share, clipboard, lifecycle/configuration). See [PLATFORM_ABSTRACTION.md](PLATFORM_ABSTRACTION.md) for the audit and staged plan.
