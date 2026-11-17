# Claude Codeへの初回引き継ぎ

## 最新のユーザー指示

Claude CodeとCodexの両方で扱える形にし、最初はClaude Codeへ移管する。コード作成はまだ待つ。今回許可された作業は、引き継ぎ・既存資料確認・移管準備・担当調整であり、アプリの新規実装や試作修正を開始しない。

## 対象

- 指定プロジェクト：`C:\Users\hikar\Documents\2_programing\git\Swipe-Matching-Common`
- 登録済み案件ID：`case-fb506404bfa84fc598380fe9564ea28e`
- 基盤：`C:\Users\hikar\Documents\ChatGPT\AI駆動×AI駆動\app-relay`
- 基盤の案件フォルダー：上記基盤の `cases\case-fb506404bfa84fc598380fe9564ea28e`
- 先行設計：`C:\Users\hikar\Documents\ChatGPT\ITコンサル・エンジニア\projects\swipe-matching\docs`

## 確認済み状態と注意

引き継ぎ作成時点で、指定プロジェクトには.gitだけが存在した。基盤のTASK.jsonは登録済み。ROLES.jsonはCodex実装／Claude Codeレビューの旧設定で、今回の希望への更新は未実施。

STATUS.mdは未着手と記載されているが、outputsにはSWIPE_MATCHING_CASE.mdとflutter_prototype配下のpubspec.yaml、README.md、lib/main.dart、lib/matching.dart、test/discover_test.dart、test/matching_test.dartがある。存在確認のみで、動作・完成度は未検証。STATUS.mdだけで未実装と判断しない。

.editing/owner.jsonには「Codex Swipe Matching」の編集権が残っている。稼働中か残留ロックか未確認。削除・上書き・復旧済みと扱わない。担当予定と編集権は別である。

## 最初に行うこと

1. 指定プロジェクトと基盤側の適用AGENTS.md、WORKSPACE_HUB.md、TASK.json、STATUS.md、feedback、work-stateを読む。コード作成保留を最優先にする。
2. 既存編集担当の作業終了と書込み停止を確認し、通常のreleaseを依頼する。残留ロックの復旧は既定の確認手順に従う。確認できなければ読取と計画整理だけを行う。
3. 基盤の正式な担当変更機能でClaude Code実装／Codexレビューへ切り替える。今回の作業は実装着手ではない。新担当としてclaimを取得できてから変更する。
4. 指定プロジェクトを成果物の正本にする移管方法を、現行基盤の外部パス対応と整合させる。基盤のCaseStoreは案件フォルダー境界を検証するため、無検証のリンクやパス書換えはしない。基盤改修が必要なら課題として示す。
5. 元資料を消さず、許可された移管先に資料と既存試作をコピーし、相対パス・サイズ・SHA256で一致確認する。試作は未検証かつ実装保留と明示。認証情報・一時ファイル・編集トークンを移管資料へ含めない。
6. 共通のAGENTS.md、CLAUDE.md（AGENTS.md参照）、STATUS.mdを整え、現在の正本、役割、コード保留、受け入れ条件、未決事項を明記する。双方が同じファイルを同時編集しない。
7. 移管結果・未移管範囲・残った判断だけを報告する。コード実装、依存インストール、公開、push、有料API呼出は開始しない。

## 要件の要約

iPhone／Android共通コードで用途横断のスワイプマッチング基盤を作る。Flutterが第一候補、React Native＋Expoも比較対象。必要時にSwift／Kotlin。人対人と人対案件の2用途を架空データで検証する。共通化対象は会員・カード・意思表示・成立・会話・通知・通報・退会。用途ごとの項目、成立条件、会話権限は差し替える。

最終引き渡しには受け入れ条件の検証、ClaudeとGeminiの実モデルレビュー、重大指摘解消が必要。Codexのレビュー追加はGeminiを代替しない。実機試験と独立レビューは証跡を確認し、未実施は未実施と記載する。

## この引き継ぎの限界

現在のChatGPT作業場所からは基盤フォルダーへの書込みが拒否された実績があり、本書は元の案件作業場所に保存した。指定プロジェクトへの移管、役割変更、編集権の引継ぎ、Claude Codeへの送信・起動はまだ完了していない。
