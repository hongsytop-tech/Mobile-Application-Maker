import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/exercise_log.dart';
import '../services/exercise_log_storage_service.dart';

final exerciseLogStorageProvider = Provider((_) => ExerciseLogStorageService());

const _uuid = Uuid();

final exerciseLogsProvider =
    AsyncNotifierProvider<ExerciseLogsNotifier, List<ExerciseLog>>(
        ExerciseLogsNotifier.new);

class ExerciseLogsNotifier extends AsyncNotifier<List<ExerciseLog>> {
  @override
  Future<List<ExerciseLog>> build() async {
    return ref.read(exerciseLogStorageProvider).loadAll();
  }

  Future<void> _persist(List<ExerciseLog> list) async {
    state = AsyncData(list);
    await ref.read(exerciseLogStorageProvider).saveAll(list);
  }

  Future<void> add({
    required String dateKey,
    required String type,
    required List<int> reps,
  }) async {
    final now = DateTime.now();
    final log = ExerciseLog(
      id: _uuid.v4(),
      dateKey: dateKey,
      type: type,
      reps: reps,
      createdAt: now,
      updatedAt: now,
    );
    await _persist([...(state.value ?? const <ExerciseLog>[]), log]);
  }

  Future<void> editLog(String id, {String? type, List<int>? reps}) async {
    final list = state.value ?? const <ExerciseLog>[];
    final now = DateTime.now();
    final updated = list
        .map((l) =>
            l.id == id ? l.copyWith(type: type, reps: reps, updatedAt: now) : l)
        .toList();
    await _persist(updated);
  }

  Future<void> remove(String id) async {
    final list = state.value ?? const <ExerciseLog>[];
    await _persist(list.where((l) => l.id != id).toList());
  }
}

/// 특정 날짜(dateKey='yyyy-MM-dd')의 운동 기록 (생성순).
final exerciseLogsByDayProvider =
    Provider.family<List<ExerciseLog>, String>((ref, dateKey) {
  final all = ref.watch(exerciseLogsProvider).value ?? const <ExerciseLog>[];
  final list = all.where((l) => l.dateKey == dateKey).toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return list;
});
