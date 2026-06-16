-- 카카오톡 메모(나에게 보내기) API 용 토큰 저장소
-- access_token 은 약 6시간, refresh_token 은 약 60일 유효.
-- Edge Function 이 서비스 롤로 upsert/update 하므로 RLS 정책은 select/delete 만 본인 허용.

create table if not exists public.kakao_tokens (
  user_id uuid primary key references auth.users(id) on delete cascade,
  access_token text not null,
  refresh_token text not null,
  expires_at timestamptz not null,
  refresh_token_expires_at timestamptz,
  scopes text[] not null default '{}',
  kakao_user_id bigint,
  linked_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.kakao_tokens enable row level security;

-- 본인 토큰 존재 여부 조회만 허용 (access_token 은 노출되지만, anon-key 클라이언트가 RLS 통과 = JWT 본인이므로 이론상 본인 토큰만 봄)
drop policy if exists kakao_tokens_self_select on public.kakao_tokens;
create policy kakao_tokens_self_select on public.kakao_tokens
  for select to authenticated using (auth.uid() = user_id);

drop policy if exists kakao_tokens_self_delete on public.kakao_tokens;
create policy kakao_tokens_self_delete on public.kakao_tokens
  for delete to authenticated using (auth.uid() = user_id);
