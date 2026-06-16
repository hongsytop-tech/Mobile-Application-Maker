import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/services/sync_manager.dart';
import '../models/diary.dart';

class DiaryStorageService {
  static const _key = 'diaries_v1';

  Future<List<Diary>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? const [];
    return list.map(Diary.fromJsonString).toList();
  }

  Future<void> saveAll(List<Diary> diaries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _key, diaries.map((e) => e.toJsonString()).toList());
    SyncManager.instance.markDirty();
  }
}
