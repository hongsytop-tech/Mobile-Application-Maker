import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/quote.dart';
import '../services/notification_service.dart';
import '../services/quote_rotation_service.dart';
import '../services/quote_storage_service.dart';

final quoteStorageServiceProvider = Provider((_) => QuoteStorageService());

final quotesProvider =
    AsyncNotifierProvider<QuotesNotifier, List<Quote>>(QuotesNotifier.new);

class QuotesNotifier extends AsyncNotifier<List<Quote>> {
  static const _uuid = Uuid();

  @override
  Future<List<Quote>> build() async {
    final quotes = await ref.read(quoteStorageServiceProvider).loadAll();
    // 앱 시작 시 순환 알림 재스케줄 (시스템 재부팅·앱 업데이트 대비)
    unawaited(QuoteRotationService.reschedule(quotes));
    return quotes;
  }

  Future<void> _persist(List<Quote> quotes) async {
    state = AsyncData(quotes);
    await ref.read(quoteStorageServiceProvider).saveAll(quotes);
    // 문구 목록 바뀌면 순환 알림 재스케줄
    unawaited(QuoteRotationService.reschedule(quotes));
  }

  Future<Quote> add(Quote draft) async {
    final q = Quote(
      id: _uuid.v4(),
      text: draft.text,
      createdAt: DateTime.now(),
      notifyEnabled: draft.notifyEnabled,
      notifyMode: draft.notifyMode,
      notifyHour: draft.notifyHour,
      notifyMinute: draft.notifyMinute,
      intervalHours: draft.intervalHours,
      intervalMinutes: draft.intervalMinutes,
    );
    await _persist([...(state.value ?? const <Quote>[]), q]);
    if (q.hasSchedule) {
      await NotificationService.scheduleForQuote(q);
    }
    return q;
  }

  Future<void> save(Quote updated) async {
    final list = (state.value ?? const <Quote>[])
        .map((q) => q.id == updated.id ? updated : q)
        .toList();
    await _persist(list);
    await NotificationService.cancel(updated.notificationId);
    if (updated.hasSchedule) {
      await NotificationService.scheduleForQuote(updated);
    }
  }

  Future<void> remove(String id) async {
    final list = state.value ?? const <Quote>[];
    final q = list.where((e) => e.id == id).firstOrNull;
    if (q != null) {
      await NotificationService.cancel(q.notificationId);
    }
    await _persist(list.where((e) => e.id != id).toList());
  }

  Future<void> togglePin(String id) async {
    final list = (state.value ?? const <Quote>[]);
    final updated = list.map((q) {
      if (q.id != id) return q;
      return q.copyWith(
        pinnedAt: q.isPinned ? null : DateTime.now(),
        clearPin: q.isPinned,
      );
    }).toList();
    await _persist(updated);
  }
}

/// 고정·미고정으로 분리된 정렬 결과.
class SortedQuotes {
  final List<Quote> pinned;
  final List<Quote> others;

  const SortedQuotes({required this.pinned, required this.others});

  int get total => pinned.length + others.length;
  bool get isEmpty => total == 0;
}

/// 고정된 것 우선, 각 그룹 안에서는 최신순.
final sortedQuotesProvider = Provider<SortedQuotes>((ref) {
  final all = ref.watch(quotesProvider).value ?? const <Quote>[];
  final pinned = all.where((q) => q.isPinned).toList()
    ..sort((a, b) => b.pinnedAt!.compareTo(a.pinnedAt!));
  final others = all.where((q) => !q.isPinned).toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return SortedQuotes(pinned: pinned, others: others);
});
