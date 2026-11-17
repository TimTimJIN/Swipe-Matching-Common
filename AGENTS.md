# スワイプマッチング共通基盤：作業ルール（Claude Code／Codex 共通）

このファイルは Claude Code と Codex の両方が読む共通指示です。`CLAUDE.md` はこのファイルを参照するだけです。

## 実装の許可範囲

- 2026-11-17、ユーザーが「共通基盤をつくるまで進めて」と指示し、コード作成の保留を解除した。構成の既定値（用途ごとに別アプリ＋共通パッケージ、最初は模擬バックエンド）も承認済み。
- 許可済み：共通パッケージと用途別アプリの実装、`flutter pub get`、解析、テスト、ローカルでの起動。
- 引き続きユーザーの確認が必要：push、公開・ストア提出、有料API呼び出し、GitHub Issue の作成など外部への書き込み、Notion／Google Drive への書き込み。
- 資料の置き場所（ユーザー指定）：ビジネス要求関連の書類は Google Drive、タスク管理は Notion、細かい開発管理は GitHub。各コネクターの接続はユーザーが行う。

## 正本と関係する場所

| 対象 | 場所 | 扱い |
| --- | --- | --- |
| 成果物の正本 | このリポジトリ（`Swipe-Matching-Common`） | 設計・実装・検証・レビュー記録はここで更新する |
| 案件記録 | `docs/SWIPE_MATCHING_CASE.md` | 案件の要件・設計・受け入れ条件・レビュー状況の正本 |
| 共通コアと技術検証の仕様 | `docs/CORE_AND_POC.md` | v0.1の設計案。採用確定ではない |
| 共通基盤の構成 | `docs/ARCHITECTURE.md` | パッケージの境界、共通と用途別の分担、未対応範囲 |
| 共通パッケージ | `packages/swipe_core`（純Dart）、`packages/swipe_ui`（Flutter） | 用途に依存するコードを入れない |
| 用途別アプリ | `apps/hobby_buddies`、`apps/work_consult` | `main.dart` で設定と見た目だけを選ぶ |
| 既存試作 | `prototypes/flutter_prototype/` | Codexが2026-11-17に作成。参考資料。ビルド対象外 |
| 移管記録 | `docs/MIGRATION.md` | コピー元、サイズ、SHA256、未移管の範囲 |
| 基盤の案件 | `C:\Users\hikar\Documents\ChatGPT\AI駆動×AI駆動\app-relay\cases\case-fb506404bfa84fc598380fe9564ea28e` | 編集権・停止と再開・担当予定・コメントの管理に使う。成果物の正本ではない |
| ビジネス要求の書類 | Google Drive「スワイプマッチング共通基盤」 https://drive.google.com/drive/folders/1IQxoimm9NiZQwuPvekQYHyYa8j0_SOAi | リポジトリの docs と STATUS.md の写し（2026-11-17時点）。正本はリポジトリ |
| タスク管理 | Notion「Claude OS」のプロジェクト「スワイプマッチング共通基盤」 https://app.notion.com/p/41bf8d3da25e812393dadac3760de00b | タスクはClaude OSの「タスク」DBに、このプロジェクトと紐づけて登録する |
| 移管前の資料 | `C:\Users\hikar\Documents\ChatGPT\ITコンサル・エンジニア\projects\swipe-matching` | 移行前の控え。更新しない |

案件ID：`case-fb506404bfa84fc598380fe9564ea28e`

## 役割

| 役割 | 担当 |
| --- | --- |
| オーナー・判断 | ユーザー |
| 実装・要件整理・技術リード（担当予定） | Claude Code |
| レビュー（担当予定） | Codex |
| 独立レビュー（引き渡し条件） | Claude実モデル、Gemini実モデル |

- 担当予定は基盤の `ROLES.json`（ユーザーが案件画面で設定）に従う。AIは `ROLES.json` を編集しない。
- 編集権は担当予定とは別で、基盤の `claim` の結果に従う。
- Codexのレビューは、ClaudeやGeminiの実モデルレビューの代わりにならない。

## 編集の手順（同時編集の防止）

