# 웹 배포 (GitHub Pages)

푸시할 때마다 Flutter Web 빌드가 자동으로 GitHub Pages에 배포됩니다.

## 1. GitHub Pages 활성화 (한 번만)

레포 페이지 → **Settings** → 좌측 **Pages**

- **Source**: `GitHub Actions` 선택 (드롭다운)
- 다른 옵션 없음 → 저장 자동

> 처음 활성화 시 "GitHub Pages source saved" 메시지 표시.

## 2. 워크플로우 권한 확인

레포 → **Settings** → **Actions** → **General**

하단 **Workflow permissions** 영역:
- `Read and write permissions` 선택
- `Allow GitHub Actions to create and approve pull requests` 체크
- **Save**

## 3. 자동 배포

푸시 → 약 5~8분 후 배포 완료.

배포 URL: **https://hongsytop-tech.github.io/Mobile-Application-Maker/**

(`hongsytop-tech` = 본인 GitHub username/org)

## 4. 동작하는 것 / 안 하는 것

| 기능 | 웹에서 동작? |
|------|------------|
| 책 검색·등록·통계 | ✅ |
| 위시리스트·완독 처리 | ✅ |
| 책 목차 (Supabase 프록시) | ✅ |
| 일기 (캘린더 + 작성) | ✅ |
| 문구 작성·고정 | ✅ |
| To-do (카테고리·체크) | ✅ |
| 이메일/비번 로그인 + 백업 | ✅ |
| Google 로그인 | △ Web Client ID 별도 origin 등록 필요 |
| **알림** (문구·할 일) | ❌ 브라우저 Push는 별도 구현 필요 |
| 앱 내 자동 업데이트 배너 | ❌ (의미 없으므로 자동 숨김) |
| 외부 링크 (알라딘/교보) | ✅ (새 탭) |

## 5. Google 로그인을 웹에서도 쓰려면

Google Cloud Console → OAuth Web 클라이언트 → **Authorized JavaScript origins**에 추가:
```
https://hongsytop-tech.github.io
```

그리고 **Authorized redirect URIs**에:
```
https://hongsytop-tech.github.io/Mobile-Application-Maker/
```

(웹 Google 로그인 구현은 다음 작업에서)

## 6. 자동 새로고침

코드 변경 → 푸시 → 5~8분 대기 → 브라우저 새로고침 → 최신 반영.

별도 "업데이트" 단계 없이 새로고침이 곧 업데이트입니다.

## 7. 데이터 위치

- 폰 앱: SharedPreferences (앱별 격리)
- 웹: 브라우저 localStorage (도메인별 격리)
- 폰과 웹은 **각자 별도 저장**
- 같은 데이터 보려면 **로그인 후 백업/복원** 사용

## 8. 트러블슈팅

| 증상 | 해결 |
|------|------|
| Pages 페이지가 404 | Step 1·2 활성화 다시 확인 |
| 빌드 실패 (Actions 빨간 X) | 로그 보고 메시지 공유 |
| 폰트·아이콘 안 보임 | 첫 로딩에 시간 걸림 (CanvasKit WASM 다운로드) |
| 로그인 실패 | SUPABASE_URL/ANON_KEY secrets 등록 확인 |
| 책 검색 안 됨 | CORS 또는 KAKAO 키. F12 콘솔 확인 |
| 일기 저장 안 됨 | 시크릿 브라우저 모드는 localStorage 제한 |

## 9. 다음 단계 (선택)

- 자체 도메인 연결: Settings → Pages → Custom domain
- Cloudflare Pages로 이전 (더 빠른 CDN)
- PWA 매니페스트 정리 (홈 화면에 추가 가능)
