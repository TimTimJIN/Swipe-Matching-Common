import 'dart:async';

import 'api.dart';
import 'config.dart';
import 'errors.dart';
import 'models.dart';
import 'rules.dart';

/// Faults injected into the next mutating call, for testing retry paths.
enum Fault {
  /// Fail before anything is stored.
  beforeCommit,

  /// Store the change, then lose the response.
  afterCommit,
}

/// A mock backend that keeps everything in memory. It enforces the same
/// authorisation, idempotency and uniqueness rules a real server must, so the
/// shared UI and tests can be written against [MatchingApi] today.
///
/// This is NOT a production backend: data disappears on restart and
/// "concurrency" is only Dart's single-threaded event loop. Passing tests here
/// does not prove a real database behaves the same way.
class InMemoryServer {
  InMemoryServer({DateTime Function()? clock, this.latency = Duration.zero})
      : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Duration latency;

  final _configs = <String, ServiceConfig>{};
  final _members = <String, Member>{};
  final _cards = <String, Candidate>{};

  /// actorId -> cardId -> decision
  final _decisions = <String, Map<String, _Decision>>{};
  final _idempotent = <String, _Stored>{};
  final _matches = <String, Match>{};
  final _matchByKey = <String, String>{};
  final _applications = <String, Application>{};
  final _applicationResults =
      <String, ({Application application, String? matchId})>{};
  final _messages = <String, List<Message>>{};

  /// Unordered pairs "a|b" (sorted) that are blocked.
  final _blocks = <String>{};
  final _reports = <Report>[];
  final _faults = <Fault>[];
  final _streams = <String, StreamController<MatchingEvent>>{};
  final _serverEvents = StreamController<MatchingEvent>.broadcast(sync: true);
  int _seq = 0;

  // ---- admin / seeding (not exposed to apps) ----

  void registerService(ServiceConfig config) =>
      _configs[config.serviceId] = config;

  void addMember(Member member) => _members[member.id] = member;

  void addCard(Candidate card) {
    final config = _configs[card.serviceId];
    if (config == null)
      throw ArgumentError('unknown service ${card.serviceId}');
    for (final spec in config.fields) {
      if (spec.required && !card.attributes.containsKey(spec.key)) {
        throw ArgumentError('card ${card.id} misses ${spec.key}');
      }
    }
    for (final key in card.attributes.keys) {
      if (config.field(key) == null) {
        throw ArgumentError('card ${card.id} has unknown field $key');
      }
    }
    _cards[card.id] = card;
  }

  /// Records a decision made before the scenario starts (seed data).
  void seedDecision(String actorId, String cardId, SwipeIntent intent) {
    _decisionsOf(actorId)[cardId] =
        _Decision(intent, const InteractionResult(InteractionStatus.recorded));
    final card = _cards[cardId]!;
    final config = _configs[card.serviceId]!;
    if (intent == SwipeIntent.positive &&
        config.matchRule == MatchRuleId.ownerApproval) {
      _createApplication(card, actorId);
    }
  }

  void updateConfig(ServiceConfig config) => registerService(config);

  void suspend(String memberId) {
    _members[memberId] =
        _members[memberId]!.copyWith(status: AccountStatus.suspended);
  }

  void injectFault(Fault fault) => _faults.add(fault);

  List<Report> get reports => List.unmodifiable(_reports);

  /// Every event, for simulators and tests.
  Stream<MatchingEvent> get serverEvents => _serverEvents.stream;

  MatchingApi clientFor(String memberId) => _Client(this, memberId);

  // ---- helpers ----

  String _id(String prefix) => '${prefix}_${++_seq}';

  Map<String, _Decision> _decisionsOf(String actor) =>
      _decisions.putIfAbsent(actor, () => {});

  static String _pair(String a, String b) {
    final p = [a, b]..sort();
    return p.join('|');
  }

  bool _blocked(String a, String b) => _blocks.contains(_pair(a, b));

  Member _activeMember(String id) {
    final m = _members[id];
    if (m == null || m.status != AccountStatus.active) {
      throw const ForbiddenFailure('account is not active');
    }
    return m;
  }

  ServiceConfig _configOf(Member m) => _configs[m.serviceId]!;

