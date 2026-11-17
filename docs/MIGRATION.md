# 移管記録

移管日時：2026-11-17 15:45頃（日本時間）
実施：Claude Code（基盤の編集権を取得して実施）
方法：元のファイルは消さずにコピーし、コピー元とコピー先のサイズと SHA256 が一致することを確認した。表の値はコピー時点のもの。

## コピーしたファイル

コピー元の略記：

- 旧作業場所 = `C:\Users\hikar\Documents\ChatGPT\ITコンサル・エンジニア\projects\swipe-matching`
- 基盤outputs = `C:\Users\hikar\Documents\ChatGPT\AI駆動×AI駆動\app-relay\cases\case-fb506404bfa84fc598380fe9564ea28e\outputs`

| コピー先 | コピー元 | サイズ | SHA256 | 一致 |
| --- | --- | --- | --- | --- |
| docs/SWIPE_MATCHING_CASE.md | 旧作業場所 docs/SWIPE_MATCHING_CASE.md | 21591 | E1BD17C4A988A37976F30C8AE1338B7C91A814182FC31A8DE85D52CD1AF1B870 | 一致 |
| docs/CORE_AND_POC.md | 旧作業場所 docs/CORE_AND_POC.md | 3510 | 98E64E9C4B6D259D1FC278B0EB1F6EF185BE4732778979BDA27BC3A55390CAF8 | 一致 |
| docs/REVIEW_CONNECTIONS.md | 旧作業場所 docs/REVIEW_CONNECTIONS.md | 2406 | 8C1FDA6D8D624A1275539D98423DDD850A91C0D64FE5A3BCF75654E8DE324E43 | 一致 |
| docs/CASE_TEMPLATE.md | 旧作業場所 docs/CASE_TEMPLATE.md | 2626 | 1B05458B4AC98E4FA535520CA529E8EA5CD10F805AB86157E4410E3E9822D10D | 一致 |
| docs/history/CLAUDE_CODE_HANDOFF.md | 旧作業場所 CLAUDE_CODE_HANDOFF.md | 4363 | F79CC31DC8E74B92C0FF42A595C709714F4D9A0137988F1935543D614EFCCD9A | 一致 |
| docs/history/REGISTRATION_STATUS.md | 旧作業場所 REGISTRATION_STATUS.md | 1893 | 1ACB1DEB31BD7ED08886F9A96892AA2267FE7E1B11F2823AA6F1A5A0D4AD8742 | 一致 |
| docs/history/PRIOR_WORKSPACE_README.md | 旧作業場所 README.md | 1319 | 793F649DF7DECCEDFE138D3F6B5C06C482B5F96988CACD5E3BA76C85BF58EF5F | 一致 |
| prototypes/flutter_prototype/pubspec.yaml | 基盤outputs flutter_prototype/pubspec.yaml | 297 | 9337D38594BFDC48D36BFD930973DB2AEAD318BC15BE7213E9A98E8FAB8A9BB1 | 一致 |
| prototypes/flutter_prototype/README.md | 基盤outputs flutter_prototype/README.md | 1916 | 9B8226A8CFE17C7E5BB4ACE6FB0DA1B70DE4C3F7C59B571E6FFBD87A00DA8359 | 一致 |
| prototypes/flutter_prototype/lib/main.dart | 基盤outputs flutter_prototype/lib/main.dart | 9957 | B5EE9E7CD556B31AA3BFE8B0991757893FAE1536096D71746F0408174DC656E7 | 一致 |
| prototypes/flutter_prototype/lib/matching.dart | 基盤outputs flutter_prototype/lib/matching.dart | 3260 | 99703D5CD911BFB21C57FE68E521E78F48CF211F6A675270DD162A8B573E5EDB | 一致 |
| prototypes/flutter_prototype/test/discover_test.dart | 基盤outputs flutter_prototype/test/discover_test.dart | 1299 | EEB47CC096D150E3EC1B832D18D47DBBB993E692B628B85D6A75E9D52183359A | 一致 |
| prototypes/flutter_prototype/test/matching_test.dart | 基盤outputs flutter_prototype/test/matching_test.dart | 1750 | 71E16A7EF345610EAD81C38F6FC74A8DC4EDB5A1EE6CFD94F6FBFB5A29A0C292 | 一致 |

基盤outputsの `SWIPE_MATCHING_CASE.md` は、旧作業場所の同名ファイルと SHA256 が同じため、1部だけコピーした。

Gitの改行変換（autocrlf）を使う環境では、コミット後に取り出したファイルのハッシュが上の値と変わることがある。照合するときは、作業ツリーのファイルとコピー元を比べる。

## 試作の扱い

`prototypes/flutter_prototype/` は、Codexが2026-11-17 13:42に基盤outputsへ作成したもの。実行・テスト・実機確認はしていない。コード作成の保留が解除されるまでは修正しない。

## コピーしなかったもの

| 対象 | 理由 |
| --- | --- |
| 旧作業場所 AGENTS.md | このリポジトリの `AGENTS.md` に置き換えた |
| 旧作業場所 register_case.py | 基盤への登録用の一時スクリプト。登録は済んでいる |
| 旧作業場所 swipe-matching.code-workspace | 旧作業場所専用のエディター設定 |
| 基盤の TASK.json・ROLES.json・STATUS.md・feedback・.editing | 基盤が管理する記録。編集権の記録（トークンを含むもの）は持ち出さない |

コピー前に、認証情報やトークンらしい文字列（APIキー、パスワード、トークンの代入など）がないことを検索で確認した。該当はなかった。

## 移管前の資料の状態

旧作業場所と基盤outputsのファイルは、そのまま残している。今後は更新しない控えとして扱う。
