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
}

/// 정렬된 메모 (order asc — 최근 추가가 위)
final sortedMemosProvider = Provider<List<Memo>>((ref) {
  final list = ref.watch(memosProvider).value ?? const <Memo>[];
  final sorted = [...list]..sort((a, b) => a.order.compareTo(b.order));
  return sorted;
});
