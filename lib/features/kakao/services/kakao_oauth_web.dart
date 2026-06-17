import 'dart:html' as html;

const _sessionKeyCode = 'kakao_oauth_code';
const _sessionKeyState = 'kakao_oauth_state_returned';

/// Supabase 초기화 이전에 호출해서 ?code/?state 를 sessionStorage 로 옮기고
/// URL 을 정리한다. Supabase auth 가 ?code 를 자기 PKCE 콜백으로 오인하는 것을 방지.
void captureKakaoCallback() {
  final params = readQueryParams();
  final code = params['code'];
  final state = params['state'];
  if (code != null && state != null && state.startsWith('kakao_')) {
    html.window.sessionStorage[_sessionKeyCode] = code;
    html.window.sessionStorage[_sessionKeyState] = state;
    clearQueryParams();
  }
}

/// 현재 페이지의 origin + pathname. Kakao 콘솔에 등록된 redirect URI 와 정확히 일치해야 함.
String currentOrigin() {
  final loc = html.window.location;
  // pathname 끝에 슬래시 강제 — Kakao 콘솔 등록 URI 와 매칭 안정성 확보.
  var path = loc.pathname ?? '/';
  if (!path.endsWith('/')) path = '$path/';
  return '${loc.origin}$path';
}

void redirectToUrl(String url) {
  html.window.location.href = url;
}

Map<String, String> readQueryParams() {
  // captureKakaoCallback 이 미리 sessionStorage 로 옮겨놨으면 그걸 우선 사용.
  final cachedCode = html.window.sessionStorage[_sessionKeyCode];
  final cachedState = html.window.sessionStorage[_sessionKeyState];
  if (cachedCode != null && cachedState != null) {
    html.window.sessionStorage.remove(_sessionKeyCode);
    html.window.sessionStorage.remove(_sessionKeyState);
    return {'code': cachedCode, 'state': cachedState};
  }
  final search = html.window.location.search ?? '';
  if (search.length < 2) return const {};
  return Uri.splitQueryString(search.substring(1));
}

/// URL 의 query string 제거 (history.replaceState).
void clearQueryParams() {
  final loc = html.window.location;
  final clean = '${loc.origin}${loc.pathname}${loc.hash ?? ''}';
  html.window.history.replaceState(null, '', clean);
}

void saveOauthState(String key, String value) {
  html.window.localStorage[key] = value;
}

String? readOauthState(String key) {
  return html.window.localStorage[key];
}

void clearOauthState(String key) {
  html.window.localStorage.remove(key);
}
