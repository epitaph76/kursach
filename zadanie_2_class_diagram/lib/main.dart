import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const ClassDiagramApp());
}

class ClassDiagramApp extends StatelessWidget {
  const ClassDiagramApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Задание 2 - Диаграмма классов',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const ClassDiagramPage(),
    );
  }
}

class ClassInfo {
  ClassInfo({required this.name, required this.bases});

  final String name;
  final List<String> bases;
}

class DiagramLayout {
  DiagramLayout({required this.size, required this.positions});

  final Size size;
  final Map<String, Offset> positions;
}

List<ClassInfo> parseHeaderClasses(String content) {
  final withoutComments = content
      .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), ' ')
      .replaceAll(RegExp(r'//.*'), ' ');
  final regex = RegExp(
    r'\b(?:class|struct)\s+([A-Za-z_]\w*)\s*(?::\s*([^{;]+))?\s*(?:\{|;)',
    multiLine: true,
  );

  final classes = <String, ClassInfo>{};
  for (final match in regex.allMatches(withoutComments)) {
    final name = match.group(1)!;
    final basesText = match.group(2);
    final bases = basesText == null
        ? <String>[]
        : basesText
              .split(',')
              .map(_cleanBaseClassName)
              .where((base) => base.isNotEmpty)
              .toList();

    classes[name] = ClassInfo(name: name, bases: bases);
  }

  return classes.values.toList();
}

String _cleanBaseClassName(String value) {
  final cleaned = value
      .replaceAll(RegExp(r'\b(public|private|protected|virtual)\b'), ' ')
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .trim();
  if (cleaned.isEmpty) {
    return '';
  }
  return cleaned.split(RegExp(r'\s+')).last.split('::').last;
}

DiagramLayout buildDiagramLayout(List<ClassInfo> classes) {
  const nodeWidth = 160.0;
  const nodeHeight = 68.0;
  const xGap = 80.0;
  const yGap = 110.0;
  const padding = 40.0;

  final byName = {for (final item in classes) item.name: item};
  final levelCache = <String, int>{};

  int levelOf(String name, Set<String> stack) {
    if (levelCache.containsKey(name)) {
      return levelCache[name]!;
    }
    final item = byName[name];
    if (item == null || item.bases.isEmpty || stack.contains(name)) {
      levelCache[name] = 0;
      return 0;
    }

    final knownBases = item.bases.where(byName.containsKey).toList();
    if (knownBases.isEmpty) {
      levelCache[name] = 0;
      return 0;
    }

    final nextStack = {...stack, name};
    final level =
        1 +
        knownBases
            .map((base) => levelOf(base, nextStack))
            .reduce((a, b) => math.max(a, b));
    levelCache[name] = level;
    return level;
  }

  for (final item in classes) {
    levelOf(item.name, {});
  }

  final levels = <int, List<ClassInfo>>{};
  for (final item in classes) {
    levels.putIfAbsent(levelCache[item.name] ?? 0, () => []).add(item);
  }
  for (final level in levels.values) {
    level.sort((a, b) => a.name.compareTo(b.name));
  }

  final positions = <String, Offset>{};
  var maxWidth = 0.0;
  var maxLevel = 0;
  for (final entry in levels.entries) {
    final level = entry.key;
    final items = entry.value;
    maxLevel = math.max(maxLevel, level);
    final rowWidth = items.length * nodeWidth + (items.length - 1) * xGap;
    maxWidth = math.max(maxWidth, rowWidth);
  }

  for (final entry in levels.entries) {
    final level = entry.key;
    final items = entry.value;
    final rowWidth = items.length * nodeWidth + (items.length - 1) * xGap;
    var x = padding + (maxWidth - rowWidth) / 2;
    final y = padding + level * (nodeHeight + yGap);

    for (final item in items) {
      positions[item.name] = Offset(x, y);
      x += nodeWidth + xGap;
    }
  }

  final width = math.max(720.0, maxWidth + padding * 2);
  final height = math.max(
    420.0,
    padding * 2 + (maxLevel + 1) * nodeHeight + maxLevel * yGap,
  );

  return DiagramLayout(size: Size(width, height), positions: positions);
}

class ClassDiagramPage extends StatefulWidget {
  const ClassDiagramPage({super.key});

  @override
  State<ClassDiagramPage> createState() => _ClassDiagramPageState();
}

class _ClassDiagramPageState extends State<ClassDiagramPage> {
  List<ClassInfo> _classes = [];
  String? _fileName;
  String? _message;

