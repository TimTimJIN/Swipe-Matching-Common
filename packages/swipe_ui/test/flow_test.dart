import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:swipe_core/swipe_core.dart';
import 'package:swipe_ui/swipe_ui.dart';

/// Bounded alternative to pumpAndSettle: a focused text field's blinking
/// cursor keeps scheduling frames, so pumpAndSettle would never return.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _start(WidgetTester tester, DemoWorld world, String name) async {
  await tester.binding.setSurfaceSize(const Size(480, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(SwipeMatchingApp(
    api: world.api,
    branding: AppBranding(appName: name, seedColor: Colors.teal),
  ));
  await _settle(tester);
}

void main() {
  testWidgets(
      'hobby: button like matches, chat works, passed card never matches',
      (tester) async {
    final world = DemoWorld.hobby(peerDelay: Duration.zero);
    await _start(tester, world, '趣味仲間');

    expect(find.text('小川 はる'), findsOneWidget);
    expect(find.text('趣味'), findsOneWidget); // field label from config
    await tester.tap(find.text('興味あり'));
    await _settle(tester);
    expect(find.text('小川 はると成立しました'), findsOneWidget);

    // Swipe the next card left = pass.
    expect(find.text('佐伯 あおい'), findsOneWidget);
    await tester.drag(find.byType(SwipeCard), const Offset(-400, 0));
    await _settle(tester);
    expect(find.text('佐伯 あおい'), findsNothing);

    await tester.tap(find.text('成立・会話'));
    await _settle(tester);
    expect(find.text('小川 はる'), findsOneWidget);
    expect(find.text('佐伯 あおい'), findsNothing);

    await tester.tap(find.text('小川 はる'));
    await _settle(tester);
    expect(find.text('はじめまして！よろしくお願いします。'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'こちらこそ！');
    await tester.tap(find.byTooltip('送信'));
    await _settle(tester);
    expect(find.text('こちらこそ！'), findsOneWidget);
    await tester.runAsync(world.dispose);
  });

  testWidgets(
      'hobby: swiping right on someone who has not liked back only records',
      (tester) async {
    final world = DemoWorld.hobby(peerDelay: Duration.zero);
    await _start(tester, world, '趣味仲間');
    await tester.tap(find.text('見送り')); // pass 小川 はる
    await _settle(tester);
    await tester.drag(find.byType(SwipeCard), const Offset(400, 0)); // 佐伯
    await _settle(tester);
    expect(await tester.runAsync(world.api.listMatches), isEmpty);
    await tester.runAsync(world.dispose);
  });

  testWidgets(
      'work: approved application matches, unapproved one stays pending',
      (tester) async {
    final world = DemoWorld.work(ownerDelay: Duration.zero);
    await _start(tester, world, '仕事相談');
    expect(find.text('相談内容'), findsOneWidget);
    await tester.drag(
        find.byType(SwipeCard), const Offset(400, 0)); // listing_0
    await _settle(tester);
    expect(find.text('応募しました。承認されると成立します'), findsOneWidget);
    await tester.tap(find.text('応募する')); // listing_1, never approved
    await _settle(tester);

    await tester.tap(find.text('成立・会話'));
    await _settle(tester);
    expect(find.text('問い合わせの一次対応を整理'), findsOneWidget);
    expect(find.text('採用サイトの改善案を作成'), findsNothing);
    await tester.runAsync(world.dispose);
  });

  testWidgets(
      'work owner: approve opens a match, decline asks first, hobby has no tab',
      (tester) async {
    final world = DemoWorld.work(ownerDelay: Duration.zero);
    await _start(tester, world, '仕事相談');
    await tester.tap(find.text('届いた応募'));
    await _settle(tester);
    expect(find.text('架空 相談員あ'), findsOneWidget);
    expect(find.text('「あなたの相談（試用）」への応募'), findsNWidgets(3));

    await tester.tap(find.text('承認する').first);
    await _settle(tester);
    expect(find.textContaining('架空 相談員あさんの応募を承認しました'), findsOneWidget);
    expect(find.text('架空 相談員あ'), findsNothing);

    // Decline needs confirmation; "戻る" keeps the application.
    await tester.tap(find.text('見送る').first);
    await _settle(tester);
    expect(find.text('応募を見送りますか'), findsOneWidget);
    await tester.tap(find.text('戻る'));
    await _settle(tester);
    expect(find.text('架空 相談員い'), findsOneWidget);
    await tester.tap(find.text('見送る').first);
    await _settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, '見送る'));
    await _settle(tester);
    expect(find.text('架空 相談員い'), findsNothing);
    expect(await tester.runAsync(world.api.listIncomingApplications),
        hasLength(1));

    // The approved applicant appears in matches and has greeted.
    await tester.tap(find.text('成立・会話'));
    await _settle(tester);
    await tester.tap(find.text('架空 相談員あ（あなたの相談（試用））'));
    await _settle(tester);
    expect(find.text('承認ありがとうございます。よろしくお願いします。'), findsOneWidget);
    await tester.runAsync(world.dispose);
  });

  testWidgets('work owner: lost approval response does not create two matches',
      (tester) async {
    final world = DemoWorld.work(ownerDelay: Duration.zero);
    await _start(tester, world, '仕事相談');
    await tester.tap(find.text('届いた応募'));
    await _settle(tester);
    world.server.injectFault(Fault.afterCommit);
    await tester.tap(find.text('承認する').first);
    await _settle(tester);
    expect(find.text('通信結果を確認できませんでした。再送しても重複しません。'), findsOneWidget);
    expect(find.text('架空 相談員あ'), findsNothing); // committed; refreshed away
    final matches = await tester.runAsync(world.api.listMatches);
    expect(matches!.where((m) => m.candidateId == myListingId), hasLength(1));
    await tester.runAsync(world.dispose);
  });

  testWidgets('hobby: no owner tab for mutual-interest services',
      (tester) async {
    final world = DemoWorld.hobby(peerDelay: Duration.zero);
    await _start(tester, world, '趣味仲間');
    expect(find.text('届いた応募'), findsNothing);
    await tester.runAsync(world.dispose);
  });

  testWidgets(
      'chat: lost response shows retry and resending stores one message',
      (tester) async {
    final world = DemoWorld.hobby(peerDelay: Duration.zero);
    await _start(tester, world, '趣味仲間');
    await tester.tap(find.text('興味あり'));
    await _settle(tester);
    await tester.tap(find.text('成立・会話'));
    await _settle(tester);
    await tester.tap(find.text('小川 はる'));
    await _settle(tester);

    world.server.injectFault(Fault.afterCommit);
    await tester.enterText(find.byType(TextField), 'テスト');
    await tester.tap(find.byTooltip('送信'));
    await _settle(tester);
    expect(find.text('通信結果を確認できませんでした。再送しても重複しません。'), findsOneWidget);
    await tester.tap(find.text('再送'));
    await _settle(tester);
    final match = (await tester.runAsync(world.api.listMatches))!.single;
    final mine = (await tester.runAsync(() => world.api.messages(match.id)))!
        .where((m) => m.senderId == world.meId);
    expect(mine, hasLength(1));
    expect(find.text('テスト'), findsOneWidget);
    await tester.runAsync(world.dispose);
  });

  testWidgets('deck: failed decision keeps the card and retries with same key',
      (tester) async {
    final world = DemoWorld.hobby(peerDelay: Duration.zero);
    await _start(tester, world, '趣味仲間');
    world.server.injectFault(Fault.beforeCommit);
    await tester.tap(find.text('興味あり'));
    await _settle(tester);
    expect(find.text('小川 はる'), findsOneWidget);
    await tester.tap(find.text('再送'));
    await _settle(tester);
    expect(find.text('小川 はると成立しました'), findsOneWidget);
    await tester.runAsync(world.dispose);
  });
}
