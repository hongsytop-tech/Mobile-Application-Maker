import 'dart:async';

import 'package:flutter/foundation.dart';

import 'supabase_service.dart';
import 'sync_service.dart';

enum SyncStatus { idle, syncing, synced, error, offline }

/// 자동 동기화 오케스트레이터 (싱글톤).
///
/// - 로컬 데이터가 바뀔 때마다 [markDirty] 호출 → 디바운스 후 클라우드 push
/// - 로그인 직후 [pullOnLogin]으로 클라우드 → 로컬 복원
class SyncManager {
  SyncManager._();
  static final SyncManager instance = SyncManager._();

  /// 웹은 모바일 브라우저가 백그라운드에서 탭을 임의 종료할 수 있어
  /// 디바운스를 매우 짧게(거의 즉시) 한다. 네이티브는 잦은 push 부담 방지로 3초.
  static final Duration _debounce =
      kIsWeb ? const Duration(milliseconds: 300) : const Duration(seconds: 3);

  Timer? _timer;
  bool _busy = false;
  bool _pendingWhileBusy = false;

  final ValueNotifier<SyncStatus> status =
      ValueNotifier(SyncStatus.idle);
  final ValueNotifier<DateTime?> lastSyncedAt = ValueNotifier(null);

  /// pull 성공 시 emit. UI 가 구독해서 provider 무효화에 사용.
  final StreamController<DateTime> _pullCompleted =
      StreamController<DateTime>.broadcast();
  Stream<DateTime> get pullCompleted => _pullCompleted.stream;

  DateTime? _lastPullAt;

  bool get _canSync =>
      SupabaseService.isConfigured && SupabaseService.isAuthenticated;

  /// 로컬 변경 알림 — 디바운스 후 자동 백업.
  void markDirty() {
    if (!_canSync) return;
    _timer?.cancel();
    _timer = Timer(_debounce, _flush);
  }

  /// 즉시 백업 (디바운스 무시).
  Future<void> flushNow() async {
    _timer?.cancel();
    await _flush();
  }

  Future<void> _flush() async {
    if (!_canSync) return;
    if (_busy) {
      _pendingWhileBusy = true;
      return;
    }
    _busy = true;
    status.value = SyncStatus.syncing;
    try {
      await SyncService.backupToCloud();
      lastSyncedAt.value = DateTime.now();
      status.value = SyncStatus.synced;
    } catch (e) {
      status.value = SyncStatus.error;
      if (kDebugMode) print('Sync push failed: $e');
    } finally {
      _busy = false;
      if (_pendingWhileBusy) {
        _pendingWhileBusy = false;
        markDirty();
      }
    }
  }

  /// 로그인 직후 클라우드 → 로컬 복원.
  /// 반환: 복원된 항목 수 (실패 시 null).
  Future<int?> pullOnLogin() async {
    if (!_canSync) return null;
    status.value = SyncStatus.syncing;
    try {
      final stats = await SyncService.restoreFromCloud();
      lastSyncedAt.value = DateTime.now();
      _lastPullAt = DateTime.now();
      _pullCompleted.add(DateTime.now());
      status.value = SyncStatus.synced;
      return stats.total;
    } catch (e) {
      status.value = SyncStatus.error;
      if (kDebugMode) print('Sync pull failed: $e');
      return null;
    }
  }

  /// 폰/탭 백그라운드에서 복귀할 때 호출 — 너무 잦은 pull 방지로 10초 throttle.
  Future<void> pullIfStale({Duration maxAge = const Duration(seconds: 10)}) async {
    if (!_canSync) return;
    if (_lastPullAt != null &&
        DateTime.now().difference(_lastPullAt!) < maxAge) {
      return;
    }
    await pullOnLogin();
  }

  void reset() {
    _timer?.cancel();
    _lastPullAt = null;
    status.value = SyncStatus.idle;
    lastSyncedAt.value = null;
  }
}
