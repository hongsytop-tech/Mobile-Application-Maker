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

  static const _minsHour = 60;
  static const _minsDay = 60 * 24;
  static const _minsWeek = 60 * 24 * 7;

  static RepeatInterval? _matchRepeatInterval(int minutes) {
    return switch (minutes) {
      1 => RepeatInterval.everyMinute,
      _minsHour => RepeatInterval.hourly,
      _minsDay => RepeatInterval.daily,
      _minsWeek => RepeatInterval.weekly,
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

  // ---- 문구 순차 알림 (시각적으로 크게 보이도록 BigTextStyle) ----

  static const _rotationAndroid = AndroidNotificationDetails(
    'quote_rotation',
    '문구 순차 알림',
    channelDescription: '저장한 문구를 매일 지정 시각에 순환 알림합니다',
    importance: Importance.max,
    priority: Priority.high,
    enableLights: true,
    enableVibration: true,
    color: Color(0xFF4F46E5),
    colorized: true,
    visibility: NotificationVisibility.public,
    category: AndroidNotificationCategory.reminder,
  );
  static const _rotationIos = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
    interruptionLevel: InterruptionLevel.timeSensitive,
  );

  static Future<void> scheduleQuoteRotation({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    if (!supported) return;
    await init();
    final scheduled = tz.TZDateTime.from(when, tz.local);

    final androidDetails = AndroidNotificationDetails(
      _rotationAndroid.channelId,
      _rotationAndroid.channelName,
      channelDescription: _rotationAndroid.channelDescription,
      importance: _rotationAndroid.importance,
      priority: _rotationAndroid.priority,
      enableLights: true,
      enableVibration: true,
      color: const Color(0xFF4F46E5),
      colorized: true,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.reminder,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: '오늘의 문구',
        htmlFormatBigText: false,
        htmlFormatContentTitle: false,
      ),
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      NotificationDetails(android: androidDetails, iOS: _rotationIos),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ---- Todo 알림 (지정 시각에 매일/주간/월간) ----

  static const _todoAndroidDetails = AndroidNotificationDetails(
    'todo',
    '할 일 알림',
    channelDescription: '할 일 데드라인 알림',
    importance: Importance.high,
    priority: Priority.high,
  );
  static const _todoDetails = NotificationDetails(
    android: _todoAndroidDetails,
    iOS: _iosDetails,
  );

  /// 특정 일시에 1회 알림 (즉시형 할 일)
  static Future<void> scheduleTodoOnce({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    if (!supported) return;
    await init();
    if (!when.isAfter(DateTime.now())) return;
    final scheduled = tz.TZDateTime.from(when, tz.local);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      _todoDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> scheduleTodoDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    if (!supported) return;
    await init();
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      _todoDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// 매주 특정 요일(1=Mon..7=Sun) hour:minute에
  static Future<void> scheduleTodoWeekly({
    required int id,
    required String title,
    required String body,
    required int weekDay,
    required int hour,
    required int minute,
  }) async {
    if (!supported) return;
    await init();
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (scheduled.weekday != weekDay || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      _todoDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  /// 매월 특정 일자 hour:minute에 (해당 월에 그 일자가 없으면 그 달은 건너뜀)
  static Future<void> scheduleTodoMonthly({
    required int id,
    required String title,
    required String body,
    required int dayOfMonth,
    required int hour,
    required int minute,
  }) async {
    if (!supported) return;
    await init();
    final now = tz.TZDateTime.now(tz.local);
    var year = now.year;
    var month = now.month;
    tz.TZDateTime? scheduled;
    for (int i = 0; i < 13; i++) {
      final daysInMonth = DateTime(year, month + 1, 0).day;
      if (dayOfMonth <= daysInMonth) {
        final candidate = tz.TZDateTime(
            tz.local, year, month, dayOfMonth, hour, minute);
        if (candidate.isAfter(now)) {
          scheduled = candidate;
          break;
        }
      }
      month++;
      if (month > 12) {
        month = 1;
        year++;
      }
    }
    if (scheduled == null) return;
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      _todoDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
    );
  }
}
