import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Page;
import 'package:swipe_core/swipe_core.dart';
import 'package:swipe_ui/swipe_ui.dart';

class _DelayedIncomingApi implements MatchingApi {
  _DelayedIncomingApi(this.api);

  final MatchingApi api;
  final reads = <Completer<List<Application>>>[];
  final decisionReadStarted = Completer<void>();

  @override
  Future<List<Application>> listIncomingApplications() {
    final read = Completer<List<Application>>();
    reads.add(read);
    if (reads.length == 2) decisionReadStarted.complete();
    return read.future;
  }

  @override
  Stream<MatchingEvent> events() => const Stream.empty();

  @override
  Future<Member> member(String id) => api.member(id);

  @override
  Future<Candidate> candidate(String id) => api.candidate(id);

  @override
  Future<Match> approveApplication(String id) => api.approveApplication(id);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _WorkApi extends _DelayedIncomingApi {
  _WorkApi(super.api, {this.readMe, this.approve, this.readMatches});

  final Future<Member> Function()? readMe;
  final Future<Match> Function(String)? approve;
  final Future<List<Match>> Function()? readMatches;

  @override
  Future<Member> me() => readMe?.call() ?? api.me();

  @override
  Future<ServiceConfig> fetchConfig() => api.fetchConfig();

  @override
  Future<Page<Candidate>> fetchCandidates({String? cursor, int limit = 10}) =>
      api.fetchCandidates(cursor: cursor, limit: limit);

  @override
  Future<List<Application>> listIncomingApplications() =>
      api.listIncomingApplications();

  @override
  Future<List<Match>> listMatches() => readMatches?.call() ?? api.listMatches();

  @override
  Future<Match> approveApplication(String id) =>
      approve?.call(id) ?? api.approveApplication(id);

  @override
  Future<List<Message>> messages(String matchId) => api.messages(matchId);
}

/// Bounded alternative to pumpAndSettle: a focused text field's blinking
/// cursor keeps scheduling frames, so pumpAndSettle would never return.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _start(WidgetTester tester, DemoWorld world, String name,
    {MatchingApi? api}) async {
  await tester.binding.setSurfaceSize(const Size(480, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(SwipeMatchingApp(
    api: api ?? world.api,
    branding: AppBranding(appName: name, seedColor: Colors.teal),
  ));
  await _settle(tester);
}

void main() {
  test('approval finishes when the latest incoming list does not respond',
      () async {
    final world = DemoWorld.work(ownerDelay: Duration.zero);
    final api = _DelayedIncomingApi(world.api);
    final controller = ApplicationsController(api,
        refreshTimeout: const Duration(milliseconds: 50));
    addTearDown(() async {
      controller.dispose();
      await world.dispose();
    });
    final initialApps = await world.api.listIncomingApplications();
    final initial = controller.refresh();
    api.reads.single.complete(initialApps);
    await initial;

    final entry = controller.entries.first;
    final id = entry.application.id;
    final decision = controller.approve(entry);
    await api.decisionReadStarted.future;
    final latest = controller.refresh();
    api.reads[1].complete(await world.api.listIncomingApplications());
    expect(await decision.timeout(const Duration(seconds: 2)), isNotNull);
    expect(controller.busy, isEmpty);
    final remainingIds = initialApps.map((app) => app.id).toSet()..remove(id);
    expect(controller.entries.map((row) => row.application.id).toSet(),
        remainingIds);

    final lateApps = await world.api.listIncomingApplications();
    final declined = lateApps.removeLast();
    await world.api.declineApplication(declined.id);
    api.reads[2].complete(lateApps);
    await latest;
    expect(controller.entries.map((row) => row.application.id).toSet(),
        remainingIds..remove(declined.id));
  });

  final lookupCases = <String, Future<List<Match>> Function()>{
    'no matching result': () async => [],
    'lookup fails': () async =>
        throw const TemporarilyUnavailableFailure('lookup failed'),
    'lookup times out': () => Completer<List<Match>>().future,
  };
  for (final lookup in lookupCases.entries) {
    test('unconfirmed approval remains actionable when ${lookup.key}',
        () async {
      final world = DemoWorld.work(ownerDelay: Duration.zero);
      var attempts = 0;
      final api =
          _WorkApi(world.api, readMatches: lookup.value, approve: (_) async {
        throw TemporarilyUnavailableFailure('approval unavailable',
            mayHaveCommitted: ++attempts == 1);
      });
      final controller = ApplicationsController(api,
          refreshTimeout: const Duration(milliseconds: 50));
      addTearDown(() async {
        controller.dispose();
        await world.dispose();
      });
      await controller.refresh();
      final entry = controller.entries.first;
      final id = entry.application.id;

      expect(await controller.approve(entry), isNull);
      expect(attempts, 2);
      expect(controller.entries.map((row) => row.application.id), contains(id));
      expect(
          controller.decisionError(id),
          describeFailure(const TemporarilyUnavailableFailure('unknown',
              mayHaveCommitted: true)));
      expect(controller.busy, isEmpty);
    });
  }

  test('approval stays busy until the latest overlapping refresh completes',
      () async {
    final world = DemoWorld.work(ownerDelay: Duration.zero);
    final api = _DelayedIncomingApi(world.api);
    final controller = ApplicationsController(api);
    addTearDown(() async {
      controller.dispose();
      await world.dispose();
    });
    final initialApps = await world.api.listIncomingApplications();
    final initialRefresh = controller.refresh();
    api.reads.single.complete(initialApps);
    await initialRefresh;

    final entry = controller.entries.first;
    final id = entry.application.id;
    final decision = controller.approve(entry);
    await api.decisionReadStarted.future;
    final latest = controller.refresh();
    api.reads[1].complete(await world.api.listIncomingApplications());
    await Future<void>.delayed(Duration.zero);
    expect(controller.busy, contains(id));

    api.reads[2].complete(await world.api.listIncomingApplications());
    await latest;
    expect(await decision, isNotNull);
    expect(controller.busy, isEmpty);
    expect(controller.entries.map((row) => row.application.id),
        isNot(contains(id)));
  });

  test('overlapping approvals return the outcome for each application',
      () async {
    final world = DemoWorld.work(ownerDelay: Duration.zero);
    final controller = ApplicationsController(world.api);
    addTearDown(() async {
      controller.dispose();
      await world.dispose();
    });
    await controller.refresh();
    final first = controller.entries[0];
    final second = controller.entries[1];

    world.server.injectFault(Fault.beforeCommit);
    final results = await Future.wait([
      controller.approve(first),
      controller.approve(second),
    ]);

    expect(results[0], isNull);
    expect(results[1]?.otherParty(world.meId), second.application.applicantId);
    expect(controller.entries.map((entry) => entry.application.id),
        contains(first.application.id));
    expect(controller.entries.map((entry) => entry.application.id),
        isNot(contains(second.application.id)));
    expect(
        controller.decisionError(first.application.id), '通信できませんでした。再送してください。');
    await controller.refresh();
    expect(controller.decisionError(first.application.id), isNotNull);
    expect(await controller.approve(first), isNotNull);
    expect(controller.decisionError(first.application.id), isNull);
  });

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

  testWidgets('work owner: failed approval retry recovers the existing match',
      (tester) async {
    final world = DemoWorld.work(ownerDelay: Duration.zero);
    // Disable simulation so its greeting cannot consume the injected faults.
    await tester.runAsync(world.dispose);
    await _start(tester, world, '仕事相談');
    await tester.tap(find.text('届いた応募'));
    await _settle(tester);
    world.server.injectFault(Fault.afterCommit);
    world.server.injectFault(Fault.beforeCommit);
    await tester.tap(find.text('承認する').first);
    await _settle(tester);
    expect(find.text('架空 相談員あさんの応募を承認しました。成立したので会話できます。'), findsOneWidget);
    expect(find.text('会話へ'), findsOneWidget);
    expect(find.text('架空 相談員あ'), findsNothing); // committed; refreshed away
    final matches = await tester.runAsync(world.api.listMatches);
    expect(matches!.where((m) => m.candidateId == myListingId), hasLength(1));
  });

  testWidgets(
      'owner approval notification survives a tab switch and opens chat',
      (tester) async {
    final world = DemoWorld.work(ownerDelay: Duration.zero);
    final approve = Completer<void>();
    final api = _WorkApi(world.api, approve: (id) async {
      await approve.future;
      return world.api.approveApplication(id);
    });
    await _start(tester, world, '仕事相談', api: api);
    await tester.tap(find.text('届いた応募'));
    await _settle(tester);
    await tester.tap(find.text('承認する').first);
    await tester.tap(find.text('設定'));
    await _settle(tester);
    approve.complete();
    await _settle(tester);

    expect(find.textContaining('架空 相談員あさんの応募を承認しました'), findsOneWidget);
    await tester.tap(find.text('会話へ'));
    await _settle(tester);
    final chat = tester.widget<ChatScreen>(find.byType(ChatScreen));
    final match = (await tester.runAsync(world.api.listMatches))!.single;
    expect(chat.entry.match.id, match.id);
    expect(chat.entry.counterpartId, match.otherParty(world.meId));
    expect(find.byType(TextField), findsOneWidget);
    await tester.runAsync(world.dispose);
  });

  testWidgets('settings stays selected when the owner tab becomes available',
      (tester) async {
    final world = DemoWorld.work(ownerDelay: Duration.zero);
    final me = Completer<Member>();
    final api = _WorkApi(world.api, readMe: () => me.future);
    await _start(tester, world, '仕事相談', api: api);
    expect(find.text('届いた応募'), findsNothing);
    await tester.tap(find.text('設定'));
    await _settle(tester);
    expect(find.byType(SettingsScreen), findsOneWidget);

    me.complete((await tester.runAsync(world.api.me))!);
    await _settle(tester);
    expect(find.text('届いた応募'), findsOneWidget);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(ApplicationsScreen), findsNothing);
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
