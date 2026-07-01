import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;

/// GIS(Google Identity Services) 스크립트를 로드해 둔다.
/// 사용자 제스처(버튼 탭) 시점에 토큰 요청이 즉시 가능하도록 미리 호출 권장.
Future<void> preloadTasksAuth() async {
  await _ensureGisLoaded();
}

Future<void> _ensureGisLoaded() async {
  if (_hasGis()) return;
  final existing = html.document
      .querySelector('script[src*="accounts.google.com/gsi/client"]');
  if (existing == null) {
    final script = html.ScriptElement()
      ..src = 'https://accounts.google.com/gsi/client'
      ..async = true
      ..defer = true;
    html.document.head!.append(script);
  }
  // 최대 약 10초 폴링
  for (var i = 0; i < 100; i++) {
    if (_hasGis()) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw Exception('Google Identity Services 스크립트를 불러오지 못했습니다.');
}

bool _hasGis() {
  try {
    final google = js_util.getProperty(html.window, 'google');
    if (google == null) return false;
    final accounts = js_util.getProperty(google, 'accounts');
    if (accounts == null) return false;
    return js_util.getProperty(accounts, 'oauth2') != null;
  } catch (_) {
    return false;
  }
}

/// GIS 토큰 클라이언트로 [scope] 권한의 access token 을 받는다.
/// 버튼 onPressed 등 사용자 제스처 컨텍스트에서 호출해야 팝업이 차단되지 않는다.
/// [silent] 이면 prompt:'' 로 요청 → 동의가 살아있으면 팝업 없이 토큰,
/// 동의가 필요하면 팝업 없이 error_callback 으로 조용히 실패한다(앱 시작 시 사용).
Future<String> getTasksAccessToken(String clientId, String scope,
    {bool silent = false, String? hint}) async {
  await _ensureGisLoaded();
  final completer = Completer<String>();

  final google = js_util.getProperty(html.window, 'google');
  final accounts = js_util.getProperty(google, 'accounts');
  final oauth2 = js_util.getProperty(accounts, 'oauth2');

  final config = js_util.newObject<Object>();
  js_util.setProperty(config, 'client_id', clientId);
  js_util.setProperty(config, 'scope', scope);
  // 계정 힌트 → 계정 선택 화면을 건너뛰고, 조용한 재발급을 가능케 함.
  if (hint != null && hint.isNotEmpty) {
    js_util.setProperty(config, 'hint', hint);
  }
  js_util.setProperty(
    config,
    'callback',
    js_util.allowInterop((resp) {
      if (completer.isCompleted) return;
      final token = js_util.getProperty(resp, 'access_token');
      if (token is String && token.isNotEmpty) {
        completer.complete(token);
      } else {
        final err = js_util.getProperty(resp, 'error');
        completer.completeError(Exception('토큰을 받지 못했습니다: $err'));
      }
    }),
  );
  js_util.setProperty(
    config,
    'error_callback',
    js_util.allowInterop((err) {
      if (completer.isCompleted) return;
      String? type;
      try {
        type = js_util.getProperty(err, 'type') as String?;
      } catch (_) {}
      completer.completeError(
          Exception('인증이 취소되었거나 오류가 발생했습니다${type != null ? ' ($type)' : ''}'));
    }),
  );

  final client = js_util.callMethod(oauth2, 'initTokenClient', [config]);
  // prompt:'' → 이미 동의한 계정이면 계정 선택·동의 화면을 건너뛰고 바로 토큰.
  // (최초 1회는 GIS 가 필요 시 동의 화면을 띄운다.)
  // silent(앱 시작·제스처 없음)에서 동의가 필요하면 팝업이 차단되어
  // error_callback 으로 조용히 실패한다.
  final override = js_util.newObject<Object>();
  js_util.setProperty(override, 'prompt', '');
  js_util.callMethod(client, 'requestAccessToken', [override]);

  return completer.future;
}
