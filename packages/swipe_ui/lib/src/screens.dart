import 'package:material_ui/material_ui.dart';
import 'package:swipe_core/swipe_core.dart';

import 'card_deck.dart';
import 'controllers.dart';

/// Look and words an app may change without touching shared code.
class AppBranding {
  const AppBranding({
    required this.appName,
    required this.seedColor,
    this.cardIcon,
  });

  final String appName;
  final Color seedColor;
  final IconData? cardIcon;

  ThemeData theme(Brightness brightness) => ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: seedColor, brightness: brightness),
        useMaterial3: true,
      );
}

/// Entry widget each per-use app runs: `runApp(SwipeMatchingApp(...))`.
class SwipeMatchingApp extends StatelessWidget {
  const SwipeMatchingApp({
    super.key,
    required this.api,
    required this.branding,
    this.banner,
  });

  final MatchingApi api;
  final AppBranding branding;

  /// Optional notice shown on top, e.g. "demo data".
  final String? banner;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: branding.appName,
      debugShowCheckedModeBanner: false,
      theme: branding.theme(Brightness.light),
      darkTheme: branding.theme(Brightness.dark),
      home: _Shell(api: api, branding: branding, banner: banner),
    );
  }
}

class _Shell extends StatefulWidget {
  const _Shell({required this.api, required this.branding, this.banner});
  final MatchingApi api;
  final AppBranding branding;
  final String? banner;

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  late final DiscoverController _discover = DiscoverController(widget.api);
  MatchesController? _matches;
  Member? _me;
  int _tab = 0;
  bool _signedOut = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    await _discover.load();
    try {
      final me = await widget.api.me();
      final config = _discover.config;
      if (!mounted || config == null) return;
      setState(() {
        _me = me;
        _matches = MatchesController(widget.api, me.id, config)..refresh();
      });
    } catch (_) {
      // Discover screen shows the load error.
    }
  }

  @override
  void dispose() {
    _discover.dispose();
    _matches?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_signedOut) {
      return const Scaffold(
          body: Center(child: Text('退会しました。ご利用ありがとうございました。')));
    }
    final matches = _matches;
    final pages = [
      DiscoverScreen(
          controller: _discover,
          icon: widget.branding.cardIcon,
          onMatched: () => setState(() => _tab = 1)),
      if (matches != null)
        MatchesScreen(controller: matches, config: _discover.config!)
      else
        const Center(child: CircularProgressIndicator()),
      SettingsScreen(
        api: widget.api,
        me: _me,
        onWithdrawn: () => setState(() => _signedOut = true),
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.branding.appName),
        bottom: widget.banner == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(28),
                child: Container(
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                  child: Text(widget.banner!,
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onTertiaryContainer)),
                ),
              ),
      ),
      body: SafeArea(child: pages[_tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.style_outlined), label: '探す'),
          NavigationDestination(
              icon: Icon(Icons.forum_outlined), label: '成立・会話'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined), label: '設定'),
        ],
      ),
    );
  }
}

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({
    super.key,
    required this.controller,
    this.icon,
    this.onMatched,
  });

  final DiscoverController controller;
  final IconData? icon;
  final VoidCallback? onMatched;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  Object? _announced;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    final last = widget.controller.lastResult;
    if (last == null || identical(last, _announced) || !mounted) return;
    _announced = last;
    final config = widget.controller.config!;
    final text = switch (last.result.status) {
      InteractionStatus.matched => '${last.card.title}と成立しました',
      InteractionStatus.awaitingApproval => '応募しました。承認されると成立します',
      InteractionStatus.recorded => '記録しました',
    };
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    messenger.showSnackBar(SnackBar(
      content: Text(text),
      action: last.result.status == InteractionStatus.matched &&
              widget.onMatched != null
          ? SnackBarAction(label: '会話へ', onPressed: widget.onMatched!)
          : null,
    ));
    if (config.targetKind == TargetKind.member &&
        last.result.status == InteractionStatus.recorded) {
      messenger.clearSnackBars();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        final theme = Theme.of(context);
        if (c.state == LoadState.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (c.state == LoadState.failed) {
          return _Message(
              text: c.error ?? '読み込めませんでした。',
              action: FilledButton(onPressed: c.load, child: const Text('再読み込み')));
        }
        final config = c.config!;
        final card = c.current;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Text(config.matchHint, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 12),
                if (card == null)
                  _Message(
                    text: 'いまは新しい候補がありません。',
                    action: OutlinedButton(
                        onPressed: c.load, child: const Text('もう一度探す')),
                  )
                else ...[
                  SwipeCard(
                    key: ValueKey(card.id),
                    labels: config.intentLabels,
                    enabled: !c.submitting,
                    onDecide: c.decide,
                    child: CandidateCardView(
                        config: config, candidate: card, icon: widget.icon),
                  ),
                  const SizedBox(height: 12),
                  if (c.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        Expanded(
                          child: Text(c.error!,
                              style: TextStyle(color: theme.colorScheme.error)),
                        ),
                        if (c.canRetry)
                          TextButton(
                              onPressed: c.retry, child: const Text('再送')),
                      ]),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: c.submitting
                              ? null
                              : () => c.decide(SwipeIntent.negative),
                          icon: const Icon(Icons.close),
                          label: Text(config.intentLabels.negative),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: c.submitting
                              ? null
                              : () => c.decide(SwipeIntent.positive),
                          icon: const Icon(Icons.favorite_border),
                          label: Text(config.intentLabels.positive),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class MatchesScreen extends StatelessWidget {
  const MatchesScreen(
      {super.key, required this.controller, required this.config});
  final MatchesController controller;
  final ServiceConfig config;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.error != null) {
          return _Message(
              text: controller.error!,
              action: FilledButton(
                  onPressed: controller.refresh, child: const Text('再読み込み')));
        }
        if (controller.entries.isEmpty) {
          return const _Message(text: '成立すると、ここから会話を始められます。');
        }
        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView(
            children: [
              for (final e in controller.entries)
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.chat_outlined)),
                  title: Text(e.title),
                  subtitle: const Text('会話を開く'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // A leftover snackbar would cover the message input.
                    ScaffoldMessenger.of(context).clearSnackBars();
                    Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => ChatScreen(
                          api: controller.api,
                          entry: e,
                          meId: controller.meId),
                    ));
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen(
      {super.key, required this.api, required this.entry, required this.meId});
  final MatchingApi api;
  final MatchEntry entry;
  final String meId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatController _chat =
      ChatController(widget.api, widget.entry.match.id)..load();
  final _input = TextEditingController();

  @override
  void dispose() {
    _chat.dispose();
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    await _chat.send(text);
  }

  Future<void> _report() async {
    final reason = await showDialog<ReportReason>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('通報する理由'),
        children: [
          for (final (r, label) in const [
            (ReportReason.spam, 'スパム・宣伝'),
            (ReportReason.harassment, '嫌がらせ'),
            (ReportReason.inappropriateContent, '不適切な内容'),
            (ReportReason.fakeProfile, 'なりすまし'),
            (ReportReason.other, 'その他'),
          ])
            SimpleDialogOption(
                onPressed: () => Navigator.pop(context, r), child: Text(label)),
        ],
      ),
    );
    if (reason == null || !mounted) return;
    try {
      await widget.api.report(widget.entry.counterpartId, reason, '');
      _toast('通報を受け付けました。');
    } catch (e) {
      _toast(describeFailure(e));
    }
  }

  Future<void> _block() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ブロックしますか？'),
        content: const Text('この相手との会話は終了し、お互いに表示されなくなります。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('やめる')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ブロック')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await widget.api.block(widget.entry.counterpartId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _toast(describeFailure(e));
    }
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry.title),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'その他の操作',
            onSelected: (v) => v == 'report' ? _report() : _block(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'report', child: Text('通報する')),
              PopupMenuItem(value: 'block', child: Text('ブロックする')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _chat,
          builder: (context, _) => Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_chat.messages.isEmpty && _chat.outgoing.isEmpty)
                      const Text('最初のメッセージを送りましょう。'),
                    for (final m in _chat.messages)
                      _Bubble(
                          text: m.body,
                          mine: m.senderId == widget.meId,
                          colors: colors),
                    for (final o in _chat.outgoing)
                      _Bubble(
                        text: o.body,
                        mine: true,
                        colors: colors,
                        status: o.state == OutgoingState.sending
                            ? '送信中…'
                            : o.error,
                        onRetry: o.state == OutgoingState.failed && !_chat.closed
                            ? () => _chat.retry(o)
                            : null,
                        onDiscard: o.state == OutgoingState.failed
                            ? () => _chat.discard(o)
                            : null,
                      ),
                    if (_chat.error != null)
                      Text(_chat.error!, style: TextStyle(color: colors.error)),
                  ],
                ),
              ),
              if (_chat.closed)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('この会話は終了しました。'),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 8, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _input,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: const InputDecoration(labelText: 'メッセージ'),
                        ),
                      ),
                      IconButton(
                        tooltip: '送信',
                        onPressed: _send,
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.text,
    required this.mine,
    required this.colors,
    this.status,
    this.onRetry,
    this.onDiscard,
  });

  final String text;
  final bool mine;
  final ColorScheme colors;
  final String? status;
  final VoidCallback? onRetry;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
          color: mine ? colors.primaryContainer : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
                label: mine ? '自分' : '相手', child: Text(text)),
            if (status != null)
              Text(status!, style: Theme.of(context).textTheme.bodySmall),
            if (onRetry != null || onDiscard != null)
              Wrap(children: [
                if (onRetry != null)
                  TextButton(onPressed: onRetry, child: const Text('再送')),
                if (onDiscard != null)
                  TextButton(onPressed: onDiscard, child: const Text('取り消す')),
              ]),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen(
      {super.key, required this.api, required this.me, required this.onWithdrawn});
  final MatchingApi api;
  final Member? me;
  final VoidCallback onWithdrawn;

  Future<void> _withdraw(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退会しますか？'),
        content: const Text('プロフィールは表示されなくなり、すべての会話が終了します。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('やめる')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('退会する')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.withdraw();
      onWithdrawn();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeFailure(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: Text(me?.displayName ?? '読み込み中'),
          subtitle: const Text('会員情報'),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('退会する'),
          onTap: () => _withdraw(context),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.action});
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    );
  }
}
