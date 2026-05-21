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

  test('layout places inherited class under its real parent', () {
    final classes = parseHeaderClasses('''
class Entity {};
class Person : public Entity {};
class Employee : public Person {};
class Order : public Entity {};
class OnlineOrder : public Order {};
''');
    final layout = buildDiagramLayout(classes);

    final onlineOrderX = layout.positions['OnlineOrder']!.dx;
    final orderX = layout.positions['Order']!.dx;
    final personX = layout.positions['Person']!.dx;

    expect(
      (onlineOrderX - orderX).abs(),
      lessThan((onlineOrderX - personX).abs()),
    );
  });
}
