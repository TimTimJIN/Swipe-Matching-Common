import 'package:swipe_core/swipe_core.dart';
import 'package:test/test.dart';

InMemoryServer _hobbyServer() {
  final s = InMemoryServer()..registerService(hobbyConfig);
  for (final id in ['a', 'b', 'c']) {
    s.addMember(Member(id: id, serviceId: 'hobby', displayName: id));
    s.addCard(Candidate(
        id: 'card_$id',
        serviceId: 'hobby',
        ownerId: id,
        title: id,
        attributes: const {
          'hobbies': ['x'],
          'area': 'y'
        }));
  }
  return s;
}

InMemoryServer _workServer() {
  final s = InMemoryServer()..registerService(workConfig);
  for (final id in ['owner', 'applicant', 'stranger']) {
    s.addMember(Member(id: id, serviceId: 'work', displayName: id));
  }
  s.addCard(const Candidate(
      id: 'job',
      serviceId: 'work',
      ownerId: 'owner',
      title: 'job',
      attributes: {
        'field': ['x'],
        'request': 'y'
      }));
  return s;
}

InteractionCommand like(String card, String key, {int version = 1}) =>
    InteractionCommand(
        candidateId: card,
        intent: SwipeIntent.positive,
        idempotencyKey: key,
        configVersion: version);

