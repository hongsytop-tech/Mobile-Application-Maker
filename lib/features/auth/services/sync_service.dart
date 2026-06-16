import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_service.dart';

/// 저장소 키 → 클라우드 컬럼명 매핑
const _keyMap = <String, String>{
  'books_v1': 'books',
  'quotes_v1': 'quotes',
  'diaries_v1': 'diaries',
  'todo_categories_v1': 'todo_categories',
  'todo_items_v1': 'todo_items',
};

class SyncStats {
  final int total;
  final Map<String, int> perKey;
  const SyncStats({required this.total, required this.perKey});
}

class SyncService {
  /// 로컬 → 클라우드 (백업)
  static Future<SyncStats> backupToCloud() async {
    final prefs = await SharedPreferences.getInstance();
    final perKey = <String, int>{};
    final lists = <String, List<String>>{};
    for (final entry in _keyMap.entries) {
      final list = prefs.getStringList(entry.key) ?? const <String>[];
      lists[entry.value] = list;
      perKey[entry.value] = list.length;
    }

    await SupabaseService.pushUserData(
      books: lists['books']!,
      quotes: lists['quotes']!,
      diaries: lists['diaries']!,
      todoCategories: lists['todo_categories']!,
      todoItems: lists['todo_items']!,
    );

    final total = perKey.values.fold<int>(0, (a, b) => a + b);
    return SyncStats(total: total, perKey: perKey);
  }

  /// 클라우드 → 로컬 (복원) — 기존 로컬 데이터를 덮어씁니다.
  static Future<SyncStats> restoreFromCloud() async {
    final data = await SupabaseService.pullUserData();
    if (data == null) {
      return const SyncStats(total: 0, perKey: {});
    }

    final prefs = await SharedPreferences.getInstance();
    final perKey = <String, int>{};
    int total = 0;
    for (final entry in _keyMap.entries) {
      final localKey = entry.key;
      final cloudKey = entry.value;
      final raw = data[cloudKey];
      final list = raw is List ? raw.map((e) => e as String).toList() : <String>[];
      await prefs.setStringList(localKey, list);
      perKey[cloudKey] = list.length;
      total += list.length;
    }
    return SyncStats(total: total, perKey: perKey);
  }
}
