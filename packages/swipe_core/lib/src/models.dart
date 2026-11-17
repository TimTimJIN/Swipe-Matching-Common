enum AccountStatus { active, suspended, withdrawn }

class Member {
  const Member({
    required this.id,
    required this.serviceId,
    required this.displayName,
    this.status = AccountStatus.active,
  });

  final String id;
  final String serviceId;
  final String displayName;
  final AccountStatus status;

  Member copyWith({AccountStatus? status}) => Member(
      id: id,
      serviceId: serviceId,
      displayName: displayName,
      status: status ?? this.status);
}

/// A swipeable card: a member profile or a listing, always owned by a member.
class Candidate {
  const Candidate({
    required this.id,
    required this.serviceId,
    required this.ownerId,
    required this.title,
    required this.attributes,
    this.status = AccountStatus.active,
  });

  final String id;
  final String serviceId;
  final String ownerId;
  final String title;

  /// Values keyed by `FieldSpec.key`: `String` or `List<String>` for tags.
  final Map<String, Object> attributes;
  final AccountStatus status;

  Candidate copyWith({AccountStatus? status}) => Candidate(
      id: id,
      serviceId: serviceId,
      ownerId: ownerId,
      title: title,
      attributes: attributes,
      status: status ?? this.status);
}

enum SwipeIntent { positive, negative }

/// What the server did with an interaction.
enum InteractionStatus {
  /// Stored; nothing else happened (yet).
  recorded,

  /// Stored and waiting for the listing owner's decision.
  awaitingApproval,

  /// A match exists as a result.
  matched,
}

class InteractionCommand {
  const InteractionCommand({
    required this.candidateId,
    required this.intent,
    required this.idempotencyKey,
    required this.configVersion,
  });

  final String candidateId;
  final SwipeIntent intent;

  /// Same key + same payload returns the stored result instead of
  /// processing twice. Same key + different payload is a conflict.
  final String idempotencyKey;
  final int configVersion;
}

class InteractionResult {
  const InteractionResult(this.status, {this.match});
  final InteractionStatus status;
  final Match? match;
}

enum MatchState { open, closed }

class Match {
  const Match({
    required this.id,
    required this.serviceId,
    required this.candidateId,
    required this.parties,
    required this.ruleId,
    required this.configVersion,
    required this.createdAt,
    this.state = MatchState.open,
  });

  final String id;
  final String serviceId;

  /// The card that triggered the match (for listings: the listing id).
  final String candidateId;
  final Set<String> parties;
  final String ruleId;
  final int configVersion;
  final DateTime createdAt;
  final MatchState state;

  Match copyWith({MatchState? state}) => Match(
      id: id,
      serviceId: serviceId,
      candidateId: candidateId,
      parties: parties,
      ruleId: ruleId,
      configVersion: configVersion,
      createdAt: createdAt,
      state: state ?? this.state);

  String otherParty(String memberId) =>
      parties.firstWhere((p) => p != memberId, orElse: () => memberId);
}

/// An application waiting for a listing owner (owner-approval services).
class Application {
  const Application({
    required this.id,
    required this.serviceId,
    required this.listingId,
    required this.applicantId,
    required this.createdAt,
  });

  final String id;
  final String serviceId;
  final String listingId;
  final String applicantId;
  final DateTime createdAt;
}

class Message {
  const Message({
    required this.id,
    required this.matchId,
    required this.senderId,
    required this.body,
    required this.clientKey,
    required this.sentAt,
  });

  final String id;
  final String matchId;
  final String senderId;
  final String body;
  final String clientKey;
  final DateTime sentAt;
}

enum ReportReason { spam, harassment, inappropriateContent, fakeProfile, other }

class Report {
  const Report({
    required this.id,
    required this.reporterId,
    required this.targetMemberId,
    required this.reason,
    required this.note,
    required this.createdAt,
  });

  final String id;
  final String reporterId;
  final String targetMemberId;
  final ReportReason reason;
  final String note;
  final DateTime createdAt;
}

class Page<T> {
  const Page(this.items, {this.nextCursor});
  final List<T> items;
  final String? nextCursor;
}