  Future<T> _run<T>(T Function() body, {bool mutating = false}) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final fault = mutating && _faults.isNotEmpty ? _faults.removeAt(0) : null;
    if (fault == Fault.beforeCommit) {
      throw const TemporarilyUnavailableFailure('injected failure');
    }
    final result = body();
    if (fault == Fault.afterCommit) {
      throw const TemporarilyUnavailableFailure('response lost',
          mayHaveCommitted: true);
    }
    return result;
  }

  void _emit(Iterable<String> to, MatchingEvent event) {
    for (final id in to) {
      _streams[id]?.add(event);
    }
    _serverEvents.add(event);
  }

  bool _visibleTo(Candidate card, Member actor) =>
      card.serviceId == actor.serviceId &&
      card.status == AccountStatus.active &&
      card.ownerId != actor.id &&
      _members[card.ownerId]?.status == AccountStatus.active &&
      !_blocked(actor.id, card.ownerId);

  Match _createMatch(
      ServiceConfig config, Candidate card, Set<String> parties, String key) {
    final existing = _matchByKey[key];
    if (existing != null) return _matches[existing]!;
    final match = Match(
      id: _id('match'),
      serviceId: config.serviceId,
      candidateId: card.id,
      parties: Set.unmodifiable(parties),
      ruleId: config.matchRule.name,
      configVersion: config.version,
      createdAt: _clock(),
    );
    _matches[match.id] = match;
    _matchByKey[key] = match.id;
    _messages[match.id] = [];
    _emit(parties, MatchCreated(match));
    return match;
  }

  Application _createApplication(Candidate listing, String applicantId) {
    for (final a in _applications.values) {
      if (a.listingId == listing.id && a.applicantId == applicantId) return a;
    }
    final app = Application(
      id: _id('app'),
      serviceId: listing.serviceId,
      listingId: listing.id,
      applicantId: applicantId,
      createdAt: _clock(),
    );
    _applications[app.id] = app;
    _emit([listing.ownerId], ApplicationReceived(app));
    return app;
  }

  T _idempotently<T>(String actor, String scope, String key, String fingerprint,
      T Function() body) {
    if (key.isEmpty) throw const ValidationFailure('idempotency key required');
    final slot = '$actor|$scope|$key';
    final stored = _idempotent[slot];
    if (stored != null) {
      if (stored.fingerprint != fingerprint) {
        throw const ConflictFailure('idempotency key reused with other data');
      }
      return stored.value as T;
    }
    final value = body();
    _idempotent[slot] = _Stored(fingerprint, value);
    return value;
  }

  Match _matchFor(Member actor, String matchId) {
    final match = _matches[matchId];
    if (match == null ||
        match.serviceId != actor.serviceId ||
        !match.parties.contains(actor.id)) {
      throw const ForbiddenFailure('not a participant');
    }
    return match;
  }

  void _assertConversationOpen(Member actor, Match match) {
    final other = match.otherParty(actor.id);
    if (match.state != MatchState.open ||
        _blocked(actor.id, other) ||
        _members[other]?.status != AccountStatus.active) {
      throw const ForbiddenFailure('conversation is closed');
    }
  }

  void _closeMatches(bool Function(Match m) where) {
    for (final m in _matches.values.toList()) {
      if (m.state == MatchState.open && where(m)) {
        _matches[m.id] = m.copyWith(state: MatchState.closed);
        _emit(m.parties, MatchClosed(m.id));
      }
    }
  }
}

class _Decision {
  _Decision(this.intent, this.result);
  final SwipeIntent intent;
  InteractionResult result;
}

class _Stored {
  _Stored(this.fingerprint, this.value);
  final String fingerprint;
  final Object? value;
}

class _Client implements MatchingApi, RuleContext {
  _Client(this._s, this._actorId);

  final InMemoryServer _s;
  final String _actorId;

  Member get _actor => _s._activeMember(_actorId);

  @override
  Future<ServiceConfig> fetchConfig() => _s._run(() => _s._configOf(_actor));

  @override
  Future<Member> me() => _s._run(() => _actor);

  @override
  Future<Page<Candidate>> fetchCandidates({String? cursor, int limit = 10}) =>
      _s._run(() {
        if (limit < 1 || limit > 50) {
          throw const ValidationFailure('limit must be 1..50');
        }
        final actor = _actor;
        final decided = _s._decisionsOf(actor.id);
        final visible = _s._cards.values
            .where((c) => _s._visibleTo(c, actor) && !decided.containsKey(c.id))
            .toList();
        var start = 0;
        if (cursor != null) {
          start = int.tryParse(cursor) ??
              (throw const ValidationFailure('bad cursor'));
        }
        final end = (start + limit).clamp(0, visible.length);
        final items = start >= visible.length
            ? <Candidate>[]
            : visible.sublist(start, end);
        return Page(items, nextCursor: end < visible.length ? '$end' : null);
      });

