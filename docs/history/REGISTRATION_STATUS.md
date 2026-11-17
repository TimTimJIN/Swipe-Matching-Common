# 基盤登録状況

状態：未登録（既存基盤の保存先への書込み権限がないため停止）。

- 基盤：`C:\Users\hikar\Documents\ChatGPT\AI駆動×AI駆動\app-relay`
- 既存API：`workspace_hub.CaseStore.create`。既存案件一覧には同名案件なし。
- 登録試行：`cases`配下の新規ディレクトリ作成時にWinError 5。TASK.jsonの作成前に停止。案件IDは未確定。
- このチャットの作業場所はITコンサル・エンジニア。別プロジェクトへの書込み権限の追加機能は利用不可。
- 登録スクリプト：`register_case.py`。同じタイトルの既存案件があれば再利用し、重複があれば停止する。成功時だけHUB_REGISTRATION.jsonを作る。
- 未取得：編集権、作業状態、レビュー用スナップショット。登録済み・稼働中とは扱わない。
- 先行成果：`docs/CORE_AND_POC.md`。基盤外の現在の案件フォルダーで作成した設計案。

## 権限がある作業場所で再開する手順

1. 基盤側のAGENTS.md、WORKSPACE_HUB.mdと案件一覧を再確認する。
2. この案件のregister_case.pyを実行し、HUB_REGISTRATION.jsonのcase_idを確認する。
3. 作成先のAGENTS.md、TASK.json、STATUS.md、feedbackを読む。
4. work-state確認→Codexのclaim取得→既存資料をoutputsへ引き継ぐ。コピー後は正本と旧フォルダーの関係を記録する。
5. CORE_AND_POC.mdから実装準備を継続し、STATUS.mdに成果・未実施項目を記録する。区切りで停止要求を確認し、終了時にreleaseする。

既存基盤にAI自動起動・常駐処理・即時通知は未実装。登録が成功しても無人連続運転の開始を意味しない。Claude・Geminiレビューを模擬回答で代替しない。追加のモデルAPI課金は行わない。
