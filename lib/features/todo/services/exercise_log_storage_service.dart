import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/services/sync_manager.dart';
import '../models/exercise_log.dart';

class ExerciseLogStorageService {
  static const _key = 'exercise_logs_v1';

  Future<List<ExerciseLog>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? const [];
    return list.map(ExerciseLog.fromJsonString).toList();
  }

  Future<void> saveAll(List<ExerciseLog> logs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _key, logs.map((e) => e.toJsonString()).toList());
    await SyncManager.instance.flushNow();
  }
}
