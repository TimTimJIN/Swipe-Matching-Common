# Swipe-Matching-Common

iPhone／Android 向けスワイプマッチングアプリを複数作るための共通基盤（Flutter）。

- 構成と設計方針：[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- 作業状況：[STATUS.md](STATUS.md)
- AI担当者向けルール：[AGENTS.md](AGENTS.md)

## 必要なもの

- Flutter 3.50 以上（Dart 3.14）。Material は `material_ui` パッケージを使う
- Android：Android SDK（Android Studio）。iOS：macOS と Xcode

## 使い方

```bash
flutter pub get
```

解析とテストはまとめて実行できます（Windows）。

```bash
powershell -NoProfile -File tools/check.ps1
```

個別に実行する場合：`dart analyze packages apps`、`packages/swipe_core` で `dart test`、`packages/swipe_ui` で `flutter test`。

```bash
cd apps/hobby_buddies && flutter run -d chrome
```

`apps/work_consult` も同じ手順で起動できます。どちらも架空データで動き、アプリを閉じるとデータは消えます。

## 新しい用途のアプリを追加する

1. `ServiceConfig` を定義する（表示項目、文言、成立ルールID）。
2. `MatchingApi` の実装を選ぶ（今は `InMemoryServer`、将来は実サーバー）。
3. `apps/<名前>/lib/main.dart` で `SwipeMatchingApp(api: ..., branding: ...)` を起動する。
