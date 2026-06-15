# Self-Dev App

자기계발을 위한 통합 모바일 어플리케이션. 하단 탭으로 모듈을 전환합니다.

## 📱 현재 구현된 기능

### 📖 독서 모듈
1. 책 제목 검색 (카카오 책 API)
2. 위시리스트 / 읽는중 / 완독 3단 책장
3. 목차 자동 가져오기 폴백 체인 (알라딘 API → 알라딘 웹 → NLK → 교보문고 SSR)
4. 알라딘 가격·구매 링크, 교보문고 정보 링크
5. 챕터별 체크박스 진행도 + 수동 편집
6. 완독 처리 + 완독일 기록
7. 기간별 독서 통계 (오늘/주/월/년/전체, 월별 그래프)
8. ISBN 단위 Postgres 캐싱 (Supabase, 30일 TTL)

### 📝 문구 모듈
1. 기억하고 싶은 문구 저장 + 입력 날짜 기록
2. 매일 지정 시간 알림 (로컬 푸시) — 모바일 전용
3. 스와이프 삭제, 탭 편집

## 🚀 실행 방법

### 사전 준비
1. Flutter SDK 3.22+ 설치 (`flutter doctor`)
2. 카카오 REST API 키 발급
   - https://developers.kakao.com → 내 애플리케이션 → REST API 키
3. 알라딘 TTB 키 발급 (목차 자동 가져오기용)
   - https://www.aladin.co.kr/ttb/wblog_manage.aspx → TTB Key 발급
4. **Supabase Edge Function 셋업** — [`docs/SUPABASE_SETUP.md`](./docs/SUPABASE_SETUP.md)
   - 알라딘/교보문고 호출은 CORS로 직접 불가하므로 Supabase 프록시를 거침
5. 프로젝트 루트에 `.env` 파일 생성:
   ```
   KAKAO_REST_API_KEY=발급받은_카카오_키
   BOOK_TOC_PROXY_URL=https://<프로젝트>.supabase.co/functions/v1/book-toc
   ```
   > 알라딘 TTB 키는 Supabase secret으로 보관 (클라이언트에 노출 X)

### 첫 실행
```bash
# 플랫폼별 폴더(android/ios/web)를 생성
flutter create . --project-name self_dev_app --org com.selfdev --platforms=android,ios,web

# 알림 권한·리시버 패치 (안드로이드 알림 사용 시)
bash scripts/patch_android_manifest.sh

flutter pub get

# 웹(Codespaces 프리뷰)
flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0

# 실기기/에뮬레이터
flutter run
```

### GitHub Codespaces
`.devcontainer/`가 설정되어 있어 Codespace를 열면 Flutter SDK가 자동 설치됩니다. 셋업 후:
```bash
flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0
```
포워딩된 8080 포트에서 미리보기 가능합니다.

## 🗂 프로젝트 구조

```
lib/
├── main.dart
├── app.dart
└── features/
    └── reading/
        ├── models/book.dart
        ├── services/
        │   ├── book_search_service.dart   # 카카오 책 API (직접)
        │   ├── book_toc_service.dart      # Supabase 프록시 → 알라딘/교보문고
        │   └── book_storage_service.dart  # SharedPreferences

supabase/
├── config.toml
└── functions/
    ├── _shared/cors.ts
    └── book-toc/
        ├── index.ts       # 프록시 엔트리포인트
        ├── aladin.ts      # 알라딘 ItemLookUp
        └── kyobo.ts       # 교보문고 스크래핑 (best-effort)
        ├── providers/book_providers.dart  # Riverpod
        ├── widgets/book_cover.dart
        └── screens/
            ├── home_screen.dart           # 읽는중 / 다 읽은 책 탭
            ├── search_screen.dart         # 책 검색
            └── book_detail_screen.dart    # 목차/진행도
```

## 🛣 다음 단계

- [x] 알라딘 TOC 자동 가져오기
- [x] 교보문고 TOC 폴백 (Supabase Edge Function 프록시)
- [ ] 프록시에 캐싱 추가 (KV 또는 Postgres)
- [ ] AI 기반 목차 추정 (모든 소스 실패 시 fallback)
- [ ] 일일 독서 시간 타이머
- [ ] 독서 메모/하이라이트
- [ ] 통계 대시보드 (월별 완독 수, 장르 분포)
- [ ] 클라우드 동기화 (Supabase)

상위 로드맵은 [`ROADMAP.md`](./ROADMAP.md) 참고.
