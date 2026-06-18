import 'dart:html' as html;

import 'sync_manager.dart';

/// 웹 전용: 탭이 백그라운드로 가거나(visibilitychange hidden),
/// 종료/내비게이션(pagehide, beforeunload)될 때 즉시 클라우드로 flush.
/// 모바일 브라우저는 백그라운드에서 탭을 OS가 임의로 종료할 수 있어서
/// beforeunload 만으로는 불충분 → visibilitychange + pagehide 가 필수.
void setupSyncTabCloseFlush() {
  void flush() {
    // 아직 push 되지 않은 변경이 있을 때만 push.
    // (stale 로컬이 최신 클라우드를 덮어쓰는 줄다리기 방지)
    SyncManager.instance.flushIfDirty();
  }

  html.document.addEventListener('visibilitychange', (_) {
    if (html.document.visibilityState == 'hidden') {
      flush();
    } else if (html.document.visibilityState == 'visible') {
      // 백그라운드에서 복귀 → 다른 기기의 변경분을 즉시 끌어온다 (throttled).
      SyncManager.instance.pullIfStale();
    }
  });
  html.window.addEventListener('pagehide', (_) => flush());
  html.window.addEventListener('beforeunload', (_) => flush());
}
