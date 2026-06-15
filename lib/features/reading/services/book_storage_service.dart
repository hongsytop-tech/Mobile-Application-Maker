import 'package:shared_preferences/shared_preferences.dart';

import '../models/book.dart';

class BookStorageService {
  static const _key = 'books_v1';

  Future<List<Book>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? const [];
    return list.map(Book.fromJsonString).toList();
  }

  Future<void> saveAll(List<Book> books) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, books.map((e) => e.toJsonString()).toList());
  }
}
