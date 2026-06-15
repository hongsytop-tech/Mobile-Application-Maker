import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/quote.dart';

/// 문구 알림 (로컬 푸시) 관리.
///
/// 매일 지정 시간에 알림을 발사한다.
/// 웹/지원하지 않는 플랫폼에서는 silent no-op.
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// 알림 가능 여부 (웹·미지원 플랫폼이면 false)
  static bool get supported => !kIsWeb;

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

  /// 문구별 매일 알림 스케줄.
  static Future<void> scheduleDaily(Quote q) async {
    if (!supported) return;
    if (!q.hasSchedule) return;
    await init();

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

    const androidDetails = AndroidNotificationDetails(
      'quotes_daily',
      '문구 알림',
      channelDescription: '저장한 문구를 지정 시간에 알려드려요',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();

    await _plugin.zonedSchedule(
      q.notificationId,
      '📝 오늘의 문구',
      q.text,
      scheduled,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
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
