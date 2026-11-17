import 'package:material_ui/material_ui.dart';
import 'package:swipe_core/swipe_core.dart';
import 'package:swipe_ui/swipe_ui.dart';

/// Only app-specific choices live here: data source, colours, icon.
/// Fields, labels and the owner-approval rule come from `workConfig`.
void main() {
  final world = DemoWorld.work();
  runApp(SwipeMatchingApp(
    api: world.api,
    branding: const AppBranding(
      appName: '仕事相談',
      seedColor: Color(0xff2b4c7e),
      cardIcon: Icons.work_outline,
    ),
    banner: '架空データで試用中（閉じると消えます）',
  ));
}