void main() {
  group('mutual interest', () {
    test('simultaneous likes create exactly one match', () async {
      final s = _hobbyServer();
      final results = await Future.wait([
        s.clientFor('a').submitInteraction(like('card_b', 'k1')),
        s.clientFor('b').submitInteraction(like('card_a', 'k1')),
      ]);
      expect(results.map((r) => r.status), contains(InteractionStatus.matched));
      expect(await s.clientFor('a').listMatches(), hasLength(1));
      expect(await s.clientFor('b').listMatches(), hasLength(1));
    });

    test('one-sided like or pass does not match and blocks conversation',
        () async {
      final s = _hobbyServer();
      final r = await s.clientFor('a').submitInteraction(like('card_b', 'k'));
      expect(r.status, InteractionStatus.recorded);
      await s.clientFor('b').submitInteraction(const InteractionCommand(
          candidateId: 'card_a',
          intent: SwipeIntent.negative,
          idempotencyKey: 'k',
          configVersion: 1));
      expect(await s.clientFor('a').listMatches(), isEmpty);
    });

    test('decided cards leave the deck', () async {
      final s = _hobbyServer();
      final a = s.clientFor('a');
      expect((await a.fetchCandidates()).items.map((c) => c.id),
          ['card_b', 'card_c']);
      await a.submitInteraction(like('card_b', 'k'));
      expect((await a.fetchCandidates()).items.map((c) => c.id), ['card_c']);
    });

    test('cursor paging covers every card once', () async {
      final s = _hobbyServer();
      final a = s.clientFor('a');
      final first = await a.fetchCandidates(limit: 1);
      final second =
          await a.fetchCandidates(cursor: first.nextCursor, limit: 1);
      expect([...first.items, ...second.items].map((c) => c.id),
          ['card_b', 'card_c']);
      expect(second.nextCursor, isNull);
    });
  });

  group('idempotency', () {
    test('same key and payload returns the same result once', () async {
      final s = _hobbyServer();
      await s.clientFor('b').submitInteraction(like('card_a', 'x'));
      final a = s.clientFor('a');
      final r1 = await a.submitInteraction(like('card_b', 'same'));
      final r2 = await a.submitInteraction(like('card_b', 'same'));
      expect(r1.match!.id, r2.match!.id);
      expect(await a.listMatches(), hasLength(1));
    });

    test('same key with different payload is a conflict', () async {
      final a = _hobbyServer().clientFor('a');
      await a.submitInteraction(like('card_b', 'same'));
      expect(a.submitInteraction(like('card_c', 'same')),
          throwsA(isA<ConflictFailure>()));
    });

    test('lost response can be retried safely', () async {
      final s = _hobbyServer();
      await s.clientFor('b').submitInteraction(like('card_a', 'x'));
      final a = s.clientFor('a');
      s.injectFault(Fault.afterCommit);
      await expectLater(
          a.submitInteraction(like('card_b', 'retry')),
          throwsA(isA<TemporarilyUnavailableFailure>()
              .having((e) => e.mayHaveCommitted, 'mayHaveCommitted', true)));
      final retried = await a.submitInteraction(like('card_b', 'retry'));
      expect(retried.status, InteractionStatus.matched);
      expect(await a.listMatches(), hasLength(1));
    });

    test('message resend with same key stores one message', () async {
      final s = _hobbyServer();
      await s.clientFor('b').submitInteraction(like('card_a', 'x'));
      final a = s.clientFor('a');
      final match = (await a.submitInteraction(like('card_b', 'y'))).match!;
      s.injectFault(Fault.afterCommit);
      await expectLater(a.sendMessage(match.id, 'hi', 'm1'),
          throwsA(isA<TemporarilyUnavailableFailure>()));
      await a.sendMessage(match.id, 'hi', 'm1');
      expect(await a.messages(match.id), hasLength(1));
      expect(a.sendMessage(match.id, 'other', 'm1'),
          throwsA(isA<ConflictFailure>()));
    });
  });

  group('authorization', () {
    test('cards and matches of another service are not reachable', () async {
      final s = _hobbyServer()..registerService(workConfig);
      s.addMember(const Member(id: 'w', serviceId: 'work', displayName: 'w'));
      final w = s.clientFor('w');
      expect((await w.fetchCandidates()).items, isEmpty);
      expect(w.submitInteraction(like('card_a', 'k')),
          throwsA(isA<ForbiddenFailure>()));
      expect(w.candidate('card_a'), throwsA(isA<ForbiddenFailure>()));
    });

    test('non-participants cannot read or send', () async {
      final s = _hobbyServer();
      await s.clientFor('b').submitInteraction(like('card_a', 'x'));
      final match =
          (await s.clientFor('a').submitInteraction(like('card_b', 'y')))
              .match!;
      final c = s.clientFor('c');
      expect(c.messages(match.id), throwsA(isA<ForbiddenFailure>()));
      expect(
          c.sendMessage(match.id, 'hi', 'k'), throwsA(isA<ForbiddenFailure>()));
    });

    test('block is ordered before send and closes the match', () async {
      final s = _hobbyServer();
      await s.clientFor('b').submitInteraction(like('card_a', 'x'));
      final a = s.clientFor('a');
      final match = (await a.submitInteraction(like('card_b', 'y'))).match!;
      await s.clientFor('b').block('a');
      expect(
          a.sendMessage(match.id, 'hi', 'k'), throwsA(isA<ForbiddenFailure>()));
      expect(await a.listMatches(), isEmpty);
      expect((await a.fetchCandidates()).items.map((c) => c.id),
          isNot(contains('card_b')));
    });

    test('suspended members disappear from the deck', () async {
      final s = _hobbyServer()..suspend('b');
      final ids =
          (await s.clientFor('a').fetchCandidates()).items.map((c) => c.id);
      expect(ids, ['card_c']);
      expect(
          s.clientFor('b').fetchCandidates(), throwsA(isA<ForbiddenFailure>()));
    });

    test('withdrawal closes matches and hides cards', () async {
      final s = _hobbyServer();
      await s.clientFor('b').submitInteraction(like('card_a', 'x'));
      final a = s.clientFor('a');
      await a.submitInteraction(like('card_b', 'y'));
      await s.clientFor('b').withdraw();
      expect(await a.listMatches(), isEmpty);
      expect((await s.clientFor('c').fetchCandidates()).items.map((c) => c.id),
          ['card_a']);
      expect(s.clientFor('b').me(), throwsA(isA<ForbiddenFailure>()));
    });

    test('reports are stored for the right service only', () async {
      final s = _hobbyServer();
      await s.clientFor('a').report('b', ReportReason.spam, ' note ');
      expect(s.reports.single.note, 'note');
      expect(s.clientFor('a').report('missing', ReportReason.spam, ''),
          throwsA(isA<ForbiddenFailure>()));
    });
  });

  group('owner approval', () {
    test('application waits, owner approval creates the match', () async {
      final s = _workServer();
      final applicant = s.clientFor('applicant');
      final r = await applicant.submitInteraction(like('job', 'k'));
      expect(r.status, InteractionStatus.awaitingApproval);
      expect(await applicant.listMatches(), isEmpty);
      final owner = s.clientFor('owner');
      final app = (await owner.listIncomingApplications()).single;
      final match = await owner.approveApplication(app.id);
      expect(match.parties, {'owner', 'applicant'});
      expect(await applicant.listMatches(), hasLength(1));
      await applicant.sendMessage(match.id, 'よろしくお願いします', 'm');
      expect(await owner.messages(match.id), hasLength(1));
    });

    test('only the listing owner can approve', () async {
      final s = _workServer();
      await s.clientFor('applicant').submitInteraction(like('job', 'k'));
      final app =
          (await s.clientFor('owner').listIncomingApplications()).single;
      expect(s.clientFor('stranger').approveApplication(app.id),
          throwsA(isA<ForbiddenFailure>()));
      expect(s.clientFor('applicant').approveApplication(app.id),
          throwsA(isA<ForbiddenFailure>()));
    });
  });

  group('configuration', () {
    test('stale config version is rejected with the current version', () async {
      final s = _hobbyServer();
      s.updateConfig(const ServiceConfig(
        serviceId: 'hobby',
        version: 2,
        displayName: '趣味仲間',
        targetKind: TargetKind.member,
        fields: [],
        intentLabels: IntentLabels(positive: 'a', negative: 'b'),
        matchRule: MatchRuleId.mutualInterest,
        matchHint: '',
      ));
      expect(
          s.clientFor('a').submitInteraction(like('card_b', 'k')),
          throwsA(isA<StaleConfigFailure>()
              .having((e) => e.currentVersion, 'currentVersion', 2)));
    });

    test('cards must follow the service field schema', () {
      final s = InMemoryServer()..registerService(hobbyConfig);
      expect(
          () => s.addCard(const Candidate(
              id: 'x',
              serviceId: 'hobby',
              ownerId: 'o',
              title: 'x',
              attributes: {'area': 'y', 'salary': '1'})),
          throwsArgumentError);
    });

    test('empty and overlong messages are rejected', () async {
      final s = _hobbyServer();
      await s.clientFor('b').submitInteraction(like('card_a', 'x'));
      final a = s.clientFor('a');
      final match = (await a.submitInteraction(like('card_b', 'y'))).match!;
      expect(a.sendMessage(match.id, '   ', 'k1'),
          throwsA(isA<ValidationFailure>()));
      expect(a.sendMessage(match.id, 'x' * 1001, 'k2'),
          throwsA(isA<ValidationFailure>()));
    });
  });

  group('demo worlds', () {
    test('hobby demo has 20 fictional peers and seeded mutual interest',
        () async {
      final world = DemoWorld.hobby(peerDelay: Duration.zero);
      final page = await world.api.fetchCandidates(limit: 50);
      expect(page.items, hasLength(20));
      final r = await world.api.submitInteraction(like('card_hobby_p0', 'k'));
      expect(r.status, InteractionStatus.matched);
      await world.dispose();
    });

    test('work demo auto-approves selected listings as their owner', () async {
      final world = DemoWorld.work(ownerDelay: Duration.zero);
      expect((await world.api.fetchCandidates(limit: 50)).items, hasLength(20));
      await world.api.submitInteraction(like('listing_0', 'k0'));
      await world.api.submitInteraction(like('listing_1', 'k1'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final matches = await world.api.listMatches();
      expect(matches.map((m) => m.candidateId), ['listing_0']);
      await world.dispose();
    });

    test('work demo: "me" owns a listing with fictional applications to decide',
        () async {
      final world = DemoWorld.work(ownerDelay: Duration.zero);
      final apps = await world.api.listIncomingApplications();
      expect(apps, hasLength(3));
      expect(apps.every((a) => a.listingId == myListingId), isTrue);
      // The owner can see who applied, but not other members.
      final applicant = await world.api.member(apps.first.applicantId);
      expect(applicant.displayName, startsWith('架空'));
      expect(world.api.member('work_applicant_unknown'),
          throwsA(isA<ForbiddenFailure>()));
      final match = await world.api.approveApplication(apps.first.id);
      await world.api.declineApplication(apps[1].id);
      expect(await world.api.listIncomingApplications(), hasLength(1));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final greeting = await world.api.messages(match.id);
      expect(greeting.single.senderId, apps.first.applicantId);
      await world.dispose();
    });

    test('a decided applicant is no longer visible through the application',
        () async {
      final world = DemoWorld.work(ownerDelay: Duration.zero);
      final app = (await world.api.listIncomingApplications())[2];
      await world.api.declineApplication(app.id);
      expect(
          world.api.member(app.applicantId), throwsA(isA<ForbiddenFailure>()));
      await world.dispose();
    });
  });
}
