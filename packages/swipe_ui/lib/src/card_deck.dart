import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart';
import 'package:swipe_core/swipe_core.dart';

/// Renders a card's fields in the order the service configuration defines.
class CandidateCardView extends StatelessWidget {
  const CandidateCardView({
    super.key,
    required this.config,
    required this.candidate,
    this.icon,
  });

  final ServiceConfig config;
  final Candidate candidate;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 120,
            color: colors.primaryContainer,
            child: ExcludeSemantics(
              child: Icon(
                icon ??
                    (config.targetKind == TargetKind.listing
                        ? Icons.work_outline
                        : Icons.person_outline),
                size: 56,
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
                    style: theme.textTheme.headlineSmall,
                    semanticsLabel: candidate.title),
                for (final spec in config.fields)
                  if (candidate.attributes[spec.key] case final value?)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _FieldView(spec: spec, value: value),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldView extends StatelessWidget {
  const _FieldView({required this.spec, required this.value});
  final FieldSpec spec;
  final Object value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = Text(spec.label,
        style: theme.textTheme.labelLarge
            ?.copyWith(color: theme.colorScheme.primary));
    return switch ((spec.kind, value)) {
      (FieldKind.tags, final List<Object?> tags) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            label,
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final t in tags) Chip(label: Text('$t')),
            ]),
          ],
        ),
      _ => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [label, const SizedBox(height: 2), Text('$value')],
        ),
    };
  }
}

/// A draggable card. Dragging right past the threshold means positive,
/// left means negative. Every swipe has a button and a screen-reader action
/// equivalent, so swiping is never required.
class SwipeCard extends StatefulWidget {
  const SwipeCard({
    super.key,
    required this.child,
    required this.labels,
    required this.onDecide,
    this.enabled = true,
  });

  final Widget child;
  final IntentLabels labels;
  final ValueChanged<SwipeIntent> onDecide;
  final bool enabled;

  @override
  State<SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<SwipeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _settle = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 180));
  double _dx = 0;
  double _from = 0;

  @override
  void initState() {
    super.initState();
    _settle.addListener(() {
      setState(() => _dx = _from * (1 - Curves.easeOut.transform(_settle.value)));
    });
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  void _end(double width, double velocity) {
    final threshold = width * 0.28;
    final intent = (_dx > threshold || velocity > 900)
        ? SwipeIntent.positive
        : (_dx < -threshold || velocity < -900)
            ? SwipeIntent.negative
            : null;
    if (intent != null) widget.onDecide(intent);
    _from = _dx;
    if (MediaQuery.of(context).disableAnimations) {
      setState(() => _dx = 0);
    } else {
      _settle.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final progress = (_dx / (width * 0.28)).clamp(-1.0, 1.0);
      return Semantics(
        customSemanticsActions: widget.enabled
            ? {
                CustomSemanticsAction(label: widget.labels.positive): () =>
                    widget.onDecide(SwipeIntent.positive),
                CustomSemanticsAction(label: widget.labels.negative): () =>
                    widget.onDecide(SwipeIntent.negative),
              }
            : const {},
        child: GestureDetector(
          excludeFromSemantics: true,
          onHorizontalDragStart: widget.enabled
              ? (_) {
                  _settle.stop();
                }
              : null,
          onHorizontalDragUpdate: widget.enabled
              ? (d) => setState(() => _dx += d.delta.dx)
              : null,
          onHorizontalDragEnd: widget.enabled
              ? (d) => _end(width, d.velocity.pixelsPerSecond.dx)
              : null,
          child: Transform.translate(
            offset: Offset(_dx, 0),
            child: Transform.rotate(
              angle: MediaQuery.of(context).disableAnimations
                  ? 0
                  : progress * 0.08,
              child: Stack(
                children: [
                  widget.child,
                  if (progress.abs() > 0.15)
                    Positioned(
                      top: 16,
                      left: progress > 0 ? 16 : null,
                      right: progress < 0 ? 16 : null,
                      child: ExcludeSemantics(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: progress > 0 ? colors.primary : colors.error,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            progress > 0
                                ? widget.labels.positive
                                : widget.labels.negative,
                            style: TextStyle(
                                color: progress > 0
                                    ? colors.onPrimary
                                    : colors.onError,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}
