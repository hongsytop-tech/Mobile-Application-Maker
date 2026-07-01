/// 비웹 환경 스텁. 현재 Tasks 연동은 웹(PWA) 전용.
Future<void> preloadTasksAuth() async {}

Future<String> getTasksAccessToken(String clientId, String scope,
    {bool silent = false}) async {
  throw UnsupportedError('Google Tasks 연동은 웹(PWA)에서만 지원됩니다.');
}
