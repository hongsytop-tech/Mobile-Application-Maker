import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_service.dart';

/// 리스트(StringList)로 저장되는 데이터 키 ↔ 클라우드 컬럼명
const _listKeyMap = <String, String>{
  'books_v1': 'books',
  'quotes_v1': 'quotes',
  'diaries_v1': 'diaries',
  'todo_categories_v1': 'todo_categories',
  'todo_items_v1': 'todo_items',
  'memos_v1': 'memos',
};

/// 단일 String으로 저장되는 설정 키들 (settings jsonb에 한꺼번에 저장)
const _settingKeys = <String>[
  'quote_rotation_settings_v1',
];

class SyncStats {
  final int total;
  final Map<String, int> perKey;
  const SyncStats({required this.total, required this.perKey});
}

class SyncService {
  /// 로컬 → 클라우드
  static Future<SyncStats> backupToCloud() async {
    final prefs = await SharedPreferences.getInstance();
    final perKey = <String, int>{};
    final lists = <String, List<String>>{};
    for (final entry in _listKeyMap.entries) {
      final list = prefs.getStringList(entry.key) ?? const <String>[];
      lists[entry.value] = list;
      perKey[entry.value] = list.length;
    }

    final settings = <String, dynamic>{};
    for (final key in _settingKeys) {
      final v = prefs.getString(key);
      if (v != null) settings[key] = v;
    }

    await SupabaseService.pushUserData(
      books: lists['books']!,
      quotes: lists['quotes']!,
      diaries: lists['diaries']!,
      todoCategories: lists['todo_categories']!,
      todoItems: lists['todo_items']!,
      memos: lists['memos']!,
      settings: settings,
    );

    final total = perKey.values.fold<int>(0, (a, b) => a + b);
    return SyncStats(total: total, perKey: perKey);
  }

  /// 클라우드 → 로컬 (덮어쓰기)
  static Future<SyncStats> restoreFromCloud() async {
    final data = await SupabaseService.pullUserData();
    if (data == null) return const SyncStats(total: 0, perKey: {});

    final prefs = await SharedPreferences.getInstance();
    final perKey = <String, int>{};
    int total = 0;
    for (final entry in _listKeyMap.entries) {
      final localKey = entry.key;
      final cloudKey = entry.value;
      final raw = data[cloudKey];
      final list =
          raw is List ? raw.map((e) => e as String).toList() : <String>[];
      await prefs.setStringList(localKey, list);
      perKey[cloudKey] = list.length;
      total += list.length;
    }

    final cloudSettings = data['settings'];
    if (cloudSettings is Map) {
      for (final key in _settingKeys) {
        final v = cloudSettings[key];
        if (v is String) await prefs.setString(key, v);
      }
    }

    return SyncStats(total: total, perKey: perKey);
  }
}