  Future<void> _pickHeaderFile() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Выберите .h файл',
      type: FileType.custom,
      allowedExtensions: ['h', 'hpp'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    try {
      final file = result.files.single;
      final text = file.bytes != null
          ? String.fromCharCodes(file.bytes!)
          : await File(file.path!).readAsString();
      final classes = parseHeaderClasses(text);

      if (!mounted) {
        return;
      }

      setState(() {
        _classes = classes;
        _fileName = file.path ?? file.name;
        _message = classes.isEmpty
            ? 'В файле не найдены объявления class или struct'
            : 'Найдено классов: ${classes.length}';
      });
    } catch (error) {
      setState(() {
        _message = 'Ошибка чтения файла: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final layout = buildDiagramLayout(_classes);

    return Scaffold(
      appBar: AppBar(title: const Text('Задание 2. Диаграмма классов из .h')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _pickHeaderFile,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Выбрать .h файл'),
                ),
                Text(_fileName == null ? 'Файл не выбран' : 'Файл: $_fileName'),
              ],
            ),
            if (_message != null) ...[
              const SizedBox(height: 10),
              Text(_message!, style: Theme.of(context).textTheme.bodyMedium),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _classes.isEmpty
                    ? const Center(
                        child: Text(
                          'Выберите заголовочный файл C++.\nНапример: class Student : public Person { };',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: InteractiveViewer(
                          minScale: 0.3,
                          maxScale: 3,
                          boundaryMargin: const EdgeInsets.all(300),
                          child: CustomPaint(
                            size: layout.size,
                            painter: ClassDiagramPainter(
                              classes: _classes,
                              layout: layout,
                              colorScheme: Theme.of(context).colorScheme,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ClassDiagramPainter extends CustomPainter {
  ClassDiagramPainter({
    required this.classes,
    required this.layout,
    required this.colorScheme,
  });

  final List<ClassInfo> classes;
  final DiagramLayout layout;
  final ColorScheme colorScheme;

  static const nodeWidth = 160.0;
  static const nodeHeight = 68.0;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = colorScheme.surface;
    canvas.drawRect(Offset.zero & size, background);

    _drawLinks(canvas);
    _drawNodes(canvas);
  }

  void _drawLinks(Canvas canvas) {
    final byName = {for (final item in classes) item.name: item};
    final linePaint = Paint()
      ..color = colorScheme.outline
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (final item in classes) {
      final childPosition = layout.positions[item.name];
      if (childPosition == null) {
        continue;
      }
      final childTop = childPosition + const Offset(nodeWidth / 2, 0);

      for (final base in item.bases) {
        if (!byName.containsKey(base)) {
          continue;
        }
        final basePosition = layout.positions[base];
        if (basePosition == null) {
          continue;
        }

        final baseBottom =
            basePosition + const Offset(nodeWidth / 2, nodeHeight);
        final middleY = (baseBottom.dy + childTop.dy) / 2;
        final path = Path()
          ..moveTo(baseBottom.dx, baseBottom.dy)
          ..lineTo(baseBottom.dx, middleY)
          ..lineTo(childTop.dx, middleY)
          ..lineTo(childTop.dx, childTop.dy);
        canvas.drawPath(path, linePaint);

        final arrow = Path()
          ..moveTo(childTop.dx, childTop.dy)
          ..lineTo(childTop.dx - 7, childTop.dy - 10)
          ..lineTo(childTop.dx + 7, childTop.dy - 10)
          ..close();
        canvas.drawPath(arrow, Paint()..color = colorScheme.outline);
      }
    }
  }

  void _drawNodes(Canvas canvas) {
    final borderPaint = Paint()
      ..color = colorScheme.primary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final fillPaint = Paint()
      ..color = colorScheme.primaryContainer.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    for (final item in classes) {
      final position = layout.positions[item.name];
      if (position == null) {
        continue;
      }
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(position.dx, position.dy, nodeWidth, nodeHeight),
        const Radius.circular(8),
      );
      canvas.drawRRect(rect, fillPaint);
      canvas.drawRRect(rect, borderPaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: item.name,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        maxLines: 2,
        ellipsis: '...',
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: nodeWidth - 18);

      textPainter.paint(
        canvas,
        Offset(
          position.dx + (nodeWidth - textPainter.width) / 2,
          position.dy + (nodeHeight - textPainter.height) / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant ClassDiagramPainter oldDelegate) {
    return oldDelegate.classes != classes ||
        oldDelegate.layout != layout ||
        oldDelegate.colorScheme != colorScheme;
  }
}
