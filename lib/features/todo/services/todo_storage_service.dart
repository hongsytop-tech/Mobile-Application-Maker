import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/services/sync_manager.dart';
import '../models/todo_category.dart';
import '../models/todo_item.dart';

class TodoStorageService {
  static const _categoriesKey = 'todo_categories_v1';
  static const _itemsKey = 'todo_items_v1';

  Future<List<TodoCategory>> loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_categoriesKey) ?? const [];
    return list.map(TodoCategory.fromJsonString).toList();
  }

  Future<void> saveCategories(List<TodoCategory> categories) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _categoriesKey, categories.map((c) => c.toJsonString()).toList());
    SyncManager.instance.markDirty();
  }

  Future<List<TodoItem>> loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_itemsKey) ?? const [];
    return list.map(TodoItem.fromJsonString).toList();
  }

  Future<void> saveItems(List<TodoItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _itemsKey, items.map((i) => i.toJsonString()).toList());
    SyncManager.instance.markDirty();
  }
}
