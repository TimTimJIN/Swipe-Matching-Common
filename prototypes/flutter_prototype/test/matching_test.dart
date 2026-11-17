import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_matching_prototype/matching.dart';

void main() {
  test('mutual interest matches once, and a one-sided like does not match', () {
    final session = MatchSession(scenarios.first);
    expect(session.decide('h1', Decision.like), isTrue);
    expect(session.decide('h1', Decision.like), isTrue);
    expect(session.decide('h2', Decision.like), isFalse);
    expect(session.matches.map((candidate) => candidate.id), ['h1']);
  });

  test('owner approval is independent of reciprocal interest', () {
    final session = MatchSession(scenarios.last);
    expect(session.decide('w1', Decision.like), isTrue);
    expect(session.decide('w2', Decision.like), isFalse);
    expect(session.nextCandidate, isNull);
    expect(session.messages('h1'), isNull);
  });

  test('pass is final and unopened conversations reject messages', () {
    final session = MatchSession(scenarios.first);
    expect(session.decide('h2', Decision.like), isFalse);
    expect(session.nextCandidate?.id, 'h1');
    expect(session.decide('h1', Decision.pass), isFalse);
    expect(session.decide('h1', Decision.like), isFalse);
    expect(session.messages('h1'), isNull);
    expect(session.send('h1', 'm1', 'こんにちは'), isFalse);
  });

  test('message retry returns success without inserting another copy', () {
    final session = MatchSession(scenarios.first)..decide('h1', Decision.like);
    expect(session.send('h1', 'm1', ' こんにちは '), isTrue);
    expect(session.send('h1', 'm1', 'こんにちは'), isTrue);
    expect(session.send('h1', 'm1', '変更'), isFalse);
    expect(session.send('h1', 'm2', ' '), isFalse);
    expect(session.messages('h1'), ['こんにちは']);
  });
}
