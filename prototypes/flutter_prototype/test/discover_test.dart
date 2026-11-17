import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_matching_prototype/main.dart';

void main() {
  testWidgets('buttons, swipe, conversation and scenario switch', (tester) async {
    await tester.pumpWidget(const SwipeMatchingApp());
    await tester.tap(find.text('興味あり'));
    await tester.pumpAndSettle();
    await tester.drag(find.byKey(const ValueKey('h2')), const Offset(-220, 0));
    await tester.pumpAndSettle();
    expect(find.text('すべての候補を確認しました'), findsOneWidget);
    await tester.tap(find.text('会話を開く'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'こんにちは');
    await tester.tap(find.text('送信'));
    await tester.pumpAndSettle();
    expect(find.text('こんにちは'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('仕事相談'));
    await tester.pumpAndSettle();
    expect(find.text('問い合わせの一次対応を整理'), findsOneWidget);
    expect(find.text('会話を開く'), findsNothing);
    await tester.tap(find.text('応募する'));
    await tester.pumpAndSettle();
    expect(find.text('会話を開く'), findsOneWidget);
  });
}
