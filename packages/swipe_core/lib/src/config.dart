/// What a card represents in a service.
enum TargetKind {
  /// A person's profile (person-to-person matching).
  member,

  /// A listing owned by a member, e.g. a job or consultation request.
  listing,
}

/// Registered match rules. Services pick one by id; arbitrary code is never
/// loaded from configuration.
enum MatchRuleId {
  /// Both members expressed positive interest in each other.
  mutualInterest,

  /// A member applied and the listing owner approved the application.
  ownerApproval,
}

enum FieldKind { shortText, longText, tags }

/// One item shown on a card. Values live in `Candidate.attributes[key]`.
class FieldSpec {
  const FieldSpec({
    required this.key,
    required this.label,
    required this.kind,
    this.required = false,
    this.maxLength = 200,
  });

  final String key;
  final String label;
  final FieldKind kind;
  final bool required;
  final int maxLength;
}

/// Words used for the two decisions, so each service can speak its own way.
class IntentLabels {
  const IntentLabels({required this.positive, required this.negative});
  final String positive;
  final String negative;
}

/// Everything a service may customise without touching the shared core.
class ServiceConfig {
  const ServiceConfig({
    required this.serviceId,
    required this.version,
    required this.displayName,
    required this.targetKind,
    required this.fields,
    required this.intentLabels,
    required this.matchRule,
    required this.matchHint,
    this.maxMessageLength = 1000,
  });

  final String serviceId;

  /// Bumped whenever fields or rules change. Clients send the version they
  /// rendered with; the backend rejects outdated ones.
  final int version;
  final String displayName;
  final TargetKind targetKind;
  final List<FieldSpec> fields;
  final IntentLabels intentLabels;
  final MatchRuleId matchRule;

  /// One-line explanation of how a match happens, shown to users.
  final String matchHint;
  final int maxMessageLength;

  FieldSpec? field(String key) {
    for (final f in fields) {
      if (f.key == key) return f;
    }
    return null;
  }
}
