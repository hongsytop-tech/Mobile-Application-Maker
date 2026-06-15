# 폰 설치용 APK 자동 빌드 셋업

코드를 푸시하면 GitHub Actions가 APK를 자동으로 빌드해서
**GitHub Releases**에 올립니다. 폰 브라우저로 페이지 열어
다운로드 → 설치하면 됩니다. 같은 keystore로 매번 서명되므로
**기존 데이터(책장·문구)를 보존**하면서 업데이트됩니다.

## 1. Keystore 생성 (한 번만, 분실 금지!)

Codespaces 터미널에서 실행:

```bash
keytool -genkey -v \
  -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias selfdev \
  -dname "CN=SelfDev, OU=Personal, O=SelfDev, L=Seoul, ST=Seoul, C=KR" \
  -storepass CHANGE_ME_STRONG_PASSWORD \
  -keypass  CHANGE_ME_STRONG_PASSWORD
```

> 🚨 **비밀번호는 본인만 알아야 합니다**. 한 번 정하면 절대 잊지 마세요.
> 분실 시 같은 키로 서명 불가 → 폰에 새 앱으로 다시 설치해야 하고
> 기존 데이터가 모두 사라집니다.

> `upload-keystore.jks` 파일도 안전한 곳에 백업하세요
> (예: 1Password, Bitwarden, USB 드라이브).
> **절대 GitHub에 커밋하지 마세요.**

## 2. base64 인코딩

GitHub Secrets는 텍스트만 저장하므로 keystore를 base64로 변환:

```bash
base64 -w 0 upload-keystore.jks
```

출력된 긴 문자열 전체를 복사 (다음 단계에서 사용).

## 3. GitHub Secrets 등록

브라우저로 이동:
**레포 페이지** → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

다음 4개의 secret을 추가:

| Name | Value |
|------|-------|
| `ANDROID_KEYSTORE_BASE64` | 위에서 출력한 base64 문자열 전체 |
| `ANDROID_KEYSTORE_PASSWORD` | keystore 생성 시 입력한 `-storepass` 값 |
| `ANDROID_KEY_PASSWORD` | `-keypass` 값 (보통 storepass와 동일) |
| `ANDROID_KEY_ALIAS` | `selfdev` (위 명령의 `-alias` 값) |

그리고 앱이 동작하려면 카카오 키도 필요:

| Name | Value |
|------|-------|
| `KAKAO_REST_API_KEY` | 본인 카카오 REST API 키 |
| `BOOK_TOC_PROXY_URL` | `https://mvuedgnyzlaysprxhasw.supabase.co/functions/v1/book-toc` |

> Secrets에 등록한 값은 한 번 저장되면 다시 볼 수 없습니다(재입력만 가능). GitHub UI 표준 동작입니다.

## 4. 첫 빌드 트리거

코드를 푸시하거나, **레포 → Actions 탭 → "Build Android APK" → Run workflow** 클릭.

빌드는 약 **5~10분** 소요됩니다. (Flutter SDK 캐시 후엔 더 빨라짐)

## 5. APK 다운로드

빌드 성공 시:
1. **레포 페이지** → **Releases** → 최신 `Build #N` 클릭
2. 폰 브라우저로 같은 페이지를 열고
3. **`self-dev-app-arm64-v8a-build{N}.apk`** 탭 → 다운로드
4. 다운로드 알림 → 파일 탭 → **"출처 알 수 없는 앱 설치"** 허용 → **설치**

> 64-bit 폰: `arm64-v8a` (대부분의 최신 폰)
> 32-bit 폰 또는 잘 모르면: `universal` (용량이 좀 더 크지만 모두 동작)

## 6. 업데이트

코드가 바뀔 때마다:
1. 코드 푸시 → 자동 빌드
2. 폰에서 Releases 페이지 새로고침
3. 새 빌드 APK 다운로드 → 탭 → 설치
4. **기존 데이터는 자동으로 유지됨** (같은 서명·패키지명)

## 7. 트러블슈팅

| 증상 | 원인 / 해결 |
|------|-------------|
| Actions에서 `signingConfig` 에러 | KEYSTORE_BASE64가 잘리거나 깨짐 → 다시 인코딩하고 secret 재등록 |
| 폰에서 설치 시 `앱이 설치되지 않았습니다` | 이전 버전이 **다른 서명**으로 깔려있음 → 폰에서 기존 앱 삭제 후 재설치 (이때 데이터 사라짐) |
| 설치 후 검색이 401 | KAKAO_REST_API_KEY가 잘못 됨 → secret 확인 |
| Releases 페이지에 APK 없음 | 빌드가 실패함 → Actions 탭에서 로그 확인 |
| 두 빌드 사이에 데이터 안 유지 | 같은 keystore 사용 확인. 다른 secret으로 빌드되면 안드로이드가 새 앱으로 인식 |

## 8. 보안 체크

- ✅ keystore 파일과 비밀번호는 **GitHub Secrets에만** 보관
- ✅ 채팅, 이슈, 코드, 로그 어디에도 평문으로 노출 X
- ✅ keystore 파일을 분실하면 같은 앱으로 업데이트 불가 → 백업 필수
- ❌ keystore를 그냥 git에 커밋하지 마세요
