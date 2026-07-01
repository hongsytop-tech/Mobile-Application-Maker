import '../../memo/providers/memo_providers.dart';
import 'google_tasks_service.dart';
import 'tasks_import_store.dart';

/// Google Tasks → 메모 가져오기 공통 로직 (수동 버튼 + 앱 시작 자동 공용).
class TasksImporter {
  /// 아직 안 가져온 Task 를 메모로 추가한다.
  /// 반환: (전체 활성 Task 수, 새로 가져온 수).
  /// [silent] 이면 팝업 없이 조용히 토큰을 시도한다(앱 시작 시).
  static Future<({int total, int imported})> importNew(
    MemosNotifier notifier, {
    bool silent = false,
  }) async {
    final tasks = await GoogleTasksService.fetchActiveTasks(silent: silent);
    final already = await TasksImportStore.loadImportedIds();
    final fresh = tasks.where((t) => !already.contains(t.id)).toList();
    for (final t in fresh) {
      await notifier.add(title: t.title, content: t.notes);
    }
    if (fresh.isNotEmpty) {
      await TasksImportStore.addImportedIds(fresh.map((t) => t.id));
    }
    return (total: tasks.length, imported: fresh.length);
  }
}
