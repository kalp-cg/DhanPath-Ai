import 'database_helper.dart';

class CategoryModel {
  final int? id;
  final String name;
  final String icon;
  final String color;
  final String type; // 'expense' or 'income'
  final bool isDefault;

  CategoryModel({
    this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.type,
    this.isDefault = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color': color,
      'type': type,
      'is_default': isDefault ? 1 : 0,
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'],
      name: map['name'],
      icon: map['icon'],
      color: map['color'],
      type: map['type'],
      isDefault: map['is_default'] == 1,
    );
  }
}

class CategoryService {
  final DatabaseHelper _dbContext = DatabaseHelper.instance;

  // Default Categories
  final List<CategoryModel> _defaultCategories = [
    CategoryModel(
      name: 'Food',
      icon: 'fastfood',
      color: '0xFFF44336',
      type: 'expense',
      isDefault: true,
    ),
    CategoryModel(
      name: 'Transport',
      icon: 'directions_bus',
      color: '0xFF2196F3',
      type: 'expense',
      isDefault: true,
    ),
    CategoryModel(
      name: 'Shopping',
      icon: 'shopping_bag',
      color: '0xFFE91E63',
      type: 'expense',
      isDefault: true,
    ),
    CategoryModel(
      name: 'Entertainment',
      icon: 'movie',
      color: '0xFF9C27B0',
      type: 'expense',
      isDefault: true,
    ),
    CategoryModel(
      name: 'Bills',
      icon: 'receipt',
      color: '0xFFFF9800',
      type: 'expense',
      isDefault: true,
    ),
    CategoryModel(
      name: 'Health',
      icon: 'medical_services',
      color: '0xFF4CAF50',
      type: 'expense',
      isDefault: true,
    ),
    CategoryModel(
      name: 'Salary',
      icon: 'attach_money',
      color: '0xFF4CAF50',
      type: 'income',
      isDefault: true,
    ),
    CategoryModel(
      name: 'Investment',
      icon: 'trending_up',
      color: '0xFF009688',
      type: 'income',
      isDefault: true,
    ),
  ];

  Future<List<CategoryModel>> getCategories(String type) async {
    final db = await _dbContext.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'custom_categories',
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'name ASC',
    );

    List<CategoryModel> userCategories = List.generate(maps.length, (i) {
      return CategoryModel.fromMap(maps[i]);
    });

    // Merge with defaults (user categories take precedence on name collision if we wanted,
    // but here we just show both or filter. For simplicity, just combining unique names or showing all)
    // Actually, typically we seed the DB with defaults on first run.
    // Let's assume we return standard defaults + user customs.

    // Filter defaults based on type
    final defaults = _defaultCategories.where((c) => c.type == type).toList();

    // Combine (avoid duplicates if name matches?)
    // Simple approach: Return defaults + user created.
    return [...defaults, ...userCategories];
  }

  Future<int> addCategory(CategoryModel category) async {
    final db = await _dbContext.database;
    return await db.insert('custom_categories', category.toMap());
  }

  Future<int> deleteCategory(int id) async {
    final db = await _dbContext.database;
    return await db.delete(
      'custom_categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
