// carolina/frontend/test/widget_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:carolina/main.dart';

void main() {
  testWidgets('Prueba básica', (WidgetTester tester) async {
    await tester.pumpWidget(const AppCarolina());
    expect(find.byType(AppCarolina), findsOneWidget);
  });
}