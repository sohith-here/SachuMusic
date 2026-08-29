import 'package:flutter_test/flutter_test.dart';
import 'package:sachu_music/main.dart';

void main() {
  testWidgets('Sachu Music app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const SachuMusicApp());

    expect(find.text('Sachu Music'), findsOneWidget);
  });
}
