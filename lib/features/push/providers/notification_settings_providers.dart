import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/services/sync_manager.dart';
import '../models/notification_settings.dart';

const _settingsKey = 'notification_settings_v1';

final notificationSettingsProvider = AsyncNotifierProvider<
    NotificationSettingsNotifier, NotificationSettings>(
  NotificationSettingsNotifier.new,
);

class NotificationSettingsNotifier
    extends AsyncNotifier<NotificationSettings> {
  @override
  Future<NotificationSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsKey);
    if (raw == null) return const NotificationSettings();
    try {
      return NotificationSettings.fromJsonString(raw);
    } catch (_) {
      return const NotificationSettings();
    }
  }

  Future<void> save(NotificationSettings updated) async {
    state = AsyncData(updated);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, updated.toJsonString());
    // 백엔드 동기화 즉시 트리거 (방해금지/진동을 edge function 이 곧바로 반영)
    await SyncManager.instance.flushNow();
  }
}
