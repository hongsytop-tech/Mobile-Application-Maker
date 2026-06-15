# Self-Dev App

자기계발을 위한 통합 모바일 어플리케이션. 첫 번째 모듈로 **독서 트래커**가 구현되어 있습니다.

## 📱 현재 구현된 기능 (독서 트래커 v0.1)

1. 책 제목으로 검색 → 카카오 책 API에서 표지·저자·출판사·소개글 자동 조회
2. "읽고 있는 책" 목록 등록
3. 목차(TOC)를 직접 입력/붙여넣기 → 챕터별 체크박스로 진행도 표시
4. "다 읽었어요" → "내가 읽은 책"으로 이동, 완독 날짜 기록

> 카카오 책 API는 표지·저자·소개글까지만 제공하고 **목차는 직접 입력**이 필요합니다. 교보문고 목차 자동 가져오기는 다음 단계에서 추가 예정 (아래 [로드맵](#-다음-단계) 참고).

## 🚀 실행 방법

### 사전 준비
1. Flutter SDK 3.22+ 설치 (`flutter doctor`)
2. 카카오 REST API 키 발급
   - https://developers.kakao.com → 내 애플리케이션 → REST API 키
3. 프로젝트 루트에 `.env` 파일 생성:
   ```
   KAKAO_REST_API_KEY=발급받은_키
   ```

### 첫 실행
```bash
# 플랫폼별 폴더(android/ios/web)를 생성
flutter create . --project-name self_dev_app --org com.selfdev --platforms=android,ios,web

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
        │   ├── book_search_service.dart   # 카카오 책 API
        │   └── book_storage_service.dart  # SharedPreferences
        ├── providers/book_providers.dart  # Riverpod
        ├── widgets/book_cover.dart
        └── screens/
            ├── home_screen.dart           # 읽는중 / 다 읽은 책 탭
            ├── search_screen.dart         # 책 검색
            └── book_detail_screen.dart    # 목차/진행도
```

## 🛣 다음 단계

- [ ] 교보문고 목차 자동 수집 (백엔드 프록시 + 캐시)
- [ ] AI 기반 목차 추정(검색 후 비공개 도서일 때 fallback)
- [ ] 일일 독서 시간 타이머
- [ ] 독서 메모/하이라이트
- [ ] 통계 대시보드 (월별 완독 수, 장르 분포)
- [ ] 클라우드 동기화 (Supabase)

상위 로드맵은 [`ROADMAP.md`](./ROADMAP.md) 참고.
