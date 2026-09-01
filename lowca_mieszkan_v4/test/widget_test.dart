import 'package:flutter_test/flutter_test.dart';
import 'package:lowca_mieszkan_android/main.dart';

void main() {
  testWidgets('uruchamia ekran główny Łowcy Mieszkań', (tester) async {
    await tester.pumpWidget(const LowcaApp());
    await tester.pump();

    expect(find.byType(LowcaApp), findsOneWidget);
  });
}
