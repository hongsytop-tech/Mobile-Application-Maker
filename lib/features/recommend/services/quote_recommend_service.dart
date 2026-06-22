import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/services/supabase_service.dart';
import '../../auth/services/sync_manager.dart';
import '../data/recommended_quotes.dart';
import '../models/recommend_settings.dart';

/// "오늘의 추천 문구" 알림 — 큐레이션 풀(kRecommendedQuotes)을
/// scheduled_pushes.recur.bodies 에 넣어 백엔드가 자동 회전 발송.
class QuoteRecommendService {
  static const settingsKey = 'quote_recommend_settings_v1';
  static const _kind = 'quote_recommend';
  static const _refId = 'recommend';

  /// 날짜 기반으로 풀에서 1개 선택 (앱 화면 카드용).
  /// 푸시 알림과 별개로 "오늘의 문구" 라벨이 일관되게 같은 문구를 가리키도록 한다.
  static String get todaysQuote {
    if (kRecommendedQuotes.isEmpty) return '';
    final now = DateTime.now();
    final epoch = DateTime(2026, 1, 1);
    final d = DateTime(now.year, now.month, now.day);
    final days = d.difference(epoch).inDays;
    final n = kRecommendedQuotes.length;
    return kRecommendedQuotes[((days % n) + n) % n];
  }

  static Future<RecommendSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(settingsKey);
    if (raw == null) return const RecommendSettings();
    try {
      return RecommendSettings.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const RecommendSettings();
    }
  }

  static Future<void> save(RecommendSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(settingsKey, jsonEncode(s.toJson()));
    await SyncManager.instance.flushNow();
  }

  /// 기존 행 제거 후, 켜져 있으면 회전 규칙 1행으로 재등록.
  /// 설정 변경/앱 시작/pull 후 호출.
  static Future<void> reschedule() async {
    if (!kIsWeb) return; // 네이티브는 추후 로컬 알림으로 (현재 PWA 전용)
    if (!SupabaseService.isAuthenticated) return;
    final uid = SupabaseService.currentUser!.id;
    final db = SupabaseService.client;
    final s = await load();

    // 항상 기존 행 정리
    try {
      await db
          .from('scheduled_pushes')
          .delete()
          .eq('user_id', uid)
          .eq('kind', _kind);
    } catch (e) {
      if (kDebugMode) print('recommend reschedule delete failed: $e');
    }

    if (!s.enabled || kRecommendedQuotes.isEmpty) return;

    final first = _firstOccurrence(s);
    if (first == null) return;

    final bodies = [...kRecommendedQuotes];
    // 사용자마다 시작 지점이 달라지도록 랜덤 시작 인덱스
    final startIdx = Random().nextInt(bodies.length);

    final recur = <String, dynamic>{
      'mode': s.mode == RecommendMode.interval ? 'interval' : 'daily',
      if (s.mode == RecommendMode.interval)
        'intervalMinutes': s.totalIntervalMinutes,
      if (s.mode == RecommendMode.daily) 'hour': s.hour,
      if (s.mode == RecommendMode.daily) 'minute': s.minute,
      'bodies': bodies,
      'index': startIdx,
    };

    try {
      await db.from('scheduled_pushes').upsert({
        'user_id': uid,
        'kind': _kind,
        'ref_id': _refId,
        'title': '💡 오늘의 추천 문구',
        'body': bodies[startIdx],
        'scheduled_at': first.toUtc().toIso8601String(),
        'sent_at': null,
        'recur': recur,
      }, onConflict: 'user_id,kind,ref_id');
    } catch (e) {
      if (kDebugMode) print('recommend reschedule upsert failed: $e');
    }
  }

  static DateTime? _firstOccurrence(RecommendSettings s) {
    final now = DateTime.now();
    if (s.mode == RecommendMode.daily) {
      var c = DateTime(now.year, now.month, now.day, s.hour, s.minute);
      if (!c.isAfter(now)) c = c.add(const Duration(days: 1));
      return c;
    } else {
      final mins = s.totalIntervalMinutes;
      if (mins < 1) return null;
      return now.add(Duration(minutes: mins));
    }
  }
}
