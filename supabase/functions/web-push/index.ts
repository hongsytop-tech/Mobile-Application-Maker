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
    return j(500, { error: 'vapid_not_configured' });
  }

  const { data: due, error } = await admin
    .from('scheduled_pushes')
    .select('*')
    .is('sent_at', null)
    .lte('scheduled_at', new Date().toISOString())
    .order('scheduled_at', { ascending: true })
    .limit(100);
  if (error) return j(500, { error: 'query_failed', detail: error.message });
  if (!due || due.length === 0) return j(200, { ok: true, processed: 0 });

  let processed = 0;
  let failed = 0;

  for (const p of due) {
    try {
      const { data: subs } = await admin
        .from('web_push_subscriptions')
        .select('*')
        .eq('user_id', p.user_id);

      if (!subs || subs.length === 0) {
        // 구독 없음 — sent_at 으로 마킹해 중복 처리 방지
        await admin
          .from('scheduled_pushes')
          .update({
            sent_at: new Date().toISOString(),
            last_error: 'no_subscription',
          })
          .eq('id', p.id);
        continue;
      }

      const payload = JSON.stringify({
        title: p.title,
        body: p.body,
        url: p.url || 'https://hongsytop-tech.github.io/Mobile-Application-Maker/',
        tag: `${p.kind}-${p.id}`,
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
        } catch (e: any) {
          const status = e?.statusCode;
          lastErr = `status=${status} ${String(e?.body ?? e?.message ?? e).slice(0, 120)}`;
          if (status === 404 || status === 410 || status === 401 || status === 403) {
            expiredIds.push(s.id);
          }
        }
      }

      if (expiredIds.length > 0) {
        await admin.from('web_push_subscriptions').delete().in('id', expiredIds);
      }

      await admin
        .from('scheduled_pushes')
        .update({
          sent_at: new Date().toISOString(),
          attempt_count: (p.attempt_count ?? 0) + 1,
          last_error: anyOk ? null : lastErr ?? 'all_failed',
        })
        .eq('id', p.id);

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

  const payload = JSON.stringify({
    title: '🔔 알림 테스트',
    body: '웹 푸시 알림이 정상적으로 동작합니다.',
    url: 'https://hongsytop-tech.github.io/Mobile-Application-Maker/',
    tag: 'test',
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
      if (status === 404 || status === 410 || status === 401 || status === 403) {
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
