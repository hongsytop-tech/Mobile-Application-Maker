import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/book.dart';
import 'book_providers.dart';

enum StatPeriod { today, week, month, year, all }

extension StatPeriodLabel on StatPeriod {
  String get label => switch (this) {
        StatPeriod.today => '오늘',
        StatPeriod.week => '이번주',
        StatPeriod.month => '이번달',
        StatPeriod.year => '올해',
        StatPeriod.all => '전체',
      };

  /// 기간의 시작 시각 (all이면 null)
  DateTime? startOf(DateTime now) {
    switch (this) {
      case StatPeriod.today:
        return DateTime(now.year, now.month, now.day);
      case StatPeriod.week:
        // 월요일 시작
        final monday = now.subtract(Duration(days: now.weekday - 1));
        return DateTime(monday.year, monday.month, monday.day);
      case StatPeriod.month:
        return DateTime(now.year, now.month, 1);
      case StatPeriod.year:
        return DateTime(now.year, 1, 1);
      case StatPeriod.all:
        return null;
    }
  }
}

final statPeriodProvider =
    StateProvider<StatPeriod>((ref) => StatPeriod.month);

class ReadingStats {
  final int finishedCount;
  final int readingCount;
  final int wishlistCount;
  final List<Book> finishedBooks; // 기간 내 완독, 최신순
  final List<int> monthlyFinished; // 올해 1~12월 완독 권수 (길이 12)

  const ReadingStats({
    required this.finishedCount,
    required this.readingCount,
    required this.wishlistCount,
    required this.finishedBooks,
    required this.monthlyFinished,
  });
}

final readingStatsProvider = Provider<ReadingStats>((ref) {
  final all = ref.watch(booksProvider).value ?? const <Book>[];
  final period = ref.watch(statPeriodProvider);
  final now = DateTime.now();
  final start = period.startOf(now);

  bool inPeriod(DateTime? d) {
    if (d == null) return false;
    if (start == null) return true;
    return !d.isBefore(start);
  }

  final finished = all
      .where((b) => b.status == BookStatus.finished && inPeriod(b.finishedAt))
      .toList()
    ..sort((a, b) => (b.finishedAt ?? b.addedAt)
        .compareTo(a.finishedAt ?? a.addedAt));

  final monthly = List<int>.filled(12, 0);
  for (final b in all) {
    if (b.status == BookStatus.finished &&
        b.finishedAt != null &&
        b.finishedAt!.year == now.year) {
      monthly[b.finishedAt!.month - 1]++;
    }
  }

  return ReadingStats(
    finishedCount: finished.length,
    readingCount:
        all.where((b) => b.status == BookStatus.reading).length,
    wishlistCount:
        all.where((b) => b.status == BookStatus.wishlist).length,
    finishedBooks: finished,
    monthlyFinished: monthly,
  );
});