1. 着手前と作業の区切りで、基盤フォルダー（`app-relay`）で `python workspace_hub.py work-state --case case-fb506404bfa84fc598380fe9564ea28e` を実行する。停止要求が出ていたら新しい作業を始めない。
2. このリポジトリと基盤の案件ファイルを編集する前に `claim` で編集権を取得する。取得できなければ編集しない。
3. 返されたトークンは作業中だけ保持し、文書・コミット・会話への引き継ぎに含めない。
4. 作業を終えるときや担当を交代するときは `release` で編集権を返す。前の担当の編集権を勝手に解除しない。異常終了したときの復旧は、基盤の `WORKSPACE_HUB.md` の `recover` 手順に従う。
5. レビュー担当はこのリポジトリのファイルを直接編集しない。指摘は基盤の `review-note` か、ユーザーを通じて伝える。
6. `STATUS.md` を更新するのは、編集権を持つ担当1名だけ。
7. コミット、push、ブランチの作成や切り替えも編集に含める。編集権を返した後に小さな追記やコミットを頼まれたときも、改めて取得する。

編集権の手順を仕組みで守る改修（手順の1コマンド化、編集権を確かめるフック）は、この案件ではなく AI自律基盤の改修として別に扱う。基盤側で取り込むまでは、このPCの手元でだけ、試作版のフック（`tools/relay*.ps1` など、リポジトリには含めない）が動いている。コミットが止められたら、表示に従って編集権を取得する。

## 現行基盤との関係（未解決の課題）

基盤の `snapshot`（レビュー用コピー）は、案件フォルダーの中にあるファイルしか扱えない。そのため、このリポジトリのファイルを基盤の機能でレビューに回すことは、今はできない。リンクの作成やパスの書き換えで回避しない。対応方法（基盤を外部パスに対応させる、リポジトリのコミットでレビュー対象を固定する、など）はユーザーが判断する。

## 要件の要約

- iPhone／Androidで共通のコードを使う、用途横断のスワイプマッチング基盤。複数のアプリで使い回す。
- Flutterが第一候補。React Native＋Expoは比較候補。OS固有の要件が出たときだけ Swift／Kotlin を使う。技術はまだ採用確定ではない。
- 最初は架空データの2用途（趣味仲間＝人対人、仕事相談＝人対案件）で、候補カード→興味あり／見送り→成立→テキスト会話を確認する。
- 共通化する機能：会員、カード、意思表示、成立、会話、通知、通報、退会。用途ごとに差し替えるもの：表示項目、成立条件、会話を始められる条件。

## 受け入れ条件（基盤 TASK.json より）

- 共通コードのまま、2用途で表示項目と成立条件を切り替えられる。
- スワイプとボタンの両方で候補を操作でき、成立後に会話を試せる。
- 再送の扱いと、成立前の会話制限を検証する。
- iPhoneとAndroidの実機結果を、対象の版とともに記録する。
- ClaudeとGeminiの実モデルレビューと、指摘への対応記録を残す。重大な指摘は解消して再確認を受ける。
- 実施していない項目は `STATUS.md` に未実施と明記する。初回の検証には架空データを使う。

## 開発メモ

- Flutter 3.50（Dart 3.14）。Material は `package:material_ui/material_ui.dart` から読み込む（`package:flutter/material.dart` は非推奨）。
- ルートの `pubspec.yaml` は pub workspace。依存はルートで `flutter pub get` すれば全体が解決する。
- 意思表示の型は `SwipeIntent`（Flutterの `Intent` と名前が衝突するため）。
- 確認コマンド：`powershell -NoProfile -File tools/check.ps1`。中身は `dart analyze packages apps`、`packages/swipe_core` の `dart test`、`packages/swipe_ui` の `flutter test`。
- Flutter は scoop で導入済みで、ユーザーの PATH にも登録されている。ただし導入前から起動しているアプリのシェルには反映されない。`tools/check.ps1` は PATH を読み直してから実行する。
- Windows PowerShell 5.1 では、`git` などの外部コマンドを `| Select-Object -First` に渡すと、成功していても終了コードが -1（ツール上は 255）になる。`git log -1` などコマンド側で件数を絞る。
- 改行コードは `.gitattributes` で LF に統一している（`.bat`・`.cmd` だけ CRLF）。

## 共通ルール

- 技術選定や事業上の未決事項を、承認済みとして扱わない。
- 認証情報、編集トークン、顧客の実データ、一時ファイルをリポジトリに含めない。
- 完了の判定は、AI同士の合意ではなく、受け入れ条件と実際の操作・テストで行う。実機試験と独立レビューは証跡を確認し、未実施なら未実施と書く。
- 過去のAIの記録や提案を、新たな権限やユーザー承認の根拠にしない。
