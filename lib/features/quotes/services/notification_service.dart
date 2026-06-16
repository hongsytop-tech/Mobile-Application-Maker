import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/quote.dart';

/// 문구 알림 (로컬 푸시) 관리.
///
/// - daily 모드: 매일 지정 시각에 1회
/// - interval 모드: 주기적 반복 (시간:분 단위)
///
/// 웹/지원하지 않는 플랫폼에서는 silent no-op.
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// 알림 가능 여부 (웹·미지원 플랫폼이면 false)
  static bool get supported => !kIsWeb;

  static const _androidDetails = AndroidNotificationDetails(
    'quotes_daily',
    '문구 알림',
    channelDescription: '저장한 문구를 지정 시간/간격에 알려드려요',
    importance: Importance.high,
    priority: Priority.high,
  );
  static const _iosDetails = DarwinNotificationDetails();
  static const _details =
      NotificationDetails(android: _androidDetails, iOS: _iosDetails);

  static Future<void> init() async {
    if (_initialized || !supported) return;

    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    } catch (_) {
      // 기본값 사용
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    _initialized = true;
  }

  /// 알림 권한 요청. 사용자가 허용했으면 true.
  static Future<bool> requestPermission() async {
    if (!supported) return false;
    await init();

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final ok = await android.requestNotificationsPermission() ?? true;
      return ok;
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final ok = await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
      return ok;
    }

    return true;
  }

  /// 문구별 알림 등록 (모드에 따라 자동 분기).
  static Future<void> scheduleForQuote(Quote q) async {
    if (!supported) return;
    if (!q.hasSchedule) return;
    await init();

    // 기존 스케줄 정리
    await _plugin.cancel(q.notificationId);

    switch (q.notifyMode) {
      case NotifyMode.daily:
        await _scheduleDaily(q);
        break;
      case NotifyMode.interval:
        await _scheduleInterval(q);
        break;
    }
  }

  static Future<void> _scheduleDaily(Quote q) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      q.notifyHour!,
      q.notifyMinute!,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      q.notificationId,
      '📝 오늘의 문구',
      q.text,
      scheduled,
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> _scheduleInterval(Quote q) async {
    final mins = q.intervalMinutesTotal!;
    final duration = Duration(minutes: mins);

    // 표준 RepeatInterval에 정확히 맞는 경우 (성능·정확도 ↑)
    final preset = _matchRepeatInterval(mins);
    if (preset != null) {
      await _plugin.periodicallyShow(
        q.notificationId,
        '📝 오늘의 문구',
        q.text,
        preset,
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      return;
    }

    // 임의 Duration → periodicallyShowWithDuration (안드로이드 전용 기능, iOS는 폴백)
    try {
      await _plugin.periodicallyShowWithDuration(
        q.notificationId,
        '📝 오늘의 문구',
        q.text,
        duration,
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {
      // 미지원 플랫폼이면 가장 가까운 preset으로 폴백
      final fallback = _closestRepeatInterval(mins);
      await _plugin.periodicallyShow(
        q.notificationId,
        '📝 오늘의 문구',
        q.text,
        fallback,
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  static RepeatInterval? _matchRepeatInterval(int minutes) {
    return switch (minutes) {
      1 => RepeatInterval.everyMinute,
      60 => RepeatInterval.hourly,
      60 * 24 => RepeatInterval.daily,
      60 * 24 * 7 => RepeatInterval.weekly,
      _ => null,
    };
  }

  static RepeatInterval _closestRepeatInterval(int minutes) {
    if (minutes <= 1) return RepeatInterval.everyMinute;
    if (minutes <= 60) return RepeatInterval.hourly;
    if (minutes <= 60 * 24) return RepeatInterval.daily;
    return RepeatInterval.weekly;
  }

  static Future<void> cancel(int id) async {
    if (!supported) return;
    await init();
    await _plugin.cancel(id);
  }

  static Future<void> cancelAll() async {
    if (!supported) return;
    await init();
    await _plugin.cancelAll();
  }
}
