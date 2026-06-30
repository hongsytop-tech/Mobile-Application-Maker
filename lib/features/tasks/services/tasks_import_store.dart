import 'package:shared_preferences/shared_preferences.dart';

/// 이미 메모로 가져온 Google Task 의 id 를 기억해 중복 import 를 막는다.
/// (기기 로컬 저장 — 같은 기기에서 두 번 가져와도 중복 생성 안 됨)
class TasksImportStore {
  static const _key = 'imported_google_task_ids_v1';

  static Future<Set<String>> loadImportedIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? const <String>[]).toSet();
  }

  static Future<void> addImportedIds(Iterable<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final cur = (prefs.getStringList(_key) ?? const <String>[]).toSet();
    cur.addAll(ids);
    await prefs.setStringList(_key, cur.toList());
  }
}
