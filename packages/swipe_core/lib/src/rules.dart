import 'config.dart';
import 'models.dart';

/// Read-only view a rule may consult.
abstract interface class RuleContext {
  /// Whether [fromMember] gave a positive intent to any active card owned by
  /// [toOwner] in the same service.
  bool hasPositiveTowardsOwner(String fromMember, String toOwner);
}

/// What should happen after a positive intent is stored.
sealed class RuleOutcome {
  const RuleOutcome();
}

final class NoMatchYet extends RuleOutcome {
  const NoMatchYet();
}

final class CreateMatch extends RuleOutcome {
  const CreateMatch(this.parties, this.uniqueKey);
  final Set<String> parties;

  /// Matches are unique per key inside a service.
  final String uniqueKey;
}

final class AwaitOwnerApproval extends RuleOutcome {
  const AwaitOwnerApproval();
}

abstract interface class MatchRule {
  RuleOutcome onPositive(RuleContext context, String actorId, Candidate card);
}

class MutualInterestRule implements MatchRule {
  const MutualInterestRule();

  @override
  RuleOutcome onPositive(RuleContext context, String actorId, Candidate card) {
    final other = card.ownerId;
    if (!context.hasPositiveTowardsOwner(other, actorId)) {
      return const NoMatchYet();
    }
    final pair = [actorId, other]..sort();
    return CreateMatch({actorId, other}, 'pair:${pair.join('|')}');
  }
}

class OwnerApprovalRule implements MatchRule {
  const OwnerApprovalRule();

  @override
  RuleOutcome onPositive(RuleContext context, String actorId, Candidate card) =>
      const AwaitOwnerApproval();

  static String uniqueKey(String listingId, String applicantId) =>
      'listing:$listingId|$applicantId';
}

MatchRule ruleFor(MatchRuleId id) => switch (id) {
      MatchRuleId.mutualInterest => const MutualInterestRule(),
      MatchRuleId.ownerApproval => const OwnerApprovalRule(),
    };
