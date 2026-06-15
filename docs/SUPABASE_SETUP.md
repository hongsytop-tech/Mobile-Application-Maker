# Supabase Edge Function 셋업 가이드

웹 브라우저에서 알라딘/교보문고 API의 CORS 차단을 우회하기 위해
**Supabase Edge Function (Deno)** 으로 프록시를 띄웁니다.

## 1. Supabase 프로젝트 생성 (5분)

1. https://supabase.com 가입 (GitHub 로그인 권장, **무료 티어로 충분**)
2. **New Project** → 이름(예: `self-dev-app`), DB 비밀번호 설정, 리전은 **Northeast Asia (Seoul)** 추천
3. 프로젝트 생성 후 좌측 **Project Settings → General**에서 **Reference ID** 복사 (`abcdxxxx`)

## 2. Supabase CLI 설치

### 로컬 macOS / Linux
```bash
# macOS
brew install supabase/tap/supabase

# Linux
curl -fsSL https://get.supabase.com | bash
```

### GitHub Codespaces
```bash
curl -fsSL https://github.com/supabase/cli/releases/latest/download/supabase_linux_amd64.tar.gz \
  | tar -xz -C ~/.local/bin/
supabase --version
```

## 3. 로그인 + 프로젝트 연결

```bash
# 브라우저로 인증
supabase login

# 프로젝트 연결 (저장소 루트에서)
supabase link --project-ref 복사한_REFERENCE_ID
```

## 4. 시크릿 등록

```bash
# 알라딘 (가격·링크·TOC 일부)
supabase secrets set ALADIN_TTB_KEY=발급받은_알라딘_TTB_키

# 국립중앙도서관 서지정보유통지원시스템 (TOC 폴백, 선택)
# 신청: https://www.nl.go.kr/seoji/contents/S80100000000.do
supabase secrets set NLK_CERT_KEY=발급받은_seoji_인증키
```

> NLK_CERT_KEY가 없어도 함수는 동작 (알라딘만 사용). 있으면 TOC 커버리지가 더 넓어집니다.

## 5. Edge Function 배포

```bash
# 저장소 루트에서
supabase functions deploy book-toc --no-verify-jwt
```

성공하면 함수 URL이 출력됩니다:
```
Function deployed: https://abcdxxxx.supabase.co/functions/v1/book-toc
```

## 6. Flutter 앱에 URL 등록

`.env` 갱신:
```bash
echo "BOOK_TOC_PROXY_URL=https://abcdxxxx.supabase.co/functions/v1/book-toc" >> .env
```

기존 카카오 키는 유지:
```
KAKAO_REST_API_KEY=...
BOOK_TOC_PROXY_URL=https://abcdxxxx.supabase.co/functions/v1/book-toc
```

`flutter run`을 한 번 종료(`q`)하고 다시 실행하면 적용됩니다.

## 7. 동작 확인

### 로컬에서 직접 호출 (선택)
```bash
curl "https://abcdxxxx.supabase.co/functions/v1/book-toc?isbn=9788934994732"
# 기대 응답:
# {"source":"aladin","toc":["1장 ...","2장 ..."],"priceStandard":18000,...}
```

### 앱에서 확인
- 책 검색 → 추가 → **"자동 가져오기"** 클릭
- 알라딘에 TOC 있는 책이면 그대로 표시
- 알라딘에 없으면 자동으로 교보문고 시도

## 8. 로그 모니터링

```bash
supabase functions logs book-toc --tail
```

또는 Supabase 대시보드 → **Edge Functions → book-toc → Logs**.

## 트러블슈팅

| 증상 | 원인 / 해결 |
|------|-------------|
| `프록시 오류 (500)` | 함수 로그 확인 — 보통 ALADIN_TTB_KEY 미설정 |
| `프록시 오류 (404)` | URL 오타 또는 함수 미배포 |
| `목차를 찾지 못했어요` | 알라딘·교보문고 둘 다 없는 책. 수동 입력 권장 |
| 교보문고만 자주 실패 | HTML 구조 변경 가능성. `kyobo.ts` 의 정규식 패턴 보강 필요 |

## 향후 확장

이 프록시 인프라는 다음 기능에도 그대로 활용됩니다:
- 알라딘 가격 정보 캐싱
- 카카오/네이버 검색 API 통합
- 소셜 로그인 OAuth 콜백 (카카오/네이버)
- 책 데이터 클라우드 동기화 (`books` 테이블 + RLS)
