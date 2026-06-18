import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/services/supabase_service.dart';
import 'web_push_platform_stub.dart'
    if (dart.library.html) 'web_push_platform_web.dart' as platform;

class WebPushService {
  /// 사용자가 명시적으로 알림을 끈 상태인지 기록하는 키.
  /// true 면 ensureSubscribed(자동 재구독)가 동작하지 않는다.
  static const _optedOutKey = 'web_push_opted_out';

  static Future<bool> _isOptedOut() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_optedOutKey) ?? false;
  }

  static Future<void> _setOptedOut(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_optedOutKey, v);
  }

  /// 사용자가 알림을 끈 상태인지 (UI 상태 표시용).
  static Future<bool> optedOut() => _isOptedOut();

  /// 현재 브라우저에서 Web Push 가 가능한지.
  static Future<bool> isSupported() async {
    if (!kIsWeb) return false;
    return platform.isPushSupported();
  }

  /// 브라우저 알림 권한 상태: granted / denied / default / unsupported
  static Future<String> permission() async {
    if (!kIsWeb) return 'unsupported';
    return platform.currentPermission();
  }

  /// 현재 활성 구독이 있는지 (브라우저 기준).
  static Future<bool> isSubscribed() async {
    if (!kIsWeb) return false;
    return platform.hasActiveSubscription();
  }

  /// VAPID 공개키 가져오기 (Edge Function 호출).
  static Future<String?> _getPublicKey() async {
    try {
      final res = await SupabaseService.client.functions
          .invoke('web-push', body: {'action': 'public_key'});
      final data = res.data as Map?;
      return data?['public_key'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// 권한 요청 + 구독 + Supabase 저장.
  /// 반환: 성공 여부 + 실패 사유. (어떤 예외도 밖으로 던지지 않는다)
  static Future<WebPushEnableResult> enable() async {
    try {
      if (!kIsWeb) return WebPushEnableResult.unsupported();
      if (!await platform.isPushSupported()) {
        return WebPushEnableResult.unsupported();
      }
      if (!SupabaseService.isAuthenticated) {
        return WebPushEnableResult.error('로그인이 필요합니다');
      }

      final pub = await _getPublicKey();
      if (pub == null || pub.isEmpty) {
        return WebPushEnableResult.error('VAPID 공개키를 받지 못했습니다 (서버 설정 확인)');
      }

      Map<String, String>? sub;
      try {
        sub = await platform.subscribe(pub);
      } catch (e) {
        return WebPushEnableResult.error('브라우저 구독 실패: $e');
      }
      if (sub == null) {
        final p = await platform.currentPermission();
        if (p == 'denied') {
          return WebPushEnableResult.error('알림 권한이 차단돼 있어요. 브라우저 설정에서 허용해 주세요.');
        }
        return WebPushEnableResult.error('구독 실패 — 권한이 부여되지 않았습니다 (상태: $p)');
      }

      try {
        final res = await SupabaseService.client
            .from('web_push_subscriptions')
            .upsert(
              {
                'user_id': SupabaseService.currentUser!.id,
                'endpoint': sub['endpoint'],
                'p256dh': sub['p256dh'],
                'auth': sub['auth'],
                'user_agent': sub['user_agent'],
              },
              onConflict: 'user_id,endpoint',
            )
            .select();
        if (res is! List || res.isEmpty) {
          return WebPushEnableResult.error(
              '구독 저장 응답이 비어있어요 (테이블/RLS 확인 필요)');
        }
      } catch (e) {
        return WebPushEnableResult.error('구독 저장 실패: $e');
      }

      // 사용자가 명시적으로 켰으니 opt-out 해제
      await _setOptedOut(false);
      return WebPushEnableResult.ok();
    } catch (e, st) {
      return WebPushEnableResult.error('예기치 못한 오류: $e\n$st');
    }
  }

  /// 앱 시작/로그인 시 호출 — 권한이 이미 허용된 경우에만 조용히 재구독해서
  /// DB 구독 행을 항상 최신으로 유지한다. (cron 발송 시 no_subscription 방지)
  /// 권한 요청 팝업은 절대 띄우지 않는다. 사용자가 끈 경우(opt-out)면 아무것도 안 함.
  static Future<void> ensureSubscribed() async {
    try {
      if (!kIsWeb) return;
      if (await _isOptedOut()) return; // 사용자가 끈 상태면 자동 재구독 금지
      if (!await platform.isPushSupported()) return;
      if (!SupabaseService.isAuthenticated) return;
      // 이미 허용된 경우에만 진행 (default/denied 면 팝업 없이 종료)
      if (await platform.currentPermission() != 'granted') return;

      final pub = await _getPublicKey();
      if (pub == null || pub.isEmpty) return;
      final sub = await platform.subscribe(pub);
      if (sub == null) return;

      await SupabaseService.client.from('web_push_subscriptions').upsert(
        {
          'user_id': SupabaseService.currentUser!.id,
          'endpoint': sub['endpoint'],
          'p256dh': sub['p256dh'],
          'auth': sub['auth'],
          'user_agent': sub['user_agent'],
        },
        onConflict: 'user_id,endpoint',
      );
    } catch (e) {
      if (kDebugMode) print('ensureSubscribed failed: $e');
    }
  }

  /// 구독 해제 + DB 정리. 사용자가 명시적으로 끈 것이므로 opt-out 기록 →
  /// 다음 앱 시작 시 자동 재구독되지 않음.
  static Future<void> disable() async {
    if (!kIsWeb) return;
    await _setOptedOut(true);
    await platform.unsubscribe();
    final uid = SupabaseService.currentUser?.id;
    if (uid != null) {
      try {
        await SupabaseService.client
            .from('web_push_subscriptions')
            .delete()
            .eq('user_id', uid);
      } catch (_) {}
    }
  }

  /// 테스트 푸시 전송. 응답에서 sent/failed/cleaned 카운트 반환.
  static Future<Map<String, int>> sendTest() async {
    final res = await SupabaseService.client.functions
        .invoke('web-push', body: {'action': 'send_test'});
    final data = res.data as Map?;
    if (data?['ok'] != true) {
      throw StateError('${data?['error'] ?? 'unknown'} ${data?['detail'] ?? ''}');
    }
    return {
      'sent': (data?['sent'] as num?)?.toInt() ?? 0,
      'failed': (data?['failed'] as num?)?.toInt() ?? 0,
      'cleaned': (data?['cleaned'] as num?)?.toInt() ?? 0,
    };
  }

  /// 스케줄러 검증용: 3초 뒤 발송 예약 + 즉시 run_due 실행.
  /// pg_cron 을 기다리지 않고 백엔드 큐 → 발송 흐름 전체를 테스트.
  static Future<Map<String, int>> testScheduler() async {
    final res = await SupabaseService.client.functions
        .invoke('web-push', body: {'action': 'test_scheduled'});
    final data = res.data as Map?;
    if (data?['ok'] != true) {
      throw StateError('${data?['error'] ?? 'unknown'} ${data?['detail'] ?? ''}');
    }
    return {
      'processed': (data?['processed'] as num?)?.toInt() ?? 0,
      'failed': (data?['failed'] as num?)?.toInt() ?? 0,
      'total': (data?['total'] as num?)?.toInt() ?? 0,
    };
  }
}

class WebPushEnableResult {
  final bool ok;
  final bool unsupported;
  final String? error;
  const WebPushEnableResult._(
      {required this.ok, required this.unsupported, this.error});
  factory WebPushEnableResult.ok() =>
      const WebPushEnableResult._(ok: true, unsupported: false);
  factory WebPushEnableResult.unsupported() =>
      const WebPushEnableResult._(ok: false, unsupported: true);
  factory WebPushEnableResult.error(String msg) =>
      WebPushEnableResult._(ok: false, unsupported: false, error: msg);
}
