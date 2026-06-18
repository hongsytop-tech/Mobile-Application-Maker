-- 반복 알림을 위한 recur 설정.
-- recur 가 null 이면 1회성(기존과 동일).
-- recur 가 있으면 runDue 가 발송 후 scheduled_at 을 다음 발송 시각으로 전진시켜
--   하나의 행이 영구히 반복된다. (40개 미리 생성 방식 폐기)
--
-- recur jsonb 예:
--   interval: {"mode":"interval","intervalMinutes":1,"bodies":["..."],"index":0}
--   daily   : {"mode":"daily","hour":9,"minute":0}
--   weekly  : {"mode":"weekly","hour":9,"minute":0,"weekdays":[1,3,5]}
--   monthly : {"mode":"monthly","hour":9,"minute":0,"monthDay":15}
--   bodies/index 는 순차 회전(문구 순차알림)용. 없으면 body 고정.

alter table public.scheduled_pushes
  add column if not exists recur jsonb;

-- 옛 40슬롯 방식 행 먼저 정리 (unique 인덱스 생성 전에 중복 제거).
delete from public.scheduled_pushes
where kind in ('quote_rotation', 'quote_individual');

-- 혹시 남은 (user_id,kind,ref_id) 중복도 제거 (가장 최근 1건만 유지).
delete from public.scheduled_pushes a
  using public.scheduled_pushes b
where a.ctid < b.ctid
  and a.user_id = b.user_id
  and a.kind = b.kind
  and a.ref_id is not null
  and a.ref_id = b.ref_id;

-- 반복 행은 scheduled_at 이 계속 바뀌므로 (user_id,kind,scheduled_at) unique 는 부적합.
-- 대신 "스케줄 1개 = 행 1개"를 (user_id,kind,ref_id) 로 보장 (ref_id 있는 경우만).
alter table public.scheduled_pushes
  drop constraint if exists scheduled_pushes_unique_slot;

create unique index if not exists scheduled_pushes_unique_ref
  on public.scheduled_pushes (user_id, kind, ref_id)
  where ref_id is not null;
