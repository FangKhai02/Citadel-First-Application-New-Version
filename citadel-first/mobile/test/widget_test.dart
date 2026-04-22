import 'package:flutter_test/flutter_test.dart';
import 'package:citadel_first/main.dart';

void main() {
  testWidgets('App renders splash screen on launch', (WidgetTester tester) async {
    await tester.pumpWidget(const CitadelFirstApp());
    await tester.pump();
    expect(find.text('Citadel First'), findsOneWidget);
  });
}
