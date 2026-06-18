-- PostgREST upsert(on_conflict=user_id,kind,ref_id)는 unique 인덱스가 아니라
-- unique CONSTRAINT 를 요구한다. 인덱스를 제약으로 교체.
--
-- 부분 인덱스(where ref_id is not null)는 제약으로 만들 수 없으므로,
-- ref_id 에 빈 문자열 기본값을 쓰는 대신 전체 컬럼 unique 제약을 건다.
-- 1회성(test 등)도 ref_id 를 부여하거나 NULL 허용을 위해 아래처럼 처리:
--   - 기존 부분 unique 인덱스 제거
--   - ref_id NULL 행은 제약에서 제외되도록 COALESCE 기반 표현식은 제약 불가 →
--     대신 ref_id NOT NULL 인 반복/개별 행만 제약 대상이 되도록 1회성은 ref_id 를 유지(NULL)

drop index if exists public.scheduled_pushes_unique_ref;

-- NULL 은 unique 제약에서 서로 충돌하지 않으므로(표준 SQL),
-- 1회성(ref_id NULL)은 자유롭게 중복 insert 가능하고
-- 반복/개별(ref_id 지정)만 (user_id,kind,ref_id) 로 유일.
alter table public.scheduled_pushes
  drop constraint if exists scheduled_pushes_ref_unique;
alter table public.scheduled_pushes
  add constraint scheduled_pushes_ref_unique
  unique (user_id, kind, ref_id);
