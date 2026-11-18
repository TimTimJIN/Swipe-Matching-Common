# 作業状況

更新：2026-11-18（日本時間） Claude Code

状態：共通基盤 v0.2 を実装済み（模擬バックエンド）。実機検証・実サーバー接続・独立レビューは未実施
現在の担当：Claude Code（実装）／Codex（レビュー）
編集権：作業後に返却済み。次に編集する担当が改めて取得する

## 経緯

- 2026-11-17 午後：Codexから移管（`docs/MIGRATION.md`）。
- 同日：ユーザーが「共通基盤をつくるまで進めて」と指示し、コード作成の保留を解除。構成の既定値（用途ごとに別アプリ＋共通パッケージ、最初は模擬バックエンド）を承認。Flutter SDK の導入（scoop、Flutter 3.50.0／Dart 3.14.0）も承認。
- 同日 18時ごろ：ユーザーの「登録して」の指示で、Google Drive に資料の写し4点、Notion（Claude OS）にプロジェクトとタスク12件を登録。
- 2026-11-18 00:53：ユーザーの「pushして」の指示で、`main` を GitHub（`TimTimJIN/Swipe-Matching-Common`、private）に push。
- 2026-11-18：ルールどおりに進められたかを確認し、次の逸脱を見つけた（いずれもユーザーの指示による作業で、同時編集は起きていない）。
  - 編集権を返した後に、コミット `f64c200`（11-17）・`3b1254a`（11-17）、`AGENTS.md` への追記（11-17）とコミット `3acc8b2`（11-18 00:52）、push（11-18 00:53）を、編集権なしで行った。
  - 移管時（11-17）、ファイルを書いた後に `confirm-direction` を記録した（正しくは書く前）。
  - 是正として、コミット・push も編集に含むことを `AGENTS.md` に明記した。仕組みでの再発防止は AI自律基盤の改修として別に扱う。
  - その後の 11-18 の作業（試作とレビュー、このリポジトリの整理）は、編集権を取得してから行った（11-18 01:00 ごろと 01:13 に取得）。
- 2026-11-18：AI自律基盤 ai-org（v0.2.0）の案件設定に切り替えた。`.ai-org.json` と git の設定 `ai-org.case` で案件に結び付け、手元専用の試作フック（`tools/relay*.ps1`、`.githooks`、`.claude/settings.json`）を外した。以後は git の共通フックと Claude Code のユーザー設定で編集権を確かめる。手順は `AGENTS.md`。
- 基盤の `work-state` の direction は、移管時の「コード作成・push は保留」のまま。上記のとおりユーザーがチャットで解除済み。案件画面での更新はユーザーに依頼している。

## 成果物

| 場所 | 内容 |
| --- | --- |
| `packages/swipe_core` | 純Dartの共通コア。設定、モデル、成立ルール、API契約、失敗型、模擬バックエンド、架空データ（各20件） |
| `packages/swipe_ui` | Flutterの共通画面。探す（スワイプ／ボタン）、成立・会話、通報・ブロック、退会、再送表示 |
| `apps/hobby_buddies` | 趣味仲間（人対人、相互の興味ありで成立） |
| `apps/work_consult` | 仕事相談（人対案件、オーナー承認で成立） |
| `docs/ARCHITECTURE.md` | 構成、共通と用途別の分担、守っている規則、未対応範囲 |
| `tools/check.ps1` | 解析とテストの一括実行 |

## 受け入れ条件の状況

| 条件 | 状態 | 証跡 |
| --- | --- | --- |
| 共通コードで2用途の表示項目と成立条件を切り替える | 達成（模擬） | 2アプリの `main.dart` は設定と見た目だけ。UIテスト「work: approved application…」「hobby: button like…」 |
| スワイプとボタンの両方で操作できる | 達成（テスト環境とブラウザー） | UIテストでボタンとドラッグの両方を確認。Chrome系ブラウザーの幅400pxでマウスのドラッグも確認 |
| 成立後に会話を試せる | 達成（模擬） | UIテストとブラウザーで送受信を確認 |
| 再送の検証 | 達成（模擬） | コアテスト「lost response can be retried safely」「message resend…」、UIテスト「chat: lost response…」「deck: failed decision…」 |
| 成立前の会話制限 | 達成（模擬） | コアテスト「non-participants cannot read or send」「one-sided like…」 |
| iPhone／Android 実機の結果 | 未実施 | Android SDK と macOS／Xcode が未準備 |
| Claude・Gemini 実モデルレビュー | 未実施 | 接続経路が未確定。Codexレビューも未実施 |

## 検証結果

- 2026-11-17：`dart analyze packages apps` 問題なし。コアのテスト21件、UIのテスト5件が成功。`flutter build web --release` は2アプリとも成功し、ブラウザー（幅400px）で、趣味仲間の成立・スワイプ・会話、仕事相談の応募・承認・成立一覧を目視確認。
- 2026-11-18：`tools/check.ps1`（info レベルも失敗扱い）で再実行し、同じ結果。
- 2026-11-18：手順とツールまわりの未 push コミット（check.ps1、.gitattributes、文書）を Claude 独立レビュー（Claude Code サブエージェント、レビューID 5852fe66…、再確認 98859a91…）に回し、重大指摘なし。指摘に対応済み。これは受け入れ条件の「Claude・Gemini 実モデルレビュー」（成果物のレビュー）とは範囲が違い、そちらは未実施のまま。
- 模擬バックエンドでの合格は、実DBでの合格を意味しない。

## 未決事項（ユーザーの判断が必要）

1. 実サーバーに何を使うか（Firebase、Supabase、独自API など）。
2. 実機検証の環境：Android SDK（Android Studio）の導入、iOS 用の macOS と Xcode。
3. 独立レビュー：Codex へのレビュー依頼の出し方（基盤の `snapshot` は外部リポジトリ非対応）と、Claude・Gemini 実モデルレビューの経路。
4. GitHub Issue を使うかどうか（push は 2026-11-18 に承認・実施済み。以後の push も都度承認）。
5. 最初の用途、市場、対象年齢。
6. 基盤の direction の更新（案件画面）。

## 次の作業

1. オーナー側の応募管理画面（API は対応済み）。
2. 実サーバー用の `MatchingApi` 実装と、同時成立・再送・ブロック競合の実DBテスト。
3. 写真・プッシュ通知の `PlatformAdapter`（必要になった時点で Swift／Kotlin）。
4. 実機での操作、VoiceOver／TalkBack、文字拡大の確認。
