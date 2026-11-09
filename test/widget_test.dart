import 'package:flutter_test/flutter_test.dart';
import 'package:organizador_financeiro/main.dart';

void main() {
  testWidgets('App basic smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const FinancialOrganizerApp());
    expect(find.byType(FinancialOrganizerApp), findsOneWidget);
  });
}
