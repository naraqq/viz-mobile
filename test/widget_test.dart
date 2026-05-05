import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viz_flutter/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: VizApp()));
    await tester.pump();
    expect(find.byType(ProviderScope), findsOneWidget);
  });
}
