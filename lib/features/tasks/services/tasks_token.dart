/// Tasks OAuth access token 발급 — 웹은 GIS 토큰 클라이언트, 그 외는 스텁.
export 'tasks_token_stub.dart'
    if (dart.library.html) 'tasks_token_web.dart';
