/// 비-웹 플랫폼 stub. 카카오 OAuth 는 현재 웹에서만 지원.
String currentOrigin() => '';

void redirectToUrl(String url) {
  throw UnsupportedError(
      '카카오 알림 연동은 현재 웹(PWA)에서만 지원합니다. PWA 에서 연동해 주세요.');
}

Map<String, String> readQueryParams() => const {};
void clearQueryParams() {}

void saveOauthState(String key, String value) {}
String? readOauthState(String key) => null;
void clearOauthState(String key) {}
