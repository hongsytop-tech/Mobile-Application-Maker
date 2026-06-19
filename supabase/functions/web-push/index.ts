// Web Push (VAPID) 전송 백엔드.
//
// actions:
//   - public_key : VAPID 공개키 반환 (인증 불필요)
//   - send_test  : 호출자의 모든 구독에 테스트 푸시 전송 (사용자 JWT)
//   - run_due    : 도래한 scheduled_pushes 를 일괄 발송 (스케줄러 시크릿)
//
// Secrets:
//   VAPID_PUBLIC_KEY   : 필수
//   VAPID_PRIVATE_KEY  : 필수
//   VAPID_SUBJECT      : mailto:hongsytop@gmail.com 등
//   SCHEDULER_SECRET   : run_due 호출용 공유 시크릿 (pg_cron 과 동일 값)

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import webpush from 'npm:web-push@3.6.7';
import { corsHeaders } from '../_shared/cors.ts';

const VAPID_PUBLIC = Deno.env.get('VAPID_PUBLIC_KEY') ?? '';
const VAPID_PRIVATE = Deno.env.get('VAPID_PRIVATE_KEY') ?? '';
const VAPID_SUBJECT = Deno.env.get('VAPID_SUBJECT') ?? 'mailto:hongsytop@gmail.com';
const SCHEDULER_SECRET = Deno.env.get('SCHEDULER_SECRET') ?? '';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

if (VAPID_PUBLIC && VAPID_PRIVATE) {
  webpush.setVapidDetails(VAPID_SUBJECT, VAPID_PUBLIC, VAPID_PRIVATE);
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  let body: any;
  try {
    body = await req.json();
  } catch {
    return j(400, { error: 'invalid_json' });
  }

  const action = body.action as string;
  const admin = createClient(SUPABASE_URL, SERVICE_ROLE);

  // public_key 는 인증 없이 접근 가능
  if (action === 'public_key') {
    if (!VAPID_PUBLIC) return j(500, { error: 'vapid_not_configured' });
    return j(200, { public_key: VAPID_PUBLIC });
  }

  // run_due 는 SCHEDULER_SECRET 인증 (사용자 JWT 불필요)
  if (action === 'run_due') {
    const auth = req.headers.get('Authorization') ?? '';
    if (!SCHEDULER_SECRET || auth !== `Bearer ${SCHEDULER_SECRET}`) {
      return j(401, { error: 'scheduler_unauthorized' });
    }
    try {
      return await runDue(admin);
    } catch (e) {
      return j(500, { error: 'internal', detail: String(e) });
    }
  }

  // 그 외는 사용자 JWT 필요
  const auth = req.headers.get('Authorization');
  if (!auth) return j(401, { error: 'missing_authorization' });
  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: auth } },
  });
  const { data: { user } } = await userClient.auth.getUser();
  if (!user) return j(401, { error: 'invalid_user' });

  try {
    switch (action) {
      case 'send_test':
        return await sendTest(user.id, admin);
      case 'test_scheduled':
        return await testScheduled(user.id, admin);
      default:
        return j(400, { error: 'unknown_action' });
    }
  } catch (e) {
    return j(500, { error: 'internal', detail: String(e) });
  }
});

