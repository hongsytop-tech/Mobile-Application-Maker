import 'dart:html' as html;

import 'sync_manager.dart';

/// 웹 전용: 탭이 백그라운드로 가거나(visibilitychange hidden),
/// 종료/내비게이션(pagehide, beforeunload)될 때 즉시 클라우드로 flush.
/// 모바일 브라우저는 백그라운드에서 탭을 OS가 임의로 종료할 수 있어서
/// beforeunload 만으로는 불충분 → visibilitychange + pagehide 가 필수.
void setupSyncTabCloseFlush() {
  void flush() {
    // 동기 컨텍스트에서 호출되지만 내부적으로 비동기 push 가 즉시 시작됨.
    // 결과를 기다리지 않고 발사 후 잊기 (브라우저는 보통 종료 직전 짧은 시간만 허용).
    SyncManager.instance.flushNow();
  }

  html.document.addEventListener('visibilitychange', (_) {
    if (html.document.visibilityState == 'hidden') flush();
  });
  html.window.addEventListener('pagehide', (_) => flush());
  html.window.addEventListener('beforeunload', (_) => flush());
}
