import 'package:flutter_test/flutter_test.dart';
import 'package:munner_ai/main.dart';

void main() {
  testWidgets('Verify Login Screen Loaded', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MunnerAiApp());

    // Verify that the logo "மு" is shown.
    expect(find.text('மு'), findsOneWidget);
    
    // Verify that the title "முன்னேறு AI" is shown.
    expect(find.text('முன்னேறு AI'), findsOneWidget);
  });
}