async function runDue(admin: any) {
  if (!VAPID_PUBLIC || !VAPID_PRIVATE) {
    console.log('runDue: VAPID not configured');
    return j(500, { error: 'vapid_not_configured' });
  }

  const { data: due, error } = await admin
    .from('scheduled_pushes')
    .select('*')
    .is('sent_at', null)
    .lte('scheduled_at', new Date().toISOString())
    .order('scheduled_at', { ascending: true })
    .limit(100);
  if (error) {
    console.log('runDue: query failed', error.message);
    return j(500, { error: 'query_failed', detail: error.message });
  }
  if (!due || due.length === 0) {
    console.log('runDue: no due rows');
    return j(200, { ok: true, processed: 0 });
  }
  console.log(`runDue: ${due.length} due row(s)`);

  const now = Date.now();
  const GRACE_MS = 5 * 60 * 1000; // 5분 이상 늦은 알림은 발송 생략(전진만)
  let processed = 0;
  let failed = 0;

  // 사용자별 알림 설정 캐시 (동일 user_id 가 여러 행을 가질 수 있음)
  const settingsCache = new Map<string, any>();
  async function loadSettings(userId: string): Promise<any> {
    if (settingsCache.has(userId)) return settingsCache.get(userId);
    let opts: any = null;
    try {
      const { data: row } = await admin
        .from('user_data')
        .select('settings')
        .eq('user_id', userId)
        .maybeSingle();
      const raw = row?.settings?.notification_settings_v1;
      if (typeof raw === 'string') {
        opts = JSON.parse(raw);
      } else if (raw && typeof raw === 'object') {
        opts = raw;
      }
    } catch (_) {}
    settingsCache.set(userId, opts);
    return opts;
  }

  for (const p of due) {
    try {
      const scheduledMs = new Date(p.scheduled_at).getTime();
      const tooStale = now - scheduledMs > GRACE_MS;
      console.log(
        `[row ${p.id.slice(0, 8)}] kind=${p.kind} ref=${p.ref_id} title="${p.title}" recur=${!!p.recur}`,
      );

      // 사용자 알림 설정 조회 (방해금지/진동)
      const opts = await loadSettings(p.user_id);
      const inQuietHours = opts?.quietHoursEnabled
        ? isInQuietHours(now, opts)
        : false;
      // 진동: false 면 [0] (0ms = 무진동) 으로 명시.
      // vibrate 키 자체를 빼면 브라우저가 OS 기본 진동을 사용해서 진동을 못 끔.
      const vibrate: number[] = opts?.vibrate === false ? [0] : [200, 100, 200];
      console.log(
        `[row ${p.id.slice(0, 8)}] quietHours=${inQuietHours} vibrate=${opts?.vibrate === false ? 'off' : 'on'}`,
      );

      // 방해금지 시간대에 도래한 알림 → 발송 생략하고 다음 시각으로 전진
      // (1회성이면 종료 시각 이후로 미루기)
      if (inQuietHours) {
        if (p.recur) {
          await advanceRecurRow(admin, p, now, 'quiet_hours');
        } else {
          const resumeAt = quietHoursEndAfter(now, opts);
          await admin
            .from('scheduled_pushes')
            .update({ scheduled_at: new Date(resumeAt).toISOString() })
            .eq('id', p.id);
        }
        continue;
      }

      // 반복(recur) 행이고 너무 늦었으면 발송 생략하고 다음 시각으로 전진만
      if (p.recur && tooStale) {
        await advanceRecurRow(admin, p, now);
        continue;
      }

      const { data: subs } = await admin
        .from('web_push_subscriptions')
        .select('*')
        .eq('user_id', p.user_id);

      console.log(
        `[row ${p.id.slice(0, 8)}] subscriptions=${subs?.length ?? 0}`,
      );

      if (!subs || subs.length === 0) {
        // 구독 없음 — 반복 행은 전진, 1회성은 sent 마킹
        if (p.recur) {
          await advanceRecurRow(admin, p, now, 'no_subscription');
        } else {
          await admin
            .from('scheduled_pushes')
            .update({
              sent_at: new Date().toISOString(),
              last_error: 'no_subscription',
            })
            .eq('id', p.id);
        }
        continue;
      }

      const payload = JSON.stringify({
        title: p.title,
        body: p.body,
        url: p.url || 'https://hongsytop-tech.github.io/Mobile-Application-Maker/',
        tag: `${p.kind}-${p.id}`,
        vibrate,
      });

      const expiredIds: string[] = [];
      let anyOk = false;
      let lastErr: string | undefined;

      for (const s of subs) {
        try {
          await webpush.sendNotification(
            { endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } },
            payload,
          );
          anyOk = true;
          console.log(
            `[row ${p.id.slice(0, 8)}] sub=${s.id.slice(0, 8)} -> OK`,
          );
        } catch (e: any) {
          const status = e?.statusCode;
          lastErr = `status=${status} ${String(e?.body ?? e?.message ?? e).slice(0, 120)}`;
          console.log(
            `[row ${p.id.slice(0, 8)}] sub=${s.id.slice(0, 8)} -> FAIL ${lastErr}`,
          );
          if (status === 404 || status === 410) { // 영구 만료만 삭제 (401/403 전송오류는 유지)
            expiredIds.push(s.id);
          }
        }
      }

      if (expiredIds.length > 0) {
        await admin.from('web_push_subscriptions').delete().in('id', expiredIds);
      }

      if (p.recur) {
        // 반복: 다음 시각으로 전진 (행 재사용)
        await advanceRecurRow(admin, p, now, anyOk ? null : lastErr ?? 'all_failed');
      } else {
        await admin
          .from('scheduled_pushes')
          .update({
            sent_at: new Date().toISOString(),
            attempt_count: (p.attempt_count ?? 0) + 1,
            last_error: anyOk ? null : lastErr ?? 'all_failed',
          })
          .eq('id', p.id);
      }

      if (anyOk) processed++;
      else failed++;
    } catch (e) {
      failed++;
      await admin
        .from('scheduled_pushes')
        .update({
          attempt_count: (p.attempt_count ?? 0) + 1,
          last_error: String(e).slice(0, 500),
        })
        .eq('id', p.id);
    }
  }

  return j(200, { ok: true, processed, failed, total: due.length });
}

