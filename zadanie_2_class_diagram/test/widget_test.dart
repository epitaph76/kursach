import 'package:flutter_test/flutter_test.dart';
import 'package:zadanie_2_class_diagram/main.dart';

void main() {
  testWidgets('class diagram app shows file button', (tester) async {
    await tester.pumpWidget(const ClassDiagramApp());

    expect(find.text('Выбрать .h файл'), findsOneWidget);
  });

  test('parser finds inheritance from header text', () {
    final classes = parseHeaderClasses('''
class Person {};
class Student : public Person {};
class Teacher : public Person {};
''');

    expect(classes.length, 3);
    expect(classes.firstWhere((item) => item.name == 'Student').bases, [
      'Person',
    ]);
  });
}
