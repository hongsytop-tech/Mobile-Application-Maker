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

  /// 아직 클라우드에 push 되지 않은 로컬 변경이 있는지.
  /// 탭이 백그라운드로 갈 때 이 값이 true 일 때만 push → "stale 로컬이 최신
  /// 클라우드를 덮어쓰는" 줄다리기 방지.
  bool _dirty = false;

  /// 이 기기에서 클라우드 pull 을 최소 1회 했는지.
  /// 한 번도 pull 하지 않은 상태(=로컬이 다른 기기보다 오래됐을 수 있음)에서는
  /// 절대 push 하지 않는다.
  bool _hasPulledOnce = false;

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
    _dirty = true;
    _timer?.cancel();
    _timer = Timer(_debounce, _flush);
  }

  /// 즉시 백업 (디바운스 무시). 명시적 저장 직후 호출 → dirty 로 표시 후 push.
  Future<void> flushNow() async {
    if (!_canSync) return;
    _dirty = true;
    _timer?.cancel();
    await _flush();
  }

  /// 탭이 백그라운드로 갈 때 호출 — 아직 push 안 된 변경이 있을 때만 push.
  /// stale 로컬이 최신 클라우드를 덮어쓰는 것을 막는다.
  Future<void> flushIfDirty() async {
    if (!_canSync) return;
    if (!_dirty || !_hasPulledOnce) return;
    _timer?.cancel();
    await _flush();
  }

  Future<void> _flush() async {
    if (!_canSync) return;
    // pull 을 한 번도 안 한 기기는 push 금지 (오래된 로컬로 클라우드 덮어쓰기 방지)
    if (!_hasPulledOnce) {
      _dirty = false;
      return;
    }
    if (_busy) {
      _pendingWhileBusy = true;
      return;
    }
    _busy = true;
    status.value = SyncStatus.syncing;
    try {
      await SyncService.backupToCloud();
      _dirty = false;
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
      _hasPulledOnce = true;
      // 클라우드로 로컬을 덮어썼으니 미전송 변경 플래그 해제
      _dirty = false;
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

  /// 외부(예: 마이페이지 "복원" 버튼)에서 SyncService 를 직접 호출한 뒤
  /// pullCompleted 구독자(설정 화면 등)에게 알리기 위해 사용.
  void notifyPullCompleted() {
    _hasPulledOnce = true;
    _dirty = false;
    _lastPullAt = DateTime.now();
    lastSyncedAt.value = DateTime.now();
    _pullCompleted.add(DateTime.now());
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
    _dirty = false;
    _hasPulledOnce = false;
    status.value = SyncStatus.idle;
    lastSyncedAt.value = null;
  }
}
