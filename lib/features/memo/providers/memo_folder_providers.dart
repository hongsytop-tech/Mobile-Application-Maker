import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/memo_folder.dart';
import '../services/memo_folder_storage_service.dart';

final memoFolderStorageProvider = Provider((_) => MemoFolderStorageService());

const _uuid = Uuid();

final memoFoldersProvider =
    AsyncNotifierProvider<MemoFoldersNotifier, List<MemoFolder>>(
        MemoFoldersNotifier.new);

class MemoFoldersNotifier extends AsyncNotifier<List<MemoFolder>> {
  @override
  Future<List<MemoFolder>> build() async {
    return ref.read(memoFolderStorageProvider).loadAll();
  }

  Future<void> _persist(List<MemoFolder> list) async {
    state = AsyncData(list);
    await ref.read(memoFolderStorageProvider).saveAll(list);
  }

  Future<MemoFolder> add(String name) async {
    final existing = state.value ?? const <MemoFolder>[];
    final maxOrder = existing.isEmpty
        ? -1
        : existing.map((f) => f.order).reduce((a, b) => a > b ? a : b);
    final now = DateTime.now();
    final folder = MemoFolder(
      id: _uuid.v4(),
      name: name.trim().isEmpty ? '새 폴더' : name.trim(),
      createdAt: now,
      updatedAt: now,
      order: maxOrder + 1,
    );
    await _persist([...existing, folder]);
    return folder;
  }

  Future<void> rename(String id, String name) async {
    final list = (state.value ?? const <MemoFolder>[]);
    final now = DateTime.now();
    final updated = list
        .map((f) => f.id == id
            ? f.copyWith(name: name.trim(), updatedAt: now)
            : f)
        .toList();
    await _persist(updated);
  }

  Future<void> remove(String id) async {
    final list = state.value ?? const <MemoFolder>[];
    await _persist(list.where((f) => f.id != id).toList());
  }

  Future<void> reorder(List<String> orderedIds) async {
    final list = [...(state.value ?? const <MemoFolder>[])];
    final byId = {for (final f in list) f.id: f};
    final updated = <MemoFolder>[];
    for (int i = 0; i < orderedIds.length; i++) {
      final f = byId[orderedIds[i]];
      if (f != null) {
        updated.add(f.copyWith(order: i));
        byId.remove(orderedIds[i]);
      }
    }
    updated.addAll(byId.values);
    await _persist(updated);
  }
}

/// order 순으로 정렬된 폴더 목록.
final sortedMemoFoldersProvider = Provider<List<MemoFolder>>((ref) {
  final list = ref.watch(memoFoldersProvider).value ?? const <MemoFolder>[];
  final sorted = [...list]..sort((a, b) => a.order.compareTo(b.order));
  return sorted;
});
