# Google Tasks 자동 동기화 설정

운전 중 "Hey Google, 할 일 추가"로 Google Tasks 에 저장한 항목을,
백엔드(cron)가 15분마다 확인해 앱 메모로 자동 추가합니다.
**앱을 열지 않아도** 서버가 알아서 가져옵니다.

동작하려면 아래 4가지 설정이 필요합니다 (최초 1회).

---

## 1. Google Cloud Console — 클라이언트 시크릿 발급

백엔드가 refresh_token 을 교환하려면 **client secret** 이 필요합니다.

1. https://console.cloud.google.com → 해당 프로젝트
2. **API 및 서비스 → 사용자 인증 정보**
3. 기존 **웹 애플리케이션 OAuth 클라이언트** 클릭
4. 우측 **클라이언트 보안 비밀번호(Client secret)** 값 복사
   - 없으면 "새 보안 비밀번호 만들기"
5. **Google Tasks API** 가 사용 설정돼 있는지 확인 (라이브러리)

> JavaScript 원본에 `https://hongsytop-tech.github.io` 는 이미 등록돼 있어야 합니다.
> 팝업(code) 방식이라 리디렉션 URI 는 필요 없습니다.

---

## 2. Supabase — 시크릿 등록

**Dashboard → Edge Functions → Settings (Secrets)** 에 추가:

| 이름 | 값 |
|---|---|
| `GOOGLE_CLIENT_ID` | 웹 OAuth 클라이언트 ID (`GOOGLE_WEB_CLIENT_ID` 와 동일) |
| `GOOGLE_CLIENT_SECRET` | 1번에서 복사한 client secret |

> `SCHEDULER_SECRET`, `SUPABASE_SERVICE_ROLE_KEY` 등은 web-push 설정 시 이미 있습니다.

---

## 3. 마이그레이션 + 함수 배포

```bash
# 테이블 생성 (google_tasks_sync)
supabase db push          # 또는 0011_google_tasks_sync.sql 을 SQL Editor 에서 실행

# Edge Function 배포 (JWT 게이트 끔 — sync_all 은 SCHEDULER_SECRET 인증)
supabase functions deploy google-tasks --no-verify-jwt
```

---

## 4. pg_cron 스케줄 등록

`supabase/cron/google_tasks_sync.sql` 을 열어 `{PROJECT_REF}`, `{SCHEDULER_SECRET}`
를 실제 값으로 바꾼 뒤 **SQL Editor** 에서 실행.

15분마다 `google-tasks:sync_all` 을 호출합니다.

확인:
```sql
select jobname, schedule, active from cron.job;
select * from cron.job_run_details order by start_time desc limit 10;
```

---

## 사용법 (설정 완료 후)

1. 앱 → **마이페이지 → 구글 Tasks 연동 → "자동 연동 켜기"**
2. 구글 팝업에서 계정·권한 허용 (최초 1회 — offline 동의)
3. 이후 **앱을 안 열어도** 15분마다 새 Task 가 메모로 쌓입니다
4. 앱을 열면 클라우드에서 자동으로 내려받아 메모에 표시됩니다

- **지금 즉시 가져오기**: 기다리기 싫을 때 클라이언트에서 바로 1회 가져오기
- **자동 연동 해제**: 서버에 저장된 refresh_token 삭제

---

## 참고 / 한계

- 중복 방지: `google_tasks_sync.imported_task_ids` 로 이미 가져온 Task 는 스킵
- 미완료(needsAction) Task 만 가져옴 (완료 처리한 건 제외)
- 서버가 `user_data.memos` 에 직접 추가 → 앱은 다음 동기화(pull) 시 반영.
  드물게 앱이 stale 로컬을 push 하면 잠깐 안 보일 수 있으나, 앱 진입 시
  pull 이 먼저 일어나 복구됩니다.
- 제목 = Task 제목, 내용 = Task 메모(notes)
