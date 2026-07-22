import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/memo.dart';
import '../services/memo_storage_service.dart';

final memoStorageProvider = Provider((_) => MemoStorageService());

const _uuid = Uuid();

final memosProvider =
    AsyncNotifierProvider<MemosNotifier, List<Memo>>(MemosNotifier.new);

class MemosNotifier extends AsyncNotifier<List<Memo>> {
  @override
  Future<List<Memo>> build() async {
    return ref.read(memoStorageProvider).loadAll();
  }

  Future<void> _persist(List<Memo> list) async {
    state = AsyncData(list);
    await ref.read(memoStorageProvider).saveAll(list);
  }

  Future<Memo> add(
      {String title = '', String content = '', String? folderId}) async {
    final existing = state.value ?? const <Memo>[];
    final minOrder = existing.isEmpty
        ? 0
        : existing.map((m) => m.order).reduce((a, b) => a < b ? a : b);
    final now = DateTime.now();
    final memo = Memo(
      id: _uuid.v4(),
      title: title,
      content: content,
      createdAt: now,
      updatedAt: now,
      order: minOrder - 1,
      folderId: folderId,
    );
    await _persist([...existing, memo]);
    return memo;
  }

  /// 메모를 폴더로 이동 (folderId=null 이면 폴더에서 빼기).
  Future<void> setFolder(String memoId, String? folderId) async {
    final list = (state.value ?? const <Memo>[]);
    final now = DateTime.now();
    final updated = list.map((m) {
      if (m.id != memoId) return m;
      return m.copyWith(
        folderId: folderId,
        clearFolder: folderId == null,
        updatedAt: now,
      );
    }).toList();
    await _persist(updated);
  }

  /// 폴더 삭제 시 그 폴더 안 메모들을 루트로 빼낸다.
  Future<void> unfileFolder(String folderId) async {
    final list = (state.value ?? const <Memo>[]);
    final now = DateTime.now();
    final updated = list
        .map((m) => m.folderId == folderId
            ? m.copyWith(clearFolder: true, updatedAt: now)
            : m)
        .toList();
    await _persist(updated);
  }

  Future<void> save(Memo updated) async {
    final list = (state.value ?? const <Memo>[])
        .map((m) => m.id == updated.id ? updated : m)
        .toList();
    await _persist(list);
  }

  Future<void> remove(String id) async {
    final list = state.value ?? const <Memo>[];
    await _persist(list.where((m) => m.id != id).toList());
  }

  Future<void> reorder(List<String> orderedIds) async {
    final list = [...(state.value ?? const <Memo>[])];
    final byId = {for (final m in list) m.id: m};
    final updated = <Memo>[];
    for (int i = 0; i < orderedIds.length; i++) {
      final m = byId[orderedIds[i]];
      if (m != null) {
        updated.add(m.copyWith(order: i));
        byId.remove(orderedIds[i]);
      }
    }
    updated.addAll(byId.values);
    await _persist(updated);
  }

  Future<void> togglePin(String id) async {
    final list = (state.value ?? const <Memo>[]);
    final now = DateTime.now();
    final updated = list.map((m) {
      if (m.id != id) return m;
      return m.copyWith(
        pinnedAt: m.isPinned ? null : now,
        clearPin: m.isPinned,
        updatedAt: now,
      );
    }).toList();
    await _persist(updated);
  }
}

/// 고정·미고정으로 분리된 정렬 결과 (문구 메뉴와 동일).
class SortedMemos {
  final List<Memo> pinned;
  final List<Memo> others;
  const SortedMemos({required this.pinned, required this.others});

  int get total => pinned.length + others.length;
  bool get isEmpty => total == 0;
}

/// 특정 폴더(folderId=null 이면 루트/미분류) 안의 메모를 고정·미고정으로 분리·정렬.
final sortedMemosProvider =
    Provider.family<SortedMemos, String?>((ref, folderId) {
  final list = ref.watch(memosProvider).value ?? const <Memo>[];
  final inScope = list.where((m) => m.folderId == folderId);
  final pinned = inScope.where((m) => m.isPinned).toList()
    ..sort((a, b) => a.order.compareTo(b.order));
  final others = inScope.where((m) => !m.isPinned).toList()
    ..sort((a, b) => a.order.compareTo(b.order));
  return SortedMemos(pinned: pinned, others: others);
});

/// 폴더별 메모 개수 (루트 제외).
final memoCountByFolderProvider = Provider<Map<String, int>>((ref) {
  final list = ref.watch(memosProvider).value ?? const <Memo>[];
  final counts = <String, int>{};
  for (final m in list) {
    if (m.folderId != null) {
      counts[m.folderId!] = (counts[m.folderId!] ?? 0) + 1;
    }
  }
  return counts;
});
