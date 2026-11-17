# 共通基盤の構成 v0.2

状態：実装済み（模擬バックエンド）。実機検証、実サーバー接続、独立レビューは未実施。
前提（2026-11-17 ユーザー承認の既定値）：用途ごとに別アプリ＋共通パッケージ。最初はサーバーなしの模擬バックエンドで作り、後から Firebase や Supabase などに差し替える。

## フォルダー構成

```text
pubspec.yaml               Dart pub workspace（全パッケージを一括で解決）
packages/
  swipe_core/              純Dart。Flutterに依存しない
    lib/src/config.dart    ServiceConfig：用途ごとの表示項目・文言・成立ルールID・設定版
    lib/src/models.dart    会員、カード、意思表示、成立、応募、メッセージ、通報
    lib/src/rules.dart     成立ルール（相互の興味あり／オーナー承認）
    lib/src/api.dart       MatchingApi：アプリとバックエンドの契約、PlatformAdapter
    lib/src/errors.dart    共通の失敗型（入力、権限、設定版、競合、一時障害）
    lib/src/in_memory_server.dart  模擬バックエンド（認可・再送・一意性を実装）
    lib/src/demo.dart      架空データ各20件と、相手役の自動応答
  swipe_ui/                Flutterの共通画面
    lib/src/card_deck.dart カード表示（設定どおりに項目を描画）、スワイプ操作
    lib/src/controllers.dart 探す・成立一覧・会話の状態管理と再送
    lib/src/screens.dart   アプリ全体、探す、成立・会話、通報・ブロック、退会
apps/
  hobby_buddies/           趣味仲間（人対人）。main.dart は約20行
  work_consult/            仕事相談（人対案件）。main.dart は約20行
prototypes/flutter_prototype/  Codexの初期試作（参考資料、未使用）
```

## 共通にするものと差し替えるもの

| 層 | 共通（packages） | 用途ごと（apps または ServiceConfig） |
| --- | --- | --- |
| データ | 会員、カード、意思表示、成立、会話、通報、ブロック、退会 | カードの項目（FieldSpec） |
| ルール | ルールの実行、成立の一意性、会話の認可 | 使うルールID（mutualInterest／ownerApproval） |
| 画面 | 探す、成立一覧、会話、設定、エラーと再送の表示 | アプリ名、色、アイコン、肯定・否定の文言 |
| バックエンド | MatchingApi の契約と失敗型 | 実装（模擬、Firebase、Supabase、独自API） |
| OS固有 | PlatformAdapter の契約 | 必要になった時だけ Swift／Kotlin のプラグインで実装 |

新しい用途を作るときは、`ServiceConfig` を1つ定義し、`apps/` に `main.dart` だけの薄いアプリを追加します。共通パッケージは変更しません。

## 守っている規則（模擬バックエンドで実装、テスト済み）

- 成立はサーバー側で判定する。クライアントは成立を決めない。
- 成立は一意キー（人対人は2人の組、人対案件は案件と応募者）で1件だけ作る。
- 意思表示とメッセージは再送キー付き。同じキー・同じ内容なら同じ結果を返し、同じキーで内容が違えば競合として拒否する。
- 応答が失われた場合（`mayHaveCommitted`）は、同じキーで再送すれば重複しない。
- 別サービスのカード・会員・会話には触れられない。成立していない相手とは会話できない。
- ブロックが確定した後の送信は拒否し、成立を閉じる。
- 応募の承認は案件オーナーだけができる。
- 設定版が古い操作は拒否し、カードを残したまま設定を読み直す。
- 退会すると、カードを隠し、成立を閉じる。

## 未対応（次の段階）

- 実サーバー（認証、DB、同時実行、通知配信）。模擬バックエンドの合格は実DBの合格とみなさない。
- 写真、プッシュ通知、課金などのOS固有機能（PlatformAdapter の実装）。
- オーナー側の応募管理画面（API と模擬バックエンドは対応済み）。
- iPhone／Android 実機での確認と、VoiceOver／TalkBack の確認。