  @override
  Future<Candidate> candidate(String candidateId) => _s._run(() {
        final actor = _actor;
        final card = _s._cards[candidateId];
        if (card != null && card.serviceId == actor.serviceId) {
          if (card.ownerId == actor.id || _s._visibleTo(card, actor)) {
            return card;
          }
          final related = _s._matches.values.any((m) =>
              m.parties.contains(actor.id) &&
              (m.candidateId == card.id || m.parties.contains(card.ownerId)));
          if (related) return card;
        }
        throw const ForbiddenFailure('card not available');
      });

  @override
  Future<Member> member(String memberId) => _s._run(() {
        final actor = _actor;
        final target = _s._members[memberId];
        if (target != null && target.serviceId == actor.serviceId) {
          final shown = target.id == actor.id ||
              _s._matches.values.any((m) =>
                  m.parties.contains(actor.id) &&
                  m.parties.contains(target.id)) ||
              // A listing owner may see who applied to their listing.
              _s._applications.values.any((a) =>
                  a.applicantId == target.id &&
                  _s._cards[a.listingId]?.ownerId == actor.id &&
                  !_s._blocked(actor.id, target.id)) ||
              _s._cards.values.any(
                  (c) => c.ownerId == target.id && _s._visibleTo(c, actor));
          if (shown) return target;
        }
        throw const ForbiddenFailure('member not available');
      });

  @override
  bool hasPositiveTowardsOwner(String fromMember, String toOwner) {
    final decisions = _s._decisions[fromMember];
    if (decisions == null) return false;
    return decisions.entries.any((e) =>
        e.value.intent == SwipeIntent.positive &&
        _s._cards[e.key]?.ownerId == toOwner &&
        _s._cards[e.key]?.status == AccountStatus.active);
  }

  @override
  Future<InteractionResult> submitInteraction(InteractionCommand command) =>
      _s._run(mutating: true, () {
        final actor = _actor;
        final config = _s._configOf(actor);
        return _s._idempotently(actor.id, 'interaction', command.idempotencyKey,
            '${command.candidateId}|${command.intent.name}|${command.configVersion}',
            () {
          if (command.configVersion != config.version) {
            throw StaleConfigFailure('configuration changed',
                currentVersion: config.version);
          }
          final card = _s._cards[command.candidateId];
          if (card == null || !_s._visibleTo(card, actor)) {
            throw const ForbiddenFailure('card not available');
          }
          final decisions = _s._decisionsOf(actor.id);
          final prior = decisions[card.id];
          if (prior != null) {
            if (prior.intent != command.intent) {
              throw const ConflictFailure('already decided differently');
            }
            return prior.result;
          }
          final decision = _Decision(command.intent,
              const InteractionResult(InteractionStatus.recorded));
          decisions[card.id] = decision;
          if (command.intent == SwipeIntent.negative) return decision.result;

          final outcome =
              ruleFor(config.matchRule).onPositive(this, actor.id, card);
          decision.result = switch (outcome) {
            NoMatchYet() => const InteractionResult(InteractionStatus.recorded),
            AwaitOwnerApproval() => () {
                _s._createApplication(card, actor.id);
                return const InteractionResult(
                    InteractionStatus.awaitingApproval);
              }(),
            CreateMatch(:final parties, :final uniqueKey) => InteractionResult(
                InteractionStatus.matched,
                match: _s._createMatch(config, card, parties, uniqueKey)),
          };
          return decision.result;
        });
      });

  @override
  Future<List<Match>> listMatches() => _s._run(() {
        final actor = _actor;
        return _s._matches.values
            .where((m) =>
                m.serviceId == actor.serviceId &&
                m.parties.contains(actor.id) &&
                m.state == MatchState.open)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      });

  @override
  Future<List<Application>> listIncomingApplications() => _s._run(() {
        final actor = _actor;
        return _s._applications.values
            .where((a) =>
                _s._cards[a.listingId]?.ownerId == actor.id &&
                _s._members[a.applicantId]?.status == AccountStatus.active &&
                !_s._blocked(actor.id, a.applicantId))
            .toList();
      });

  Application _ownedApplication(Member actor, String applicationId) {
    final app = _s._applications[applicationId] ??
        _s._applicationResults[applicationId]?.application;
    final listing = app == null ? null : _s._cards[app.listingId];
    if (app == null || listing == null || listing.ownerId != actor.id) {
      throw const ForbiddenFailure('only the listing owner can decide');
    }
    return app;
  }

