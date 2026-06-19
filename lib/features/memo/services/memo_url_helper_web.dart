import 'dart:html' as html;

/// URL 쿼리 파라미터에서 memo=<id> 를 읽는다.
String? readMemoIdFromUrl() {
  final id = Uri.base.queryParameters['memo'];
  if (id == null || id.isEmpty) return null;
  return id;
}

/// 현재 URL에서 ?memo=<id> 쿼리 파라미터를 제거한다.
/// 새로고침 시 같은 메모가 다시 열리는 것을 막기 위함.
void clearMemoQueryParam() {
  final uri = Uri.base;
  final newParams = Map<String, String>.from(uri.queryParameters)
    ..remove('memo');
  final newUri = uri.replace(
    queryParameters: newParams.isEmpty ? null : newParams,
  );
  html.window.history.replaceState(null, '', newUri.toString());
}

/// 특정 메모를 여는 공유 URL을 만든다.
/// 예: https://hongsytop-tech.github.io/Mobile-Application-Maker/?memo=abc123
String buildMemoShareUrl(String memoId) {
  final uri = Uri.base;
  final newParams = Map<String, String>.from(uri.queryParameters)
    ..['memo'] = memoId;
  return uri.replace(queryParameters: newParams).toString();
}
