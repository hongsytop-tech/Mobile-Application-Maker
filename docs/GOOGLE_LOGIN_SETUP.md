# Google 로그인 셋업

Supabase + google_sign_in 패키지를 사용한 모바일 Google 로그인 설정 절차입니다.
한 번 설정해두면 코드 변경 없이 동작합니다.

## 1. Google Cloud Console 프로젝트 만들기

1. https://console.cloud.google.com 접속
2. 상단의 **프로젝트 선택** → **새 프로젝트** → 이름(예: `SelfDev`)
3. 생성된 프로젝트로 전환

## 2. OAuth 동의 화면 구성

1. 좌측 메뉴 → **APIs & Services** → **OAuth 동의 화면** (OAuth consent screen)
2. User Type: **외부(External)** 선택 → 만들기
3. 앱 정보 입력:
   - 앱 이름: `SelfDev` (또는 본인 앱명)
   - 사용자 지원 이메일: 본인 이메일
   - 개발자 연락처: 본인 이메일
4. 다음 → 범위는 **그대로 다음** → 테스트 사용자에 본인 이메일 추가 → 저장

> "외부" + 게시 안 함 상태에서는 **테스트 사용자에 추가된 계정만** 로그인 가능합니다. 본인 + 베타 사용자 이메일을 추가하세요.

## 3. OAuth 클라이언트 ID 두 개 만들기

### 3-1. Web 클라이언트 (Supabase + Flutter에서 사용)
1. **APIs & Services** → **Credentials (사용자 인증 정보)**
2. **+ CREATE CREDENTIALS** → **OAuth client ID**
3. Application type: **Web application**
4. 이름: `SelfDev Web`
5. **Authorized redirect URIs**에 다음 추가:
   ```
   https://<your-ref>.supabase.co/auth/v1/callback
   ```
   `<your-ref>`는 Supabase 프로젝트 reference (대시보드 좌측 상단)
6. **만들기** → 표시되는 **클라이언트 ID 복사** (`....apps.googleusercontent.com` 형태)

### 3-2. Android 클라이언트 (실제 로그인 동작용)
1. 다시 **+ CREATE CREDENTIALS** → **OAuth client ID**
2. Application type: **Android**
3. 이름: `SelfDev Android`
4. **Package name**: `com.selfdev.self_dev_app`
5. **SHA-1 certificate fingerprint**: 본인 keystore의 SHA-1
   ```bash
   # Codespaces 터미널에서
   keytool -list -v -keystore upload-keystore.jks -alias selfdev | grep "SHA1:"
   ```
   출력된 SHA1 값(콜론 포함) 그대로 붙여넣기
6. **만들기** → 닫기

> Android 클라이언트는 별도의 클라이언트 ID를 사용하지 않습니다(우리는 Web client ID로 통합 사용). SHA-1을 등록해두는 것만으로도 Google이 우리 앱을 신뢰합니다.

## 4. Supabase에서 Google Provider 활성화

1. Supabase 대시보드 → **Authentication** → **Providers**
2. **Google** 찾기 → **Enable** 토글 ON
3. **Client ID (for OAuth)**: 위 3-1의 Web 클라이언트 ID 붙여넣기
4. **Client Secret**: 비워두기 (모바일 ID 토큰 방식에선 불필요)
5. **Skip nonce checks**: ON (모바일 ID 토큰 호환)
6. **Save**

## 5. .env / GitHub Secrets에 키 등록

### 로컬 (.env)
```bash
echo "GOOGLE_WEB_CLIENT_ID=위에서_복사한_웹_클라이언트_ID" >> .env
```

### GitHub Actions
1. 레포 → **Settings** → **Secrets and variables** → **Actions**
2. **New repository secret**:
   - Name: `GOOGLE_WEB_CLIENT_ID`
   - Value: 위 Web 클라이언트 ID

## 6. 빌드 + 동작 확인

다음 빌드부터 GOOGLE_WEB_CLIENT_ID가 APK에 포함됩니다.

확인:
1. 새 APK 설치
2. 홈 화면 → 우측 상단 사람 아이콘 → **"Google로 시작하기"**
3. Google 계정 선택 화면 → 본인 계정 → 허용 → 자동 로그인 완료
4. 프로필 화면에서 이메일 확인

## 트러블슈팅

| 증상 | 원인 / 해결 |
|------|-------------|
| `ApiException: 10` | SHA-1이 Google Cloud Console에 등록 안 됨 → 3-2 단계 재확인 |
| `ApiException: 12500` | 패키지명 불일치 → `com.selfdev.self_dev_app` 정확히 등록했는지 |
| `ApiException: 7` | 네트워크 / Google Play Services 없음 |
| Supabase에 사용자 안 생김 | Web Client ID 잘못 등록 / Skip nonce checks OFF |
| "테스트 사용자가 아닙니다" 오류 | OAuth 동의 화면에서 본인 이메일을 테스트 사용자로 추가 |
| 로그인은 되는데 한글 이름 안 보임 | 정상. Supabase user_metadata에 들어있음 |

## 베타/상용 출시 시

- OAuth 동의 화면을 **"게시(Publish)"** 상태로 전환 → 누구나 로그인 가능
- 게시 전에는 Google 검토를 받을 수도 있음 (민감 범위가 없으면 보통 즉시 통과)
- 본인 사용 단계에선 "외부 + 테스트 모드 + 테스트 사용자 추가"로 충분
