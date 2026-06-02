import 'package:flutter_test/flutter_test.dart';
import 'package:snapcity/main.dart';

void main() {
  testWidgets('SnapCity renders home dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(const SnapCityApp());

    expect(find.text('Making Gulshan\nbetter'), findsOneWidget);
    expect(find.text('Confirm nearby issue'), findsOneWidget);
  });
}
