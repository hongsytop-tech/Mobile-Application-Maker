import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../push/services/web_push_scheduler.dart';
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
    // 웹: 개별 문구 알림도 큐 동기화
    if (kIsWeb) unawaited(WebPushScheduler.scheduleAll(quotes));
    return quotes;
  }

  Future<void> _persist(List<Quote> quotes) async {
    state = AsyncData(quotes);
    await ref.read(quoteStorageServiceProvider).saveAll(quotes);
    // 문구 목록 바뀌면 순환 알림 재스케줄
    unawaited(QuoteRotationService.reschedule(quotes));
  }

  Future<Quote> add(Quote draft) async {
    final existing = state.value ?? const <Quote>[];
    final minOrder = existing.isEmpty
        ? 0
        : existing.map((q) => q.order).reduce((a, b) => a < b ? a : b);
    final now = DateTime.now();
    final q = Quote(
      id: _uuid.v4(),
      text: draft.text,
      createdAt: now,
      updatedAt: now,
      notifyEnabled: draft.notifyEnabled,
      notifyMode: draft.notifyMode,
      notifyHour: draft.notifyHour,
      notifyMinute: draft.notifyMinute,
      intervalHours: draft.intervalHours,
      intervalMinutes: draft.intervalMinutes,
      order: minOrder - 1,
    );
    await _persist([...existing, q]);
    if (q.hasSchedule) {
      await NotificationService.scheduleForQuote(q);
      if (kIsWeb) await WebPushScheduler.scheduleQuote(q);
    }
    return q;
  }

  /// 주어진 ID 순서대로 order = 0,1,2,... 재할당 (드래그 정렬용).
  /// orderedIds에 없는 항목은 기존 order 유지.
  Future<void> reorder(List<String> orderedIds) async {
    final list = [...(state.value ?? const <Quote>[])];
    final byId = {for (final q in list) q.id: q};
    final updated = <Quote>[];
    for (int i = 0; i < orderedIds.length; i++) {
      final q = byId[orderedIds[i]];
      if (q != null) {
        updated.add(q.copyWith(order: i, updatedAt: DateTime.now()));
        byId.remove(orderedIds[i]);
      }
    }
    updated.addAll(byId.values);
    await _persist(updated);
  }

  Future<void> save(Quote updated) async {
    final list = (state.value ?? const <Quote>[])
        .map((q) => q.id == updated.id ? updated : q)
        .toList();
    await _persist(list);
    await NotificationService.cancel(updated.notificationId);
    if (kIsWeb) await WebPushScheduler.cancelQuote(updated.id);
    if (updated.hasSchedule) {
      await NotificationService.scheduleForQuote(updated);
      if (kIsWeb) await WebPushScheduler.scheduleQuote(updated);
    }
  }

  Future<void> remove(String id) async {
    final list = state.value ?? const <Quote>[];
    final q = list.where((e) => e.id == id).firstOrNull;
    if (q != null) {
      await NotificationService.cancel(q.notificationId);
      if (kIsWeb) await WebPushScheduler.cancelQuote(q.id);
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
        updatedAt: DateTime.now(),
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
    ..sort((a, b) => a.order.compareTo(b.order));
  final others = all.where((q) => !q.isPinned).toList()
    ..sort((a, b) => a.order.compareTo(b.order));
  return SortedQuotes(pinned: pinned, others: others);
});
