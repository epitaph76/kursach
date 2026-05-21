import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const RestaurantApp());
}

class RestaurantApp extends StatelessWidget {
  const RestaurantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Задание 1 - Ресторан',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const RestaurantHomePage(),
    );
  }
}

class Dish {
  Dish({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.ingredients,
  });

  final String id;
  final String name;
  final String category;
  final double price;
  final List<String> ingredients;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'price': price,
      'ingredients': ingredients,
    };
  }

  factory Dish.fromJson(Map<String, dynamic> json) {
    final rawIngredients = json['ingredients'];
    final ingredients = rawIngredients is List
        ? rawIngredients.map((item) => item.toString()).toList()
        : rawIngredients
              .toString()
              .split(',')
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toList();

    return Dish(
      id: json['id'].toString(),
      name: json['name'].toString(),
      category: json['category'].toString(),
      price: double.tryParse(json['price'].toString()) ?? 0,
      ingredients: ingredients,
    );
  }

  Dish copyWith({
    String? id,
    String? name,
    String? category,
    double? price,
    List<String>? ingredients,
  }) {
    return Dish(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      price: price ?? this.price,
      ingredients: ingredients ?? this.ingredients,
    );
  }
}

class RestaurantHomePage extends StatefulWidget {
  const RestaurantHomePage({super.key});

  @override
  State<RestaurantHomePage> createState() => _RestaurantHomePageState();
}

class _RestaurantHomePageState extends State<RestaurantHomePage> {
  final List<Dish> _dishes = [
    Dish(
      id: '1',
      name: 'Борщ',
      category: 'Суп',
      price: 250,
      ingredients: ['свекла', 'капуста', 'говядина'],
    ),
    Dish(
      id: '2',
      name: 'Цезарь',
      category: 'Салат',
      price: 320,
      ingredients: ['курица', 'салат', 'сыр', 'соус'],
    ),
  ];

  String? _currentFileName;

  int get _nextId {
    final numbers = _dishes
        .map((dish) => int.tryParse(dish.id) ?? 0)
        .where((number) => number > 0);
    return numbers.isEmpty ? 1 : numbers.reduce((a, b) => a > b ? a : b) + 1;
  }

  Future<void> _addDish() async {
    final dish = await _showDishDialog();
    if (dish == null) {
      return;
    }
    setState(() {
      _dishes.add(dish.copyWith(id: _nextId.toString()));
    });
  }

  Future<void> _editDish(Dish oldDish) async {
    final dish = await _showDishDialog(dish: oldDish);
    if (dish == null) {
      return;
    }
    setState(() {
      final index = _dishes.indexWhere((item) => item.id == oldDish.id);
      if (index != -1) {
        _dishes[index] = dish.copyWith(id: oldDish.id);
      }
    });
  }

  void _deleteDish(Dish dish) {
    setState(() {
      _dishes.removeWhere((item) => item.id == dish.id);
    });
    _showMessage('Блюдо удалено');
  }

  Future<Dish?> _showDishDialog({Dish? dish}) async {
    final nameController = TextEditingController(text: dish?.name ?? '');
    final categoryController = TextEditingController(
      text: dish?.category ?? '',
    );
    final priceController = TextEditingController(
      text: dish == null ? '' : dish.price.toStringAsFixed(2),
    );
    final ingredientsController = TextEditingController(
      text: dish?.ingredients.join(', ') ?? '',
    );

    return showDialog<Dish>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(dish == null ? 'Добавить блюдо' : 'Изменить блюдо'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Название'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(labelText: 'Категория'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Цена'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: ingredientsController,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Ингредиенты через запятую',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                final category = categoryController.text.trim();
                final price = double.tryParse(
                  priceController.text.replaceAll(',', '.'),
                );
                final ingredients = ingredientsController.text
                    .split(',')
                    .map((item) => item.trim())
                    .where((item) => item.isNotEmpty)
                    .toList();

                if (name.isEmpty || category.isEmpty || price == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Заполните название, категорию и цену'),
                    ),
                  );
                  return;
                }

                Navigator.of(context).pop(
                  Dish(
                    id: dish?.id ?? '',
                    name: name,
                    category: category,
                    price: price,
                    ingredients: ingredients,
                  ),
                );
              },
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveToJson() async {
    final data = {
      'restaurant': 'Restaurant',
      'dishes': _dishes.map((dish) => dish.toJson()).toList(),
    };
    const encoder = JsonEncoder.withIndent('  ');
    final jsonText = encoder.convert(data);
    final bytes = Uint8List.fromList(utf8.encode(jsonText));

    final path = await FilePicker.saveFile(
      dialogTitle: 'Сохранить данные ресторана',
      fileName: 'restaurant.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: bytes,
    );

    if (!mounted || path == null) {
      return;
    }

    setState(() {
      _currentFileName = path;
    });
    _showMessage('Данные сохранены в JSON');
  }

  Future<void> _loadFromJson() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Выберите JSON-файл',
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    try {
      final file = result.files.single;
      final text = file.bytes != null
          ? utf8.decode(file.bytes!)
          : await File(file.path!).readAsString();
      final decoded = jsonDecode(text);
      final rawDishes = decoded is Map<String, dynamic>
          ? decoded['dishes']
          : decoded;
      if (rawDishes is! List) {
        throw const FormatException('В JSON нет списка dishes');
      }

      final dishes = rawDishes
          .map((item) => Dish.fromJson(Map<String, dynamic>.from(item)))
          .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _dishes
          ..clear()
          ..addAll(dishes);
        _currentFileName = file.path ?? file.name;
      });
      _showMessage('Данные загружены из JSON');
    } catch (error) {
      _showMessage('Ошибка загрузки: $error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Задание 1. Ресторан: блюда и ингредиенты'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: _addDish,
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить'),
                ),
                OutlinedButton.icon(
                  onPressed: _saveToJson,
                  icon: const Icon(Icons.save),
                  label: const Text('Сохранить JSON'),
                ),
                OutlinedButton.icon(
                  onPressed: _loadFromJson,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Загрузить JSON'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _currentFileName == null
                  ? 'Файл не выбран'
                  : 'Текущий файл: $_currentFileName',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _dishes.isEmpty ? _buildEmptyState() : _buildTable(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Text('Список пуст. Добавьте блюдо или загрузите JSON-файл.'),
    );
  }

  Widget _buildTable() {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Scrollbar(
        child: SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('ID')),
                DataColumn(label: Text('Название')),
                DataColumn(label: Text('Категория')),
                DataColumn(label: Text('Цена')),
                DataColumn(label: Text('Ингредиенты')),
                DataColumn(label: Text('Действия')),
              ],
              rows: _dishes.map((dish) {
                return DataRow(
                  cells: [
                    DataCell(Text(dish.id)),
                    DataCell(Text(dish.name)),
                    DataCell(Text(dish.category)),
                    DataCell(Text(dish.price.toStringAsFixed(2))),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: Text(dish.ingredients.join(', ')),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Изменить',
                            icon: const Icon(Icons.edit),
                            onPressed: () => _editDish(dish),
                          ),
                          IconButton(
                            tooltip: 'Удалить',
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteDish(dish),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
