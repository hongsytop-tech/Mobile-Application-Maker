import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/auth/services/sync_manager.dart';
import 'menu_settings.dart';

const menuSettingsKey = 'menu_settings_v1';

final menuSettingsProvider =
    AsyncNotifierProvider<MenuSettingsNotifier, MenuSettings>(
  MenuSettingsNotifier.new,
);

class MenuSettingsNotifier extends AsyncNotifier<MenuSettings> {
  @override
  Future<MenuSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(menuSettingsKey);
    if (raw == null) return const MenuSettings();
    try {
      return MenuSettings.fromJsonString(raw);
    } catch (_) {
      return const MenuSettings();
    }
  }

  Future<void> _save(MenuSettings updated) async {
    state = AsyncData(updated);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(menuSettingsKey, updated.toJsonString());
    await SyncManager.instance.flushNow();
  }

  /// 탭 표시/숨김 토글. 표시 탭이 2개 미만이 되면 거부 (false 반환).
  Future<bool> setHidden(String id, bool hidden) async {
    final cur = state.value ?? const MenuSettings();
    final next = {...cur.hidden};
    if (hidden) {
      next.add(id);
    } else {
      next.remove(id);
    }
    final candidate = cur.copyWith(hidden: next);
    if (candidate.visibleOrder.length < 2) return false; // 최소 2개 유지
    await _save(candidate);
    return true;
  }

  /// 순서 변경 — 정규화된 전체 순서를 받아 저장.
  Future<void> reorder(List<String> newOrder) async {
    final cur = state.value ?? const MenuSettings();
    await _save(cur.copyWith(order: newOrder));
  }
}
