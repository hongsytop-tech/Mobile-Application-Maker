import 'dart:async';
import 'dart:html' as html;

/// 웹 전용: Service Worker 가 새 버전을 받아 설치 완료된 순간을 감지해서
/// [available] 스트림으로 알린다. UI 가 배너를 띄우고, 사용자가 탭하면
/// [apply] 가 페이지를 새로고침하여 새 SW 가 서빙하는 콘텐츠를 보여준다.
class WebUpdateDetector {
  static final StreamController<bool> _controller =
      StreamController<bool>.broadcast();
  static Stream<bool> get available => _controller.stream;

  static bool _initialized = false;
  static bool _notified = false;

  /// 이미 새 버전이 발견된 상태인지.
  static bool get hasUpdate => _notified;

  static void init() {
    if (_initialized) return;
    _initialized = true;
    final sw = html.window.navigator.serviceWorker;
    if (sw == null) return;

    sw.getRegistration().then((reg) {
      if (reg == null) return;

      // 이미 설치 완료(waiting) 상태인 SW 가 있으면 즉시 알림
      if (reg.waiting != null && sw.controller != null) {
        _notify();
      }

      reg.addEventListener('updatefound', (_) {
        final installing = reg.installing;
        if (installing == null) return;
        installing.addEventListener('statechange', (_) {
          // 첫 방문(컨트롤러 없음)은 업데이트가 아닌 최초 설치
          if (installing.state == 'installed' && sw.controller != null) {
            _notify();
          }
        });
      });

      // 5분마다 서버에 최신 SW 확인
      Timer.periodic(const Duration(minutes: 5), (_) {
        try {
          reg.update();
        } catch (_) {}
      });
    });
  }

  static void _notify() {
    if (_notified) return;
    _notified = true;
    _controller.add(true);
  }

  /// 새 버전 적용 — 페이지 새로고침. SW 가 이미 skipWaiting + claim 된 상태라
  /// 다음 로드에서 새 콘텐츠가 즉시 서빙된다.
  static Future<void> apply() async {
    html.window.location.reload();
  }

  /// 수동으로 서버에 새 SW 가 있는지 확인. 새 버전이 발견되면 true.
  /// 5초 안에 응답이 없거나 변화가 없으면 false (= 최신).
  static Future<bool> checkForUpdate() async {
    final sw = html.window.navigator.serviceWorker;
    if (sw == null) return false;

    // 이미 적용 대기 중인 SW 가 있으면 즉시 true
    if (_notified) return true;

    final reg = await sw.getRegistration();
    if (reg == null) return false;

    // updatefound 시 listen → notify 흐름이 트리거하는 broadcast 를 기다린다.
    final completer = Completer<bool>();
    final sub = _controller.stream.listen((_) {
      if (!completer.isCompleted) completer.complete(true);
    });
    try {
      await reg.update();
    } catch (_) {
      await sub.cancel();
      return false;
    }
    // 시작 직후 reg.waiting 이 채워졌을 수도 있으므로 한 번 더 확인
    if (reg.waiting != null && sw.controller != null) {
      _notify();
    }
    final result = await Future.any<bool>([
      completer.future,
      Future<bool>.delayed(const Duration(seconds: 5), () => false),
    ]);
    await sub.cancel();
    return result;
  }
}
