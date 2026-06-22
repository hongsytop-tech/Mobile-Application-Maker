import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/services/supabase_service.dart';
import '../../auth/services/sync_manager.dart';
import '../data/recommended_books.dart';
import '../models/recommend_settings.dart';
import '../models/recommended_book.dart';

/// "오늘의 추천 책" — 날짜 기반으로 큐레이션 풀에서 매일 1권을 고른다.
/// 앱 카드와 푸시가 같은 날 같은 책을 가리키도록 날짜 인덱스를 공유한다.
class BookRecommendService {
  static const settingsKey = 'book_recommend_settings_v1';
  static const _kind = 'book_recommend';
  static const _refId = 'recommend';

  /// 기준 날짜 (인덱스 계산용 epoch).
  static final DateTime _epoch = DateTime(2026, 1, 1);

  /// 특정 날짜의 추천 책 인덱스.
  static int dayIndex(DateTime date) {
    if (kRecommendedBooks.isEmpty) return 0;
    final d = DateTime(date.year, date.month, date.day);
    final days = d.difference(_epoch).inDays;
    final n = kRecommendedBooks.length;
    return ((days % n) + n) % n; // 음수 방어
  }

  /// 오늘의 추천 책.
  static RecommendedBook get todaysBook =>
      kRecommendedBooks[dayIndex(DateTime.now())];

  static Future<BookRecommendSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(settingsKey);
    if (raw == null) return const BookRecommendSettings();
    try {
      return BookRecommendSettings.fromJsonString(raw);
    } catch (_) {
      return const BookRecommendSettings();
    }
  }

  static Future<void> save(BookRecommendSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(settingsKey, s.toJsonString());
    await SyncManager.instance.flushNow();
  }

  /// 기존 행 제거 후, 켜져 있으면 daily 회전 1행으로 재등록.
  /// bodies 는 풀 전체("제목 — 저자")이고 시작 인덱스를 첫 발송 날짜에 맞춰
  /// 앱 카드의 날짜 기반 선택과 일치시킨다.
  static Future<void> reschedule() async {
    if (!kIsWeb) return;
    if (!SupabaseService.isAuthenticated) return;
    final uid = SupabaseService.currentUser!.id;
    final db = SupabaseService.client;
    final s = await load();

    try {
      await db
          .from('scheduled_pushes')
          .delete()
          .eq('user_id', uid)
          .eq('kind', _kind);
    } catch (e) {
      if (kDebugMode) print('book recommend delete failed: $e');
    }

    if (!s.enabled || kRecommendedBooks.isEmpty) return;

    final now = DateTime.now();
    var first = DateTime(now.year, now.month, now.day, s.hour, s.minute);
    if (!first.isAfter(now)) first = first.add(const Duration(days: 1));

    // 첫 발송 날짜의 인덱스로 시작 → 이후 daily(+1)로 날짜 인덱스와 정합 유지
    final startIdx = dayIndex(first);
    final bodies = [
      for (final b in kRecommendedBooks) '${b.title} — ${b.author}',
    ];

    final recur = <String, dynamic>{
      'mode': 'daily',
      'hour': s.hour,
      'minute': s.minute,
      'bodies': bodies,
      'index': startIdx,
    };

    try {
      await db.from('scheduled_pushes').upsert({
        'user_id': uid,
        'kind': _kind,
        'ref_id': _refId,
        'title': '📚 오늘의 추천 책',
        'body': bodies[startIdx],
        'scheduled_at': first.toUtc().toIso8601String(),
        'sent_at': null,
        'recur': recur,
      }, onConflict: 'user_id,kind,ref_id');
    } catch (e) {
      if (kDebugMode) print('book recommend upsert failed: $e');
    }
  }
}
