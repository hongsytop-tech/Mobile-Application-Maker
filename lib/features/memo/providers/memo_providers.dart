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

  Future<Memo> add({String title = '', String content = ''}) async {
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
    );
    await _persist([...existing, memo]);
    return memo;
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

/// 고정된 것 우선, 각 그룹 안에서는 order asc.
final sortedMemosProvider = Provider<SortedMemos>((ref) {
  final list = ref.watch(memosProvider).value ?? const <Memo>[];
  final pinned = list.where((m) => m.isPinned).toList()
    ..sort((a, b) => a.order.compareTo(b.order));
  final others = list.where((m) => !m.isPinned).toList()
    ..sort((a, b) => a.order.compareTo(b.order));
  return SortedMemos(pinned: pinned, others: others);
});
