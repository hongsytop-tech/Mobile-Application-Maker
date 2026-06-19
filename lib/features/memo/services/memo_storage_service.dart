import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/services/sync_manager.dart';
import '../models/memo.dart';

class MemoStorageService {
  static const _key = 'memos_v1';

  Future<List<Memo>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? const [];
    return list.map(Memo.fromJsonString).toList();
  }

  Future<void> saveAll(List<Memo> memos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _key, memos.map((e) => e.toJsonString()).toList());
    await SyncManager.instance.flushNow();
  }
}
