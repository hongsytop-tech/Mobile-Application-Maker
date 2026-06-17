-- 같은 사용자/종류에 같은 시각이 중복 등록되지 않도록 unique constraint.
-- 양 기기가 동일 anchor + interval 기반으로 스케줄을 생성하면
-- 시각이 일치 → 한 쪽은 ignored 되어 멱등 처리됨.

-- 기존 중복이 있을 수 있어 먼저 정리.
delete from public.scheduled_pushes a
  using public.scheduled_pushes b
where a.id < b.id
  and a.user_id = b.user_id
  and a.kind = b.kind
  and a.scheduled_at = b.scheduled_at;

alter table public.scheduled_pushes
  drop constraint if exists scheduled_pushes_unique_slot;

alter table public.scheduled_pushes
  add constraint scheduled_pushes_unique_slot
  unique (user_id, kind, scheduled_at);
