import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/quote.dart';
import '../services/notification_service.dart';
import '../services/quote_storage_service.dart';

final quoteStorageServiceProvider = Provider((_) => QuoteStorageService());

final quotesProvider =
    AsyncNotifierProvider<QuotesNotifier, List<Quote>>(QuotesNotifier.new);

class QuotesNotifier extends AsyncNotifier<List<Quote>> {
  static const _uuid = Uuid();

  @override
  Future<List<Quote>> build() async {
    return ref.read(quoteStorageServiceProvider).loadAll();
  }

  Future<void> _persist(List<Quote> quotes) async {
    state = AsyncData(quotes);
    await ref.read(quoteStorageServiceProvider).saveAll(quotes);
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
}
