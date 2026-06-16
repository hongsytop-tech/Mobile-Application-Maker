import 'dart:html' as html;

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