/// 반복 행을 다음 발송 시각으로 전진시키고 body/index 를 갱신한다.
async function advanceRecurRow(admin: any, p: any, nowMs: number, lastError?: string | null) {
  const recur = p.recur ?? {};
  const nextAt = computeNextOccurrence(recur, new Date(p.scheduled_at).getTime(), nowMs);
  if (nextAt == null) {
    // 계산 불가 → 더 이상 반복 안 함 (sent 마킹)
    await admin.from('scheduled_pushes').update({
      sent_at: new Date().toISOString(),
      last_error: lastError ?? 'recur_compute_failed',
    }).eq('id', p.id);
    return;
  }

  // 순차 회전 body 갱신
  let nextBody = p.body;
  let nextRecur = recur;
  const bodies = recur.bodies as string[] | undefined;
  if (Array.isArray(bodies) && bodies.length > 0) {
    const idx = ((recur.index ?? 0) + 1) % bodies.length;
    nextBody = bodies[idx];
    nextRecur = { ...recur, index: idx };
  }

  await admin.from('scheduled_pushes').update({
    scheduled_at: new Date(nextAt).toISOString(),
    body: nextBody,
    recur: nextRecur,
    sent_at: null,
    attempt_count: (p.attempt_count ?? 0) + 1,
    last_error: lastError ?? null,
  }).eq('id', p.id);
}

/// recur 설정에 따라 fromMs 이후 + nowMs 이후의 첫 발송 시각(ms) 계산.
function computeNextOccurrence(recur: any, fromMs: number, nowMs: number): number | null {
  const mode = recur.mode as string;
  if (mode === 'interval') {
    const mins = Number(recur.intervalMinutes ?? 0);
    if (mins < 1) return null;
    const step = mins * 60 * 1000;
    let t = fromMs + step;
    if (t <= nowMs) {
      const skip = Math.floor((nowMs - t) / step) + 1;
      t += skip * step;
    }
    return t;
  }
  const hour = Number(recur.hour ?? 9);
  const minute = Number(recur.minute ?? 0);
  if (mode === 'daily') {
    return nextDailyAfter(nowMs, hour, minute);
  }
  if (mode === 'weekly') {
    const weekdays: number[] = Array.isArray(recur.weekdays) ? recur.weekdays : [];
    if (weekdays.length === 0) return null;
    // 향후 14일 내에서 첫 매칭 요일/시각
    for (let d = 0; d <= 14; d++) {
      const cand = dayAt(nowMs, d, hour, minute);
      if (cand <= nowMs) continue;
      const wd = isoWeekday(cand); // 1=Mon..7=Sun
      if (weekdays.includes(wd)) return cand;
    }
    return null;
  }
  if (mode === 'monthly') {
    const md = Number(recur.monthDay ?? 1);
    for (let m = 0; m <= 2; m++) {
      const cand = monthDayAt(nowMs, m, md, hour, minute);
      if (cand != null && cand > nowMs) return cand;
    }
    return null;
  }
  return null;
}

function nextDailyAfter(nowMs: number, hour: number, minute: number): number {
  for (let d = 0; d <= 1; d++) {
    const cand = dayAt(nowMs, d, hour, minute);
    if (cand > nowMs) return cand;
  }
  return dayAt(nowMs, 1, hour, minute);
}

/// KST 기준 현재 시각이 방해금지 시간대 안에 있는지.
/// start > end 면 자정을 넘기는 구간 (예: 23:00 → 08:00).
function isInQuietHours(nowMs: number, opts: any): boolean {
  const k = new Date(nowMs + KST_OFFSET);
  const curMin = k.getUTCHours() * 60 + k.getUTCMinutes();
  const startMin =
    Number(opts.quietStartHour ?? 23) * 60 + Number(opts.quietStartMinute ?? 0);
  const endMin =
    Number(opts.quietEndHour ?? 8) * 60 + Number(opts.quietEndMinute ?? 0);
  if (startMin === endMin) return false;
  if (startMin < endMin) {
    return curMin >= startMin && curMin < endMin;
  }
  // 자정 넘김
  return curMin >= startMin || curMin < endMin;
}

/// 방해금지 구간이 끝나는 다음 시각 (ms UTC).
function quietHoursEndAfter(nowMs: number, opts: any): number {
  const endHour = Number(opts.quietEndHour ?? 8);
  const endMinute = Number(opts.quietEndMinute ?? 0);
  // 오늘 KST 의 종료 시각
  let cand = dayAt(nowMs, 0, endHour, endMinute);
  if (cand <= nowMs) cand = dayAt(nowMs, 1, endHour, endMinute);
  return cand;
}

