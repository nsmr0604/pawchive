# Project Status & Roadmap

> 最終更新: 2026-11-20 10:15 JST  
> この文書は、ローカル環境の `notes/` や過去の会話を参照できない開発者・エージェントが、Pawchive の現状と次の作業を把握するための共有引き継ぎです。  
> 状態が変わったら、このファイルを実装・CI の実態に合わせて更新してください。

## 1. 現在の状態

- リポジトリ: [nsmr0604/pawchive](https://github.com/nsmr0604/pawchive)
- アプリ: PawKemoViewer (pawchive.pw の非公式クライアント)
- 技術構成: React 18 + TypeScript + Vite + Tauri 2 + Rust + reqwest
- 対象: Windows / Linux / macOS / Android
- main の既知バージョン: `0.3.2`
- 現在の作業 PR: [#7 UX/UI刷新と通信・描画処理の効率化](https://github.com/nsmr0604/pawchive/pull/7)
  - ブランチ: `improve/ux-ui-codebase`
  - 直近の追加機能: 設定画面の情報設計を整理し、キャッシュ項目を統合。ホーム投稿一覧のサービスフィルターと公式 `hide=(ai)` AI除外、クリエイター一覧の更新日 / 人気 / 名前ソートとサービスフィルター。ホームの任意タグフィルターは実装しない。Android CIで検出されたCreators.tsxの日時パース型エラーを修正
  - 直近の実装修正: 認証状態表示・開発者向けセッション設定 `0b0de94` / `22c9403`、未キャッシュ認証検証 `d9d870e` / `67f8805`、IDログイン文言・引き継ぎ更新 `a30455a` 以降。Creators.tsx の日時パース修正 `3f06879` も含む
  - AI除外は初期値 OFF。設定を localStorage / バックアップに保存し、ホームの一覧・検索 API に適用
  - 旧 head `cf48a4e` の Android Actions run `44640938963` は failure。`src/pages/Creators.tsx:28` の `Date.parse(string | number)` 型エラーで Frontend build が停止したため、修正コミット `3f06879` で `Date.parse(String(value))` に変更。後続の認証・ビルド分離変更に伴うAndroid run #161 / #165 / #168 / #170 / #172 は後続pushでcancelled。Android run #175 (`44645540679`, SHA `b0913a4`) は completed/cancelled。最新変更を含むCI成功は未確認。キャンセル理由はActions上で確認できていない
  - 状態: Open。2026-11-20 時点の最新HEAD `9720a1e` で GitHub API は `mergeable=true` を返却。競合は現時点で検出されていない
  - バージョン番号は変更していない
  - **マージしないこと。ユーザーから明示的な依頼があるまで PR は open のままにする。**
- PR #7 の Android Actions: [run 44634915879](https://github.com/nsmr0604/pawchive/actions/runs/44634915879)
  - 対象 SHA はドキュメント追加前の `8036d31bf7aa8f88583e154378551a6c3cc493b0`
  - 最新 run #175 (`44645540679`) は cancelled。TypeScript / Android / Cargo feature の成否は未確認
  - 成功・失敗は確定していない。作業開始時に Actions の最新状態を確認すること
- PC 向け Tauri workflow は現状 main への push でのみ実行される。PR #7 では PC ビルド未検証。マージして CI を起動してはならない。ユーザーの明示指示を待つ
- 実機での UI/UX の視覚確認は未完了

## ビルドフラグによる開発機能の分離 (2026-11-20)
- [x] フロントエンドの `DEBUG_DIAG` を `src/buildFlags.ts` に分離。`VITE_DEBUG_DIAG=1` のときだけ開発用チャンクを動的ロード
- [x] 開発用セッションID入力・検証・保存、詳細ログフォルダ操作、バックアップJSONダンプを `DeveloperDiagnostics.tsx` へ分離。製品版では lazy import 自体をビルド時に除去
- [x] 長文ログ分割を `debug-log.ts` へ分離し、詳細APIレスポンスログとファイルログをデバッグビルドだけでロード
- [x] 製品版ログは基本的な uncaught error / unhandled rejection / API失敗 (method/path/HTTP status) に限定。APIレスポンス本文や詳細スタックは記録しない
- [x] Rust の `debug_append_log` / `debug_open_log_folder` は既存 Cargo feature `debug-diag` のみで定義・登録。request/method/status/icon URL の `println!` も同 feature で囲み、製品版から除外
- [x] PC / Android の CI debug ビルドで `--features debug-diag` を注入。正式リリースは `VITE_DEBUG_DIAG=0` + Cargo feature 無し
- [x] `npm run tauri:dev` / `npm run tauri:android:dev` も `debug-diag` feature を指定。Vite `.env.development` でフロント診断を常時有効
- [ ] Android Actions run #173 (`44645386866`) でフロント・Rust双方の feature 分岐をビルド確認。PC PR workflow は未設定のため、PR段階ではAndroidのみ検証可能
- [ ] 製品版ビルド成果物を展開し、DeveloperDiagnostics / debug-log / debug Tauri commands が含まれないことを確認

## 開発項目の製品版オプトイン (2026-11-20)
- [x] 開発項目を「アプリ情報」のアプリバージョン表示直下へ移動
- [x] デバッグビルドでは開発項目を常時表示
- [x] 製品版では「開発項目」トグルを既定OFFで表示し、ON時だけ開発項目を展開。設定は `developerToolsEnabled` として保存
- [x] セッションIDの手動入力・検証・保存を製品版でも利用可能にし、保存時の設定変更イベントでログイン状態を再検証
- [x] Rust の `debug_append_log` / `debug_open_log_folder` は製品版にも登録。UIは既定で非表示とし、トグルON時にだけ操作可能
- [x] 開発項目トグルは `developerToolsEnabled` として通常設定に永続化。セッションID保存時は設定変更イベントでログイン状態を再検証し、無関係な設定変更では再検証しない
- [x] 製品版ではトグルOFFなら基本エラーログのみ。トグルON時は詳細ログ・API応答情報を動的ロードしてファイルへ追記
- [ ] 最新PR head `0175cb0` の Android CIで TypeScript / Rust / Android build を確認
- [ ] 製品版でトグルOFF時に開発項目が隠れ、ON時にセッションIDログインとログ操作が動くことを実機確認
## 2. PR #7 で実施した内容

### ログイン導線・開発者向け認証 (2026-11-20)
- [x] 通常ログインはpawchiveのID / パスワード方式。ログイン画面の入力ラベル・説明もID表記に統一
- [x] 設定 > アカウントに保存済みセッションのAPI検証結果を表示: 確認中 / ログイン済み / 未ログイン・無効 / 通信エラー。キャッシュを使わず毎回サーバーへ検証
- [x] セッションIDの手動入力・テスト・保存は通常アカウント欄から除去し、`DEBUG_DIAG` ビルド時のみ「開発・診断」内に表示
- [x] 診断ログ・ログフォルダ・バックアップダンプと開発者向けセッション設定を同じセクションに統合
- [x] ログイン画面から手動セッション設定へのリンクを削除し、セッション取得失敗時の案内も一般ユーザー向けに修正
- [ ] Android / PC で通常ログイン、セッション状態の表示、DEBUG_DIAG の開発者向け操作を実機確認
- [ ] Android Actions run `44644558325` (run #154、SHA `67f8805`) は次の push に伴い Android SDK setup 中に cancelled。最新の変更を含むCI成功は未確認

### 設定画面の情報設計 (2026-11-20)
- [x] 設定画面冒頭にカテゴリ構成と反映タイミングの説明を追加。セッションキーは保存ボタンが必要なことを明示
- [x] ナビゲーションとセクション見出しを「通信」「バックアップ」「キャッシュ・保存領域」に統一
- [x] クリエイター索引とクリエイターアイコンのキャッシュ管理をキャッシュセクションに集約
- [x] 日本語 / 英語の両方を更新
- [ ] Android / PC 実機でナビゲーション・小画面表示・各操作の視認性を確認

### UI / UX
- 設定画面の情報設計を再整理: キャッシュ関連項目を「キャッシュ」へ集約し、アイコンキャッシュを独立カテゴリから移動。ナビゲーション名と各セクション見出しを「通信 / バックアップ / キャッシュ・保存領域」に具体化し、画面冒頭に設定の反映タイミングに関する案内を追加
- デスクトップナビゲーションをアイコン中心の細いレールから、ラベル付きサイドバーへ変更
- モバイル / デスクトップでナビゲーションアイコンと選択状態を統一
- ヘッダーに現在の画面名とログイン / アカウント設定への導線を追加
- 設定画面にカテゴリーナビゲーションを追加
- フォーカス表示、タップ領域、カード、フォーム、余白、ライト / ダークテーマを調整
- 投稿カードとクリエイター一覧をキーボード操作可能に
- 日本語 / 英語のナビゲーション文言を追加
- 設定内の移動はボタン + `scrollIntoView` を使用。アプリの hash router と衝突する `<a href="#...">` は使用しない

### ホーム投稿一覧のフィルター
- [x] FANBOX / Patreon / すべて のサービスフィルターをクライアント側に実装
- [x] 任意タグ選択 UI は実装しない (公式 API の任意タグ検索はグローバル投稿一覧の契約として確認できていないため)
- [x] 設定にグローバル「AI投稿を除外」を追加。公式 API の `GET /posts?hide=(ai)` を利用し、ホームの一覧・検索に適用
- [x] AI除外設定は localStorage に永続化し、バックアップ対象の Settings に含める
- [ ] 公式 API の hide パラメーターが検索時・オフセットページング時も一貫して適用されるか実機で確認

### クリエイター一覧
- [x] 既存のクリエイター検索ページを一覧として拡張。サービス (すべて / FANBOX / Patreon) で絞り込み
- [x] API の `updated` による更新日順、`favorited` による人気順、名前順でソート
- [x] IndexedDB のクリエイター索引 v3 に `updated` / `indexed` / `favorited` を保存。v2以前の索引は API から再構築
- [x] 10万件規模の一覧を一度に描画せず、60件ずつ段階表示
- [ ] 実機で更新日時の単位・人気指標の意味・並び順を確認

### フォロー一覧のソート
- 最新投稿日・最終確認日・名前・フォロー順で並べ替え可能。各項目で昇順 / 降順を切替
- 最新投稿日と最終確認日は新着チェックのキャッシュを利用し、余計な通信は発生させない

### フォロー新着表示・既読キャッシュ
- フォロー中クリエイターの NEW 表示は公開日時が直近 7 日以内の投稿に限定
- IndexedDB の `seen` ストアに最新投稿情報・チェック時刻・最後に既読にした投稿 ID を保存し、画面再表示やアカウント再同期後も未読状態を復元
- 新着チェック結果の保存は readwrite transaction 内で既読 ID を読み直し、通信中に押された「既読」を古い値で上書きしない
- アカウント同期後にも新着チェックを実行し、同期で追加されたフォローも対象にする
- フォロー同期は既読キャッシュを削除しない。解除後に再フォローした場合も既読 ID が残るため、同じ投稿の NEW は復活しない

### パフォーマンス / 安定性
- Rust の reqwest Client を API / ログイン / blocking proxy 用にアプリ全体で再利用し、接続プールを共有
- 無限スクロールの 700ms 定期ポーリングを廃止し、scroll / resize イベントを `requestAnimationFrame` で集約
- API scheduler の重複 pump timer を抑止
- Home / Creators の検索で古いレスポンスが後から表示される競合を防止
- ウィンドウ幅変更時、768px ブレークポイントを跨いだ場合だけレイアウト状態を更新

### ドキュメント
- `docs/DEVELOPMENT.md` と `docs/API.md` のアプリ / React バージョン表記を実装に合わせて修正

### 変更ファイル
`src/App.tsx`, `src/components.tsx`, `src/styles.css`, `src/api.ts`, `src-tauri/src/lib.rs`, `src/pages/Home.tsx`, `src/pages/Creators.tsx`, `src/pages/Settings.tsx`, `src/locales/ja.json`, `src/locales/en.json`, `docs/DEVELOPMENT.md`, `docs/API.md` および関連ファイル。正確な一覧は PR #7 の Files changed を参照。

## 3. 次に行う作業

以下は優先順位付きの候補・未完了項目です。実装済みと誤認しないこと。着手時にコードと GitHub の最新状態を確認し、完了した項目は状態と根拠を更新する。

### P0 — PR #7 の検証と完了判断
- [x] PR #7 の Android Actions run `44640938963` の失敗ログを確認。原因は `src/pages/Creators.tsx:28` の `Date.parse` に `string | number` を渡す TypeScript エラー
- [x] 上記を `Date.parse(String(value))` に修正 (commit `3f06879`)
- [ ] Android Actions run `44641968656` (run #142、対象 SHA `89d835f`) は次の push に伴い Setup Node.js 前に cancelled。最新 docs-only head `31b2394` には新しい PR run が確認できず、今回の変更を含むビルド成功は未確認
- [ ] TypeScript / Frontend / Rust のチェック結果を確認
- [ ] PC ビルドは PR の現行 workflow では未検証であることを維持し、main への push が必要な場合もユーザーの許可なくマージしない
- [ ] Android 実機と PC でナビゲーション、設定カテゴリ移動、ログイン導線、ライト / ダークテーマ、キーボード操作、狭い画面幅を確認
- [ ] レイアウト崩れ、操作不能、コントラスト不足、タップ領域不足があれば PR #7 で修正
- [ ] 検証結果をこの文書に追記し、ユーザーが判断できる状態にしてからマージ可否を確認する

### P1 — フォロー同期の状態表示と失敗処理
- [x] NEW 表示を直近 7 日以内の投稿に限定し、既読状態を IndexedDB に永続化。アカウント再同期後も既読状態を復元し、同期中の既読操作との競合を防止
- [ ] Pawchive 側をフォロー情報の正 (canonical source)、ローカル保存をミラーとして扱う既存仕様を維持
- [ ] ログイン後の同期成功 / 失敗 / 未実行をユーザーが区別できる表示にする
- [ ] 同期失敗をログイン成功として誤認させない。再試行導線とエラー理由を検討
- [ ] 旧来のローカル単独 `toggleFollow` が残っていないか呼び出し元を監査し、全経路が canonical sync と整合することを確認
- [ ] 既存の一回限りのローカルデータ移行とアカウント同期の互換性を壊さない

### P2 — 投稿詳細の表示速度
- [ ] 投稿詳細を開いてから本文・メタデータ・画像一覧が表示されるまでを計測
- [ ] 先行表示できるデータと遅延ロード可能なデータを分離
- [ ] service / creatorId / postId の投稿コンテキストを維持し、詳細画像・改訂履歴等の取得で再利用
- [ ] 重複 API リクエストや不要な再レンダーを調査
- [ ] 既存の API scheduler / cache / cooldown を迂回しない

### P3 — 設定画面の情報設計
- [x] 設定カテゴリを利用目的に合わせて再整理。アイコンキャッシュをキャッシュカテゴリに統合し、ナビゲーション名を具体化
- [x] 設定画面冒頭にカテゴリと即時反映の案内を追加
- [ ] 個々の設定項目名と説明をさらに短く具体化し、専門用語には補足を付ける
- [ ] アカウント、表示、投稿、接続、データ、キャッシュ、診断、アプリ情報の分類が実際の利用目的に合うか確認
- [ ] 変更が即時反映か保存操作を要するかを明示
- [ ] 日本語 / 英語の文言、長いラベル、小画面での折り返しを確認

### P4 — データ / キャッシュの堅牢性
- [ ] キャッシュの保存・読み込み・破損時フォールバック・容量増大を監査
- [ ] バックアップ / 復元の不正データ検証と失敗時の安全性を確認
- [ ] 既読・お気に入り・フォロー・設定の既存データを失わない移行手順を維持
- [ ] データ削除・再構築の操作は対象と影響範囲を明示し、誤操作を防ぐ

## 4. 絶対に維持する設計・仕様

### ネットワーク / アーキテクチャ
- 正式構成は **React + Tauri 2 + Rust + reqwest の直接通信**。
- Cloudflare Pages / Workers / Functions / Wrangler / Reverse Proxy 等の中継インフラを導入・提案しない。Cloudflare 由来の中継は pawchive 側で Fake site と判定される実測がある
- reqwest は `default-features = false` + `rustls-tls` を維持し、OpenSSL に依存させない
- Tauri v2 の JS → Rust コマンド引数は camelCase。Rust 側 snake_case のまま JS から渡さない
- pawchive API は `pawchive.pw/api/v1` に直接アクセスし、Swagger スキーマに準拠
- `pkv://` は FANBOX / Patreon の対象メディアに限って使用。pawchive 本体と `*.pawchive.pw` は常に直接通信
- pkv の Referer / User-Agent / host allowlist の制御を維持し、Pawchive の画像を pkv 経由で再試行しない
- API scheduler / cache / request spacing / concurrency 制限を維持
- Favorites の cooldown を維持
- API の意図的な未実装である `fancards` / `links` / GET flag を追加しない

### フォロー / 投稿コンテキスト
- フォロー情報は Pawchive 側が正。ローカルはミラー
- 初回のローカルデータ移行後はアカウント側と同期する。ローカル単独を正とする設計に戻さない
- 投稿 URL は `/post/{service}/{creatorId}/{postId}` の形式を検証し、undefined を含む URL を生成しない
- 投稿画面を開いた際の `service` / `creatorId` / `postId` を後続の詳細・画像・改訂履歴取得に引き継ぐ

### セキュリティ / リリース
- セッションキー、パスワード、API キー、正式署名鍵などの秘密情報をソース・ドキュメント・コミット・ログへ記録しない
- ビルドは GitHub Actions を正とし、成功を確認する前に「ビルド成功」と報告しない
- Android の debug keystore は公開標準値のもの。正式リリース鍵は GitHub Secrets で管理し、debug keystore を正式配布に使わない
- Windows 実行ファイルは現状未署名。将来 eMudhra コード署名を予定
- バージョンはユーザーのリリース方針に従い、依頼なしに変更しない

## 5. 変更履歴の要点

| PR / commit | 内容 | 状態 |
|---|---|---|
| PR #1 / `878c18a` | Pawchive を正とするクリエイターフォロー同期 | main に統合済み |
| PR #2 / `6513aec` | 投稿 URL 検証、service / creatorId / postId の記録と後続処理への引き継ぎ | main に統合済み |
| PR #3 / `2d0ad73` | 改訂履歴セレクター | main に統合済み |
| PR #4 / `e4f0908` | PC 同一バージョンビルドのクリーンアップ | main に統合済み |
| PR #5 / `d0868b0` | TypeScript ビルド修正 | main に統合済み。Android / PC Actions 成功確認済み |
| PR #6 | サムネイル優先表示、FANBOX cover.jpeg 除外、pkv proxy 制御修正 | この文書作成時点の統合状態は要確認。PR / main を確認すること |
| PR #7 | UX/UI 刷新、通信・描画効率化、直近 7 日のフォロー新着表示と既読キャッシュ改善 | Open。検証中。未マージ |

※ PR #6 の状態や PR #7 の CI は時間とともに変わるため、作業開始時に GitHub で必ず再確認する。

## 6. 作業開始・完了時のチェックリスト

### 作業開始時
1. `AGENTS.md` を読む
2. この `docs/PROJECT_STATUS.md` と関連する `docs/DEVELOPMENT.md` / `docs/API.md` / `docs/BUILD.md` を読む
3. GitHub の main、対象 PR、Actions の最新状態を確認する。ここに書かれた SHA / 状態を最新と決めつけない
4. 変更対象のコードと呼び出し元を追い、既存仕様への影響を把握する
5. 既存の PR があれば新規ブランチや重複 PR を作る前に、そのブランチ上で継続できるか確認する

### 作業完了時
1. 実装内容・未実施項目・検証結果・CI URL をこの文書に反映
2. 新しい仕様・制約・既知の罠は適切な開発ドキュメントにも追記
3. 変更を小さな単位でコミットし、秘密情報が含まれないことを確認
4. PR を作成 / 更新し、CI の最終結果を確認
5. マージ・リリース・バージョン変更はユーザーの明示指示を得る

## 7. ドキュメントの役割

- `AGENTS.md`: エージェント共通の作業規約と絶対制約
- `docs/PROJECT_STATUS.md`: 現在の進捗、未完了作業、改善ロードマップ、重要な引き継ぎ
- `docs/DEVELOPMENT.md`: アーキテクチャとコード構成
- `docs/API.md`: API / Tauri コマンド仕様
- `docs/BUILD.md`: ビルド・CI・リリース手順

このファイルはローカル専用 `notes/` の代替となる共有可能な要約であり、秘密情報やローカル端末固有の情報は記載しない。


## Lite / Full 開発機能の分離 (2026-11-20)
- [x] Lite: セッションIDの手動入力・API検証・保存。製品版にも含め、既存の「開発項目」トグルで表示
- [x] Full: 詳細ログファイル追記、ログフォルダを開く、バックアップJSONダンプ、APIレスポンス本文などの詳細ログ
- [x] Full UI は DEBUG_DIAG が有効なデバッグビルドだけで動的 import / 表示
- [x] Full の Rust コマンド debug_append_log / debug_open_log_folder は Cargo feature debug-diag の場合だけコンパイル・登録
- [x] 製品版で Lite を有効にしても Full は含まれず、詳細ログは無効
- [ ] 最新 Android Actions の成功と正式版構成のビルドを確認
- [ ] 製品版成果物に Full UI / Rust commands / debug-log が含まれないことを確認


> 2026-11-20 追記: Lite / Full の分離は上記の現行実装を正とする。以前の「製品版トグルで Full 診断も有効化」「Rust診断コマンドを製品版にも登録」という説明は無効。現行 PR head では Android run #202 より後に追加コミットがあり、head に対応する Actions 実行は未確認。


## Android API logcat (Full 開発機能 / 2026-11-20)
- [x] Rust `api_request` の開始時に HTTP method / URL を logcat へ出力
- [x] レスポンス受信後に HTTP status / 本文サイズ / 本文を出力。本文は UTF-8 境界を維持して約 3 KB ごとに分割
- [x] 接続エラーとレスポンス本文読取エラーも出力
- [x] Tauri log plugin の Android Stdout target を使用 (`log::info!` / `log::error!`)
- [x] Cookie / session ID / Authorization / ログインフォームの認証情報は出力しない。login_request はログ対象外
- [x] `debug-diag` feature で全出力コードを cfg 制御し、正式版ビルドから除外
- [ ] Android debug APK を実機で起動し、`adb logcat` で request / response body を確認
- [ ] Android release build (feature 無し) で Full ログコードが無いことをビルド確認


> Android API logcat 実装追記 (2026-11-20): `src-tauri/src/lib.rs` の `api_request` に Full 限定の request / response body / HTTP status / transport error ログを追加。Tauri log plugin の Android Stdout target を使用し、約3 KB の UTF-8 chunk 単位で出力。Cookie / session ID / Authorization / login form credentials は出力対象外。debug APK の logcat 実機確認と正式版ビルド確認は未実施。実装コミット `d7ec9d9`、Structured logger への整理 `cbea913`。


## HTTP プロキシ通信ヘッダーログ (Full / 2026-11-20)
- [x] Pawchive API `api_request`: 送信リクエスト / 受信レスポンスのヘッダーを Full logcat に記録
- [x] 外部 `pkv://` プロキシ: 実際に送信する reqwest Request の method / URL / ヘッダー、および応答 status / 全ヘッダーを記録
- [x] Cookie / Set-Cookie / Authorization / Proxy-Authorization / API key / auth token の値をマスキング
- [x] 外部 HTML / text / JSON / XML のレスポンス本文を記録。バイナリ本文は内容を記録せずサイズのみ記録
- [x] リクエスト本文は記録しない。ログインフォームを扱う `login_request` は対象外
- [x] すべて Cargo feature `debug-diag` でコンパイル制御し、正式版から除外
- [ ] Android 実機で Pawchive API と FANBOX / Patreon の両方を通信させ、ヘッダーの出力と秘匿値マスキングを確認
- [ ] Rust / Android CI の最新 head 結果を確認

> 2026-11-20 追記: 実装コミット `ac32792`、ログターゲットと本文ロガーの整理 `d0e84a3`。実機確認・CI確認は未実施。レスポンス本文には個人情報や投稿データが含まれ得るため、ログ共有前に確認すること。


> 最新追記 (2026-11-20): HTTP プロキシ通信ログを追加。Rust 実装 `ac32792`、ヘッダー秘匿値の追加マスキング `2b69049`、ロケール説明 `ca0d064` / `fc10fdc`。PR #7 head `fc10fdc` に対する Android Actions run #225 (`44648823060`) は確認時点で build job in progress。成功未確認。

> URL秘匿値対策 (2026-11-20): Full ログに出す URL の query parameter も token / secret / session / auth / api_key / signature 等のキーを検出して値をマスキング。実装コミット `f3f91df`。

## Lite / Full ネイティブ通信ログ・ファイル保存 (2026-11-20)
- [x] `app_data/logs/pawchive.log` にネイティブ通信ログを追記する共通ロガーを追加
- [x] Lite はエラーのみ。Pawchive API のエラーは宛先 URL とレスポンス本文のみ、接続失敗 / 本文読取失敗は宛先のみを logcat とファイルへ記録
- [x] Lite の外部 `pkv://` プロキシはエラーのみ記録
- [x] Full は Pawchive API / 外部プロキシの request / response / method / URL / status / 全ヘッダー / テキスト本文 / 通信エラーを logcat と `pawchive.log` の両方へ記録
- [x] Full 詳細ログは `debug-diag` feature に限定。Lite エラー記録は製品版でも利用
- [x] 秘匿ヘッダーと URL query の認証値はマスキング
- [ ] Android debug build / release build でログ出力と feature 除外を確認
- [ ] 実機で `logs/pawchive.log` の追記、再起動後の保持、logcat とファイルの内容一致を確認

> 実装コミット: 共通ファイルロガー `8815e58`、Lite API エラー / Full HTTP トレース統合 `31ed2db`、Lite API 出力の宛先・本文限定 `d3e139c`、URL parse の panic 回避 `86e2ffc`。CI / 実機確認は未実施。


> Lite ログ範囲の追加調整 (2026-11-20): `src/log.ts` で Lite の info / warn を破棄し、エラーのみリングバッファへ保持。API失敗の表示内容も宛先 URL + レスポンス本文のみに限定。実装 `0d06f2c`、正規表現修正 `6d83fde`。


## 通信ログのマスキング追加確認 (2026-11-20)
- [x] Full の API / 外部 pkv プロキシ URL ログは query の token / secret / session / auth / signature 等に加え、password / passwd / jwt をマスキング
- [x] URL user-info の username / password もログ出力前に除去
- [x] API transport error / response body read error の Full ログもサニタイズ済み URL を使用
- [ ] この修正を含む最新 Android Actions の完了結果を確認
- [ ] Android 実機で Lite / Full のログファイル・logcat・秘匿値マスキングを確認


## Full HTTP request body diagnostics (2026-11-20)
- [x] Full は pkv proxy の outgoing POST body も記録。text / JSON / form-urlencoded はチャンク分割し、password / passwd / token / secret / session / auth / credential / API key / JWT 等をマスキング
- [x] Pawchive login POST は request headers / redacted form body / response headers / response body を記録。username/password の値は記録しない
- [x] ログイン後の session validation API request / response と creator icon request / response headers を Full ログ対象に追加
- [x] request body は logcat と app_data/logs/pawchive.log の両方へ出力
- [ ] Rust / Android debug build の CI 完了確認と実機ログ検証が必要
- Note: api_request の現行 Tauri command は GET/POST/DELETE の method を受け取るが payload 引数を持たず、現状の API POST は空 body。将来 payload 引数が追加された場合は同じ request-body logger に接続すること。


## 0.4.0 リリース準備・マージ条件 (2026-11-20)
- ユーザー指示により、PR #7 の全変更をアプリバージョン **0.4.0** として main に統合する。
- `package.json` / `src-tauri/Cargo.toml` / `src-tauri/tauri.conf.json` の version を 0.4.0 に統一。関連する BUILD / DEVELOPMENT / API ドキュメントの表記と成果物例も 0.4.0 に更新。
- マージ条件: 0.4.0 に更新した最新 PR head に対する必須 GitHub Actions が正常完了することを確認してから PR #7 を main にマージする。実行中・未取得・cancelled は成功と扱わない。
- PR #7 は Android run #244 (ID: 44650139575) が進行中。これはバージョン更新前の run であり、最終マージ条件を満たさない。0.4.0 更新コミット後の run を改めて確認する。
- PC Tauri workflow は main push でのみ動作するため、PR 段階での PC ビルド成功を主張しない。マージ後に PC workflow の結果も確認し、失敗時は修正 PR / hotfix を行う。
- Android 実機 UI 確認と logcat / ログファイルの実機検証は CI ビルド成功とは別項目で、未実施のまま区別して報告する。
- この項目は従来の「マージしない」「ユーザーの明示指示を待つ」という記述を更新する。今回のユーザー指示により、上記条件達成後の PR #7 マージが承認されている。


## 0.4.0 マージ完了・main CI 確認中 (2026-11-20)
- [x] PR #7 の最新 head `2837c73950bfecc8cfe384584cc104991cb32d35` に対する Android Actions run #248 (`44650764660`) が **success**。Frontend build / Android initialization / APK build / APK signing / artifact upload がすべて成功。
- [x] 上記 CI 成功を確認後、PR #7 を squash merge。merge commit: `15403e13e3ccfe2c71b722db99242c32cc59602b`。
- [x] main の `package.json` と `src-tauri/tauri.conf.json` がともに `0.4.0` であることを確認。
- [ ] main push による Android Build run #249 (`44653227135`) の完了確認。
- [ ] main push による PC Tauri Build run #250 (`44653227249`) の完了確認。
- [ ] Wiki Sync run #251 (`44653227178`) の完了確認。
- 実機 UI / logcat / 永続ログファイルの検証は CI とは別であり、未実施。
- PR #7 は closed / merged。今後は main の最新 CI と実機検証結果をこの文書に追記する。


## Platform common foundation refactor (2026-11-20)
- User requirement: abstract all platform-dependent operations (storage, logging, database/cache, networking, permissions, export/share, clipboard/environment) behind a common foundation and implement actual OS work in platform adapters for desktop, Android and iOS.
- Primary is private app storage; Secondary is optional user-accessible storage. Supplemental language files load Primary then Secondary with Secondary overriding keys. Android Secondary is app-specific external storage under Android/data; iOS Secondary must be Files-accessible; desktop Secondary user-accessible. Normal logs remain Primary, dump exports Secondary. Developer-only JSON import UI, release hides import UI but continues reading Secondary language files.
- Added architecture/migration plan document `docs/PLATFORM_ABSTRACTION.md`. This is specification/roadmap only; no application code refactor is complete yet.
- Migration must be incremental and data-safe; preserve reqwest direct networking, API scheduler/cache, Favorites cooldown, canonical follow sync, PKV policy/redaction and Tauri camelCase.


## Platform-family intermediate layer and whole-codebase refactor (2026-11-20)
- User clarifies the intended architecture is common UI/components -> desktop/mobile intermediate processing layers -> OS-specific execution (Windows/macOS/Linux or Android/iOS). The whole codebase is in scope, not just storage/log export.
- Repository audit finds the intended family intermediate layer is not consistently present today: `src/platform.ts` is mainly UA/layout/clipboard helper; direct native invoke, IndexedDB/localStorage, logs and large Rust command module remain coupled across files. Details and phased target documented in `docs/PLATFORM_ABSTRACTION.md`.
- Target: common foundation contracts, Desktop family layer, Mobile family layer, OS-specific adapters; central adapter selection/capability reporting, avoid OS branching scattered through common code.
- PR #9 updated to include this audit and target architecture. This remains documentation/plan only; implementation not yet done.
