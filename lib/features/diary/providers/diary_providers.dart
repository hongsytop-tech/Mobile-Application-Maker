import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/diary.dart';
import '../services/diary_storage_service.dart';

final diaryStorageProvider = Provider((_) => DiaryStorageService());

final diariesProvider =
    AsyncNotifierProvider<DiariesNotifier, List<Diary>>(DiariesNotifier.new);

class DiariesNotifier extends AsyncNotifier<List<Diary>> {
  @override
  Future<List<Diary>> build() async {
    return ref.read(diaryStorageProvider).loadAll();
  }

  Future<void> _persist(List<Diary> diaries) async {
    state = AsyncData(diaries);
    await ref.read(diaryStorageProvider).saveAll(diaries);
  }

  Future<void> upsert(Diary diary) async {
    final list = [...(state.value ?? const <Diary>[])];
    final idx = list.indexWhere((d) => d.dateKey == diary.dateKey);
    if (idx >= 0) {
      list[idx] = diary;
    } else {
      list.add(diary);
    }
    list.sort((a, b) => b.date.compareTo(a.date));
    await _persist(list);
  }

  Future<void> removeByDate(DateTime date) async {
    final key = Diary.dateKeyOf(date);
    final list = (state.value ?? const <Diary>[])
        .where((d) => d.dateKey != key)
        .toList();
    await _persist(list);
  }
}

/// 특정 날짜의 일기 (없으면 null).
final diaryByDateProvider = Provider.family<Diary?, DateTime>((ref, date) {
  final all = ref.watch(diariesProvider).value ?? const <Diary>[];
  final key = Diary.dateKeyOf(date);
  for (final d in all) {
    if (d.dateKey == key) return d;
  }
  return null;
});

/// 일기가 작성된 날짜 집합 (캘린더 마커용).
final diaryDateSetProvider = Provider<Set<String>>((ref) {
  final all = ref.watch(diariesProvider).value ?? const <Diary>[];
  return all.where((d) => !d.isEmpty).map((d) => d.dateKey).toSet();
});