  @override
  Future<Match> approveApplication(String applicationId) =>
      _s._run(mutating: true, () {
        final actor = _actor;
        final app = _ownedApplication(actor, applicationId);
        final listing = _s._cards[app.listingId]!;
        if (_s._blocked(actor.id, app.applicantId) ||
            _s._members[app.applicantId]?.status != AccountStatus.active) {
          throw const ForbiddenFailure('applicant not available');
        }
        final previous = _s._applicationResults[app.id];
        if (previous != null) {
          final matchId = previous.matchId;
          if (matchId == null) {
            throw const ConflictFailure('application already declined');
          }
          return _s._matches[matchId]!;
        }
        final config = _s._configOf(actor);
        final match = _s._createMatch(
            config,
            listing,
            {app.applicantId, actor.id},
            OwnerApprovalRule.uniqueKey(listing.id, app.applicantId));
        final decision = _s._decisions[app.applicantId]?[listing.id];
        if (decision != null) {
          decision.result =
              InteractionResult(InteractionStatus.matched, match: match);
        }
        _s._applications.remove(app.id);
        _s._applicationResults[app.id] = (application: app, matchId: match.id);
        return match;
      });

  @override
  Future<void> declineApplication(String applicationId) =>
      _s._run(mutating: true, () {
        final app = _ownedApplication(_actor, applicationId);
        if (_s._applicationResults[app.id]?.matchId != null) {
          throw const ConflictFailure('application already approved');
        }
        _s._applications.remove(app.id);
        _s._applicationResults[app.id] = (application: app, matchId: null);
      });

  @override
  Future<List<Message>> messages(String matchId) => _s._run(() {
        final actor = _actor;
        final match = _s._matchFor(actor, matchId);
        _s._assertConversationOpen(actor, match);
        return List.unmodifiable(_s._messages[match.id]!);
      });

  @override
  Future<Message> sendMessage(String matchId, String body, String clientKey) =>
      _s._run(mutating: true, () {
        final actor = _actor;
        return _s._idempotently(
            actor.id, 'message', clientKey, '$matchId|$body', () {
          final match = _s._matchFor(actor, matchId);
          _s._assertConversationOpen(actor, match);
          final text = body.trim();
          final limit = _s._configOf(actor).maxMessageLength;
          if (text.isEmpty) throw const ValidationFailure('message is empty');
          if (text.length > limit) {
            throw ValidationFailure('message exceeds $limit characters');
          }
          final message = Message(
            id: _s._id('msg'),
            matchId: match.id,
            senderId: actor.id,
            body: text,
            clientKey: clientKey,
            sentAt: _s._clock(),
          );
          _s._messages[match.id]!.add(message);
          _s._emit(match.parties.where((p) => p != actor.id),
              MessageReceived(message));
          return message;
        });
      });

  @override
  Future<void> block(String memberId) => _s._run(mutating: true, () {
        final actor = _actor;
        final target = _s._members[memberId];
        if (target == null ||
            target.serviceId != actor.serviceId ||
            target.id == actor.id) {
          throw const ForbiddenFailure('cannot block this member');
        }
        // The block is committed first; any later send is rejected.
        _s._blocks.add(InMemoryServer._pair(actor.id, memberId));
        _s._closeMatches((m) =>
            m.parties.contains(actor.id) && m.parties.contains(memberId));
      });

  @override
  Future<Report> report(String memberId, ReportReason reason, String note) =>
      _s._run(mutating: true, () {
        final actor = _actor;
        final target = _s._members[memberId];
        if (target == null || target.serviceId != actor.serviceId) {
          throw const ForbiddenFailure('cannot report this member');
        }
        if (note.length > 1000) {
          throw const ValidationFailure('note is too long');
        }
        final report = Report(
          id: _s._id('report'),
          reporterId: actor.id,
          targetMemberId: memberId,
          reason: reason,
          note: note.trim(),
          createdAt: _s._clock(),
        );
        _s._reports.add(report);
        return report;
      });

  @override
  Future<void> withdraw() => _s._run(mutating: true, () {
        final actor = _actor;
        _s._members[actor.id] = actor.copyWith(status: AccountStatus.withdrawn);
        for (final card in _s._cards.values.toList()) {
          if (card.ownerId == actor.id) {
            _s._cards[card.id] = card.copyWith(status: AccountStatus.withdrawn);
          }
        }
        _s._applications.removeWhere((_, a) =>
            a.applicantId == actor.id ||
            _s._cards[a.listingId]?.ownerId == actor.id);
        _s._applicationResults.removeWhere((_, result) =>
            result.application.applicantId == actor.id ||
            _s._cards[result.application.listingId]?.ownerId == actor.id);
        _s._closeMatches((m) => m.parties.contains(actor.id));
        _s._streams.remove(actor.id)?.close();
      });

  @override
  Stream<MatchingEvent> events() {
    _actor;
    return _s._streams
        .putIfAbsent(_actorId, StreamController<MatchingEvent>.broadcast)
        .stream;
  }
}
