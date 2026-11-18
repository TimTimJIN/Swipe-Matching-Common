import 'config.dart';
import 'models.dart';

/// Events pushed to a signed-in member.
sealed class MatchingEvent {
  const MatchingEvent();
}

final class MatchCreated extends MatchingEvent {
  const MatchCreated(this.match);
  final Match match;
}

final class MessageReceived extends MatchingEvent {
  const MessageReceived(this.message);
  final Message message;
}

final class MatchClosed extends MatchingEvent {
  const MatchClosed(this.matchId);
  final String matchId;
}

final class ApplicationReceived extends MatchingEvent {
  const ApplicationReceived(this.application);
  final Application application;
}

/// The contract between apps and any backend (in-memory, Firebase, Supabase,
/// a custom REST server...). One instance is bound to one signed-in member;
/// implementations derive the caller from their own authentication, never
/// from parameters, and must authorise every call on the server side.
///
/// Failures are reported as `MatchingException` subtypes.
abstract interface class MatchingApi {
  Future<ServiceConfig> fetchConfig();

  Future<Member> me();

  /// Cards the caller may decide on: excludes own cards, already decided
  /// cards, blocked members, suspended/withdrawn accounts and other services.
  Future<Page<Candidate>> fetchCandidates({String? cursor, int limit = 10});

  /// A card the caller can currently see, or one tied to the caller's match.
  Future<Candidate> candidate(String candidateId);

  /// Public profile of a member whose card is visible or who shares a match
  /// with the caller.
  Future<Member> member(String memberId);

  Future<InteractionResult> submitInteraction(InteractionCommand command);

  Future<List<Match>> listMatches();

  /// Pending applications from active, unblocked applicants to the caller's
  /// listings (owner-approval services).
  Future<List<Application>> listIncomingApplications();

  /// Only the listing owner may approve. Retrying with the same application ID
  /// returns the existing match while the applicant is available.
  Future<Match> approveApplication(String applicationId);

  /// Only the listing owner may decline. Retrying a decline is a no-op.
  Future<void> declineApplication(String applicationId);

  Future<List<Message>> messages(String matchId);

  /// [clientKey] makes retries safe: resending with the same key and body
  /// returns the already stored message.
  Future<Message> sendMessage(String matchId, String body, String clientKey);

  Future<void> block(String memberId);

  Future<Report> report(String memberId, ReportReason reason, String note);

  /// Deletes the caller's presence: cards hidden, matches closed, sign-out.
  Future<void> withdraw();

  Stream<MatchingEvent> events();
}

/// OS-specific capabilities (photos, push tokens, purchases...). Implemented
/// per platform in Flutter plugins (Swift / Kotlin) only when the shared
/// Flutter code cannot meet a requirement.
abstract interface class PlatformAdapter {
  Future<PermissionResult> requestNotificationPermission();
  Future<String?> pushToken();
}

enum PermissionResult { granted, denied, permanentlyDenied, unsupported }
