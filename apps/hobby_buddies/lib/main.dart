import 'package:material_ui/material_ui.dart';
import 'package:swipe_core/swipe_core.dart';
import 'package:swipe_ui/swipe_ui.dart';

/// Only app-specific choices live here: data source, colours, icon.
/// Fields, labels and the match rule come from `hobbyConfig` in swipe_core.
void main() {
  final world = DemoWorld.hobby();
  runApp(SwipeMatchingApp(
    api: world.api,
    branding: const AppBranding(
      appName: '趣味仲間',
      seedColor: Color(0xff245844),
      cardIcon: Icons.landscape_outlined,
    ),
    banner: '架空データで試用中（閉じると消えます）',
  ));
}
