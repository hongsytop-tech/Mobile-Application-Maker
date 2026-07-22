import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/services/sync_manager.dart';
import '../models/memo_folder.dart';

class MemoFolderStorageService {
  static const _key = 'memo_folders_v1';

  Future<List<MemoFolder>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? const [];
    return list.map(MemoFolder.fromJsonString).toList();
  }

  Future<void> saveAll(List<MemoFolder> folders) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _key, folders.map((e) => e.toJsonString()).toList());
    await SyncManager.instance.flushNow();
  }
}
