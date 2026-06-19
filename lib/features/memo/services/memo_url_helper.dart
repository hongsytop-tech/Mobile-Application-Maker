/// 비-웹 플랫폼 stub. 메모 딥링크 URL/쿼리 파라미터 관련 함수의 no-op 구현.
String? readMemoIdFromUrl() => null;
void clearMemoQueryParam() {}

/// 현재 위치 기준으로 특정 메모를 여는 공유 URL을 만든다.
/// 비웹에서는 메모 ID만 담은 임시 URL을 반환 (실제 사용처는 웹 전용).
String buildMemoShareUrl(String memoId) => '?memo=$memoId';
