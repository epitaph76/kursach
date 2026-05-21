import 'package:flutter_test/flutter_test.dart';
import 'package:zadanie_1_files/main.dart';

void main() {
  testWidgets('restaurant app shows main title', (tester) async {
    await tester.pumpWidget(const RestaurantApp());

    expect(find.textContaining('Ресторан'), findsWidgets);
    expect(find.text('Добавить'), findsOneWidget);
  });
}
