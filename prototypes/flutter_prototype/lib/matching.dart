enum Decision { pass, like }
enum MatchRule { mutualInterest, ownerApproval }

class Candidate {
  const Candidate(this.id, this.title, this.labels, this.description,
      {this.interested = false, this.approved = false});
  final String id;
  final String title;
  final List<String> labels;
  final String description;
  final bool interested;
  final bool approved;
}

class Scenario {
  const Scenario(this.name, this.rule, this.hint, this.candidates);
  final String name;
  final MatchRule rule;
  final String hint;
  final List<Candidate> candidates;

  bool matches(Candidate candidate) => switch (rule) {
    MatchRule.mutualInterest => candidate.interested,
    MatchRule.ownerApproval => candidate.approved,
  };
}

const scenarios = [
  Scenario('趣味仲間', MatchRule.mutualInterest, 'お互いが「興味あり」で成立', [
    Candidate('h1', '小川 はる', ['写真', '東京'],
        '休日の朝に街を歩きながら、光や建物を撮る仲間を探しています。',
        interested: true),
    Candidate('h2', '佐伯 あおい', ['登山', '神奈川'],
        '低山を中心に、月に一度くらい一緒に歩ける人を探しています。'),
  ]),
  Scenario('仕事相談', MatchRule.ownerApproval, '応募に案件オーナーが承認すると成立', [
    Candidate('w1', '問い合わせの一次対応を整理', ['業務改善', 'オンライン'],
        '小規模事業者の問い合わせ対応を見直す、初回の業務整理を相談したいです。',
        approved: true),
    Candidate('w2', '採用サイトの改善案を作成', ['Web企画', 'オンライン'],
        '応募者が必要な情報に迷わずたどり着ける構成を検討しています。'),
  ]),
];

class MatchSession {
  MatchSession(this.scenario);
  final Scenario scenario;
  final _decisions = <String, Decision>{};
  final _threads = <String, Map<String, String>>{};

  Candidate? get nextCandidate {
    for (final candidate in scenario.candidates) {
      if (!_decisions.containsKey(candidate.id)) return candidate;
    }
    return null;
  }

  List<Candidate> get matches => scenario.candidates
      .where((candidate) => _threads.containsKey(candidate.id))
      .toList(growable: false);

  bool decide(String candidateId, Decision decision) {
    final prior = _decisions[candidateId];
    if (prior != null) {
      return prior == decision && _threads.containsKey(candidateId);
    }
    final candidate = nextCandidate;
    if (candidate == null || candidate.id != candidateId) return false;
    _decisions[candidateId] = decision;
    if (decision != Decision.like || !scenario.matches(candidate)) return false;
    _threads[candidateId] = {};
    return true;
  }

  List<String>? messages(String candidateId) {
    final thread = _threads[candidateId];
    return thread == null ? null : List.unmodifiable(thread.values);
  }

  bool send(String candidateId, String messageId, String body) {
    final thread = _threads[candidateId];
    final text = body.trim();
    if (thread == null || messageId.isEmpty || text.isEmpty) return false;
    final prior = thread[messageId];
    if (prior != null) return prior == text;
    thread[messageId] = text;
    return true;
  }
}
