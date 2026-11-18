import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:swipe_core/swipe_core.dart';

final _random = Random.secure();

/// Random key for idempotent requests.
String newRequestKey() => List.generate(
    16, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();

/// User-facing text for a failure.
String describeFailure(Object error) => switch (error) {
      ValidationFailure() => '入力内容を確認してください。',
      ForbiddenFailure() => 'この操作は現在できません。',
      StaleConfigFailure() => '表示内容が更新されました。もう一度お試しください。',
      ConflictFailure() => 'すでに別の操作が記録されています。',
      TemporarilyUnavailableFailure(mayHaveCommitted: true) =>
        '通信結果を確認できませんでした。再送しても重複しません。',
      TemporarilyUnavailableFailure() => '通信できませんでした。再送してください。',
      _ => '問題が発生しました。',
    };

enum LoadState { loading, ready, failed }

/// Drives the card deck: loading, deciding, retrying with the same key.
class DiscoverController extends ChangeNotifier {
  DiscoverController(this.api);

  final MatchingApi api;
  ServiceConfig? config;
  LoadState state = LoadState.loading;
  final List<Candidate> _queue = [];
  String? _cursor;
  bool _exhausted = false;

  /// The pending decision for the top card, kept until the server confirms
  /// so a retry reuses the same idempotency key.
  ({String cardId, SwipeIntent intent, String key})? _pending;
  bool submitting = false;
  String? error;

  /// Last decision result, for announcing matches.
  ({Candidate card, InteractionResult result})? lastResult;

  Candidate? get current => _queue.isEmpty ? null : _queue.first;
  bool get canRetry => _pending != null && !submitting;

  Future<void> load() async {
    state = LoadState.loading;
    error = null;
    notifyListeners();
    try {
      config = await api.fetchConfig();
      _queue.clear();
      _cursor = null;
      _exhausted = false;
      await _fill();
      state = LoadState.ready;
    } catch (e) {
      error = describeFailure(e);
      state = LoadState.failed;
    }
    notifyListeners();
  }

  Future<void> _fill() async {
    while (_queue.length < 3 && !_exhausted) {
      final page = await api.fetchCandidates(cursor: _cursor, limit: 10);
      final known = _queue.map((c) => c.id).toSet();
      _queue.addAll(page.items.where((c) => !known.contains(c.id)));
      _cursor = page.nextCursor;
      _exhausted = page.nextCursor == null;
    }
  }

  Future<void> decide(SwipeIntent intent) async {
    final card = current;
    final cfg = config;
    if (card == null || cfg == null || submitting) return;
    final pending = _pending;
    final key = (pending != null &&
            pending.cardId == card.id &&
            pending.intent == intent)
        ? pending.key
        : newRequestKey();
    _pending = (cardId: card.id, intent: intent, key: key);
    await _submit(card, cfg);
  }

  Future<void> retry() async {
    final card = current;
    final cfg = config;
    if (card == null || cfg == null || _pending == null || submitting) return;
    await _submit(card, cfg);
  }

  Future<void> _submit(Candidate card, ServiceConfig cfg) async {
    final pending = _pending!;
    submitting = true;
    error = null;
    notifyListeners();
    try {
      final result = await api.submitInteraction(InteractionCommand(
        candidateId: card.id,
        intent: pending.intent,
        idempotencyKey: pending.key,
        configVersion: cfg.version,
      ));
      _pending = null;
      _queue.removeAt(0);
      lastResult = (card: card, result: result);
      // Cursor offsets shift once cards are decided, so restart paging and
      // drop duplicates already in the queue.
      _cursor = null;
      _exhausted = false;
      await _fill();
    } on StaleConfigFailure catch (e) {
      // Keep the card on screen; refresh labels and let the user choose again.
      _pending = null;
      error = describeFailure(e);
      try {
        config = await api.fetchConfig();
      } catch (_) {}
    } on ForbiddenFailure catch (e) {
      // The card became unavailable (blocked, withdrawn...). Skip it.
      _pending = null;
      _queue.removeAt(0);
      error = describeFailure(e);
    } catch (e) {
      error = describeFailure(e);
    } finally {
      submitting = false;
      notifyListeners();
    }
  }
}

/// One row in the match list.
class MatchEntry {
  const MatchEntry(this.match, this.title, this.counterpartId);
  final Match match;
  final String title;
  final String counterpartId;
}

class MatchesController extends ChangeNotifier {
  MatchesController(this.api, this.meId, this.config) {
    _events = api.events().listen((event) {
      if (event is MatchCreated || event is MatchClosed) refresh();
    });
  }

  final MatchingApi api;
  final String meId;
  final ServiceConfig config;
  late final StreamSubscription<MatchingEvent> _events;
  List<MatchEntry> entries = const [];
  String? error;

  Future<void> refresh() async {
    try {
      final matches = await api.listMatches();
      entries = [
        for (final m in matches) await _entry(m),
      ];
      error = null;
    } catch (e) {
      error = describeFailure(e);
    }
    notifyListeners();
  }

  Future<MatchEntry> _entry(Match m) async {
    final other = m.otherParty(meId);
    if (config.targetKind == TargetKind.listing) {
      final card = await api.candidate(m.candidateId);
      if (card.ownerId == meId) {
        // Owner side: several applicants may match one listing, so name them.
        final applicant = await api.member(other);
        return MatchEntry(m, '${applicant.displayName}（${card.title}）', other);
      }
      return MatchEntry(m, card.title, other);
    }
    final member = await api.member(other);
    return MatchEntry(m, member.displayName, other);
  }

  @override
  void dispose() {
    _events.cancel();
    super.dispose();
  }
}

/// One incoming application, with names resolved for display.
class ApplicationEntry {
  const ApplicationEntry(
      this.application, this.applicantName, this.listingTitle);
  final Application application;
  final String applicantName;
  final String listingTitle;
}

/// Owner side of owner-approval services: applications to my listings.
class ApplicationsController extends ChangeNotifier {
  ApplicationsController(this.api,
      {this.refreshTimeout = const Duration(seconds: 10)}) {
    _events = api.events().listen((event) {
      if (event is ApplicationReceived || event is MatchCreated) refresh();
    });
  }

  final MatchingApi api;
  final Duration refreshTimeout;
  late final StreamSubscription<MatchingEvent> _events;
  List<ApplicationEntry> entries = const [];
  String? error;

  /// Application ids with a decision in flight (buttons are disabled).
  final Set<String> busy = {};

  int _refreshVersion = 0;
  Future<void>? _latestRefresh;
  bool _disposed = false;

  Future<void> refresh() => _latestRefresh = _refresh();

  Future<void> _refresh() async {
    if (_disposed) return;
    final version = ++_refreshVersion;
    try {
      final apps = await api.listIncomingApplications()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final loaded = [for (final a in apps) await _entry(a)];
      if (_disposed || version != _refreshVersion) return;
      entries = loaded;
      error = null;
    } catch (e) {
      if (_disposed || version != _refreshVersion) return;
      error = describeFailure(e);
    }
    notifyListeners();
  }

  Future<ApplicationEntry> _entry(Application a) async {
    var name = '応募者';
    var title = '募集';
    try {
      name = (await api.member(a.applicantId)).displayName;
    } catch (_) {}
    try {
      title = (await api.candidate(a.listingId)).title;
    } catch (_) {}
    return ApplicationEntry(a, name, title);
  }

  Future<Match?> approve(ApplicationEntry entry) =>
      _decide(entry, () => _approve(entry.application));

  Future<Match> _approve(Application application) async {
    try {
      return await api.approveApplication(application.id);
    } on TemporarilyUnavailableFailure catch (failure) {
      if (!failure.mayHaveCommitted) rethrow;
      try {
        return await api.approveApplication(application.id);
      } on TemporarilyUnavailableFailure {
        // The first approval may already have produced an open match.
        try {
          final matches = await api.listMatches().timeout(refreshTimeout);
          for (final match in matches) {
            if (match.candidateId == application.listingId &&
                match.parties.contains(application.applicantId)) {
              return match;
            }
          }
        } on MatchingException {
          // Preserve the uncertain approval result if verification fails.
        } on TimeoutException {
          // Preserve the uncertain approval result if verification times out.
        }
        throw failure;
      }
    }
  }

  Future<void> decline(ApplicationEntry entry) async {
    await _decide(entry, () async {
      final id = entry.application.id;
      try {
        await api.declineApplication(id);
      } on TemporarilyUnavailableFailure catch (failure) {
        if (!failure.mayHaveCommitted) rethrow;
        await api.declineApplication(id);
      }
      return null;
    });
  }

  Future<Match?> _decide(
      ApplicationEntry entry, Future<Match?> Function() action) async {
    final id = entry.application.id;
    if (_disposed || !busy.add(id)) return null;
    error = null;
    notifyListeners();
    Match? match;
    String? failure;
    try {
      match = await action();
      entries = entries.where((entry) => entry.application.id != id).toList();
    } catch (e) {
      failure = describeFailure(e);
    }
    // Reload even after an error. The server may have committed the decision.
    await _waitForRefresh();
    busy.remove(id);
    if (!_disposed) {
      if (failure != null) error = failure;
      notifyListeners();
    }
    return match;
  }

  Future<void> _waitForRefresh() async {
    if (_disposed) return;
    final elapsed = Stopwatch()..start();
    var pending = refresh();
    try {
      while (!_disposed) {
        final remaining = refreshTimeout - elapsed.elapsed;
        if (remaining <= Duration.zero) return;
        await pending.timeout(remaining);
        if (identical(pending, _latestRefresh)) return;
        pending = _latestRefresh!;
      }
    } on TimeoutException {
      // Let the decision finish. A late refresh can still update the list.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _events.cancel();
    super.dispose();
  }
}

enum OutgoingState { sending, failed }

class OutgoingMessage {
  OutgoingMessage(this.body, this.key);
  final String body;
  final String key;
  OutgoingState state = OutgoingState.sending;
  String? error;
}

class ChatController extends ChangeNotifier {
  ChatController(this.api, this.matchId) {
    _events = api.events().listen((event) {
      switch (event) {
        case MessageReceived(:final message) when message.matchId == matchId:
          load();
        case MatchClosed(matchId: final id) when id == matchId:
          closed = true;
          notifyListeners();
        default:
          break;
      }
    });
  }

  final MatchingApi api;
  final String matchId;
  late final StreamSubscription<MatchingEvent> _events;
  List<Message> messages = const [];
  final List<OutgoingMessage> outgoing = [];
  bool closed = false;
  String? error;

  Future<void> load() async {
    try {
      messages = await api.messages(matchId);
      error = null;
    } on ForbiddenFailure {
      closed = true;
    } catch (e) {
      error = describeFailure(e);
    }
    notifyListeners();
  }

  Future<void> send(String body) async {
    if (body.trim().isEmpty || closed) return;
    final out = OutgoingMessage(body, newRequestKey());
    outgoing.add(out);
    await _deliver(out);
  }

  Future<void> retry(OutgoingMessage out) => _deliver(out);

  void discard(OutgoingMessage out) {
    outgoing.remove(out);
    notifyListeners();
  }

  Future<void> _deliver(OutgoingMessage out) async {
    out
      ..state = OutgoingState.sending
      ..error = null;
    notifyListeners();
    try {
      await api.sendMessage(matchId, out.body, out.key);
      outgoing.remove(out);
      messages = await api.messages(matchId);
    } on ForbiddenFailure catch (e) {
      closed = true;
      out
        ..state = OutgoingState.failed
        ..error = describeFailure(e);
    } catch (e) {
      out
        ..state = OutgoingState.failed
        ..error = describeFailure(e);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _events.cancel();
    super.dispose();
  }
}