// KST(UTC+9) 기준으로 날짜 계산. (한국 사용자 고정)
const KST_OFFSET = 9 * 60 * 60 * 1000;
function dayAt(nowMs: number, addDays: number, hour: number, minute: number): number {
  const k = new Date(nowMs + KST_OFFSET);
  const y = k.getUTCFullYear();
  const mo = k.getUTCMonth();
  const da = k.getUTCDate() + addDays;
  // KST 시각 → UTC ms
  return Date.UTC(y, mo, da, hour, minute) - KST_OFFSET;
}
function monthDayAt(nowMs: number, addMonths: number, monthDay: number, hour: number, minute: number): number | null {
  const k = new Date(nowMs + KST_OFFSET);
  const y = k.getUTCFullYear();
  const mo = k.getUTCMonth() + addMonths;
  return Date.UTC(y, mo, monthDay, hour, minute) - KST_OFFSET;
}
function isoWeekday(ms: number): number {
  const k = new Date(ms + KST_OFFSET);
  const wd = k.getUTCDay(); // 0=Sun..6=Sat
  return wd === 0 ? 7 : wd; // 1=Mon..7=Sun
}

async function sendTest(userId: string, admin: any) {
  if (!VAPID_PUBLIC || !VAPID_PRIVATE) {
    return j(500, { error: 'vapid_not_configured' });
  }
  const { data: subs, error } = await admin
    .from('web_push_subscriptions')
    .select('*')
    .eq('user_id', userId);
  if (error) return j(500, { error: 'db_query_failed', detail: error.message });
  if (!subs || subs.length === 0) return j(400, { error: 'no_subscription' });

  // 사용자의 진동 / 방해금지 설정 반영
  let vibrate: number[] = [200, 100, 200];
  let opts: any = null;
  try {
    const { data: row } = await admin
      .from('user_data')
      .select('settings')
      .eq('user_id', userId)
      .maybeSingle();
    const raw = row?.settings?.notification_settings_v1;
    opts = typeof raw === 'string' ? JSON.parse(raw) : raw;
    if (opts?.vibrate === false) vibrate = [0];
  } catch (_) {}

  // 방해금지 시간대면 테스트도 발송하지 않음 (스케줄러 동작과 일치).
  if (opts?.quietHoursEnabled && isInQuietHours(Date.now(), opts)) {
    return j(200, {
      ok: true,
      sent: 0,
      failed: 0,
      cleaned: 0,
      skipped: 'quiet_hours',
      errors: [],
    });
  }

  const payload = JSON.stringify({
    title: '🔔 알림 테스트',
    body: '웹 푸시 알림이 정상적으로 동작합니다.',
    url: 'https://hongsytop-tech.github.io/Mobile-Application-Maker/',
    tag: 'test',
    vibrate,
  });

  let sent = 0;
  let failed = 0;
  const expiredIds: string[] = [];
  const errors: { id: string; status?: number; body?: string }[] = [];

  for (const s of subs) {
    try {
      await webpush.sendNotification(
        { endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } },
        payload,
      );
      sent++;
    } catch (e: any) {
      failed++;
      const status = e?.statusCode;
      errors.push({ id: s.id, status, body: String(e?.body ?? e?.message ?? e).slice(0, 200) });
      // 만료/거부 = 구독 정리 (404/410=gone, 401/403=signature mismatch)
      if (status === 404 || status === 410) { // 영구 만료만 삭제 (401/403 전송오류는 유지)
        expiredIds.push(s.id);
      }
    }
  }

  if (expiredIds.length > 0) {
    await admin.from('web_push_subscriptions').delete().in('id', expiredIds);
  }

  return j(200, { ok: true, sent, failed, cleaned: expiredIds.length, errors });
}

/// 호출자 본인에게 5초 뒤 알림 1건을 예약하고 즉시 run_due 를 돌려서
/// pg_cron 을 기다리지 않고 스케줄러 흐름을 검증.
async function testScheduled(userId: string, admin: any) {
  const scheduledAt = new Date(Date.now() + 5000).toISOString();
  const { error: insertErr } = await admin
    .from('scheduled_pushes')
    .insert({
      user_id: userId,
      kind: 'test',
      title: '⏱️ 스케줄러 테스트',
      body: '백엔드 스케줄러로 전송된 알림입니다.',
      scheduled_at: scheduledAt,
    });
  if (insertErr) {
    return j(500, { error: 'insert_failed', detail: insertErr.message });
  }
  // 5.5초 대기 → scheduled_at 이 도래 → run_due 가 즉시 발송
  await new Promise((r) => setTimeout(r, 5500));
  return await runDue(admin);
}

function j(status: number, payload: unknown) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders },
  });
}
