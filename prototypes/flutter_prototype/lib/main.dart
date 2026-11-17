import 'package:flutter/material.dart';

import 'matching.dart';

void main() => runApp(const SwipeMatchingApp());

class SwipeMatchingApp extends StatelessWidget {
  const SwipeMatchingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'スワイプマッチング',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff245844)),
        scaffoldBackgroundColor: const Color(0xfff5f5ef),
        useMaterial3: true,
      ),
      home: const DiscoverPage(),
    );
  }
}

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  final _sessions = scenarios.map(MatchSession.new).toList();
  int _selected = 0;
  double _distance = 0;

  MatchSession get _session => _sessions[_selected];

  void _decide(MatchSession session, Candidate candidate, Decision decision) {
    if (!identical(session, _session) ||
        session.nextCandidate?.id != candidate.id) return;
    setState(() {
      _distance = 0;
      final matched = session.decide(candidate.id, decision);
      final message = switch ((decision, matched)) {
        (_, true) => '${candidate.title}と成立しました',
        (Decision.like, false) => '意思表示を記録しました',
        (Decision.pass, false) => '見送りました',
      };
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(message)));
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final candidate = session.nextCandidate;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isWork = session.scenario.rule == MatchRule.ownerApproval;
    return Scaffold(
      appBar: AppBar(title: const Text('スワイプマッチング')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var index = 0; index < scenarios.length; index++)
                      ChoiceChip(
                        label: Text(scenarios[index].name),
                        selected: _selected == index,
                        onSelected: (_) => setState(() {
                          _selected = index;
                          _distance = 0;
                          ScaffoldMessenger.of(context).clearSnackBars();
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('候補を探す', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text(session.scenario.hint),
                const SizedBox(height: 16),
                if (candidate == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Text('すべての候補を確認しました'),
                  )
                else ...[
                  GestureDetector(
                    key: ValueKey(candidate.id),
                    excludeFromSemantics: true,
                    onHorizontalDragStart: (_) => setState(() => _distance = 0),
                    onHorizontalDragUpdate: (event) {
                      setState(() => _distance += event.delta.dx);
                    },
                    onHorizontalDragCancel: () => setState(() => _distance = 0),
                    onHorizontalDragEnd: (_) {
                      final distance = _distance;
                      if (distance.abs() < 64) {
                        setState(() => _distance = 0);
                        return;
                      }
                      _decide(session, candidate,
                          distance > 0 ? Decision.like : Decision.pass);
                    },
                    child: Transform.translate(
                      offset: Offset(_distance.clamp(-48, 48).toDouble(), 0),
                      child: Card(
                        margin: EdgeInsets.zero,
                        clipBehavior: Clip.hardEdge,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              constraints: const BoxConstraints(minHeight: 120),
                              color: colors.primaryContainer,
                              child: ExcludeSemantics(
                                child: Icon(
                                  isWork ? Icons.work_outline : Icons.landscape_outlined,
                                  size: 52,
                                  color: colors.onPrimaryContainer,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(candidate.title,
                                      style: theme.textTheme.headlineSmall),
                                  const SizedBox(height: 8),
                                  Text(candidate.labels.join(' / '),
                                      style: TextStyle(color: colors.primary)),
                                  const SizedBox(height: 12),
                                  Text(candidate.description),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => _decide(session, candidate, Decision.pass),
                        child: const Text('見送り'),
                      ),
                      FilledButton(
                        onPressed: () => _decide(session, candidate, Decision.like),
                        child: Text(isWork ? '応募する' : '興味あり'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 26),
                Text('成立した相手', style: theme.textTheme.titleLarge),
                if (session.matches.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('成立すると、ここから会話を始められます。'),
                  ),
                for (final match in session.matches)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(match.title),
                    subtitle: const Text('会話を開く'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => ConversationPage(session: session, candidate: match),
                    )),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ConversationPage extends StatefulWidget {
  const ConversationPage({
    super.key,
    required this.session,
    required this.candidate,
  });

  final MatchSession session;
  final Candidate candidate;

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final id = widget.candidate.id;
    final messages = widget.session.messages(id);
    if (messages == null) return;
    if (widget.session.send(id, 'local-${messages.length}', _controller.text)) {
      setState(() => _controller.clear());
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.session.messages(widget.candidate.id);
    return Scaffold(
      appBar: AppBar(title: Text(widget.candidate.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (messages == null)
              const Text('この相手との会話はまだ開始できません。')
            else ...[
              if (messages.isEmpty) const Text('最初のメッセージを送りましょう。'),
              for (final message in messages)
                Card(child: Padding(padding: const EdgeInsets.all(14), child: Text(message))),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: const InputDecoration(labelText: 'メッセージ'),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(onPressed: _send, child: const Text('送信')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
