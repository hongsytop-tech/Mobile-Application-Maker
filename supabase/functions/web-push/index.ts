// Web Push (VAPID) 전송 백엔드.
//
// actions:
//   - public_key : VAPID 공개키 반환 (인증 불필요)
//   - send_test  : 호출자의 모든 구독에 테스트 푸시 전송
//   - send_to_user (service role) : 향후 스케줄러용 — admin만 호출
//
// Secrets:
//   VAPID_PUBLIC_KEY  : 필수 (URL-safe base64, P-256 공개키)
//   VAPID_PRIVATE_KEY : 필수
//   VAPID_SUBJECT     : mailto:hongsytop@gmail.com 등

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import webpush from 'npm:web-push@3.6.7';
import { corsHeaders } from '../_shared/cors.ts';

const VAPID_PUBLIC = Deno.env.get('VAPID_PUBLIC_KEY') ?? '';
const VAPID_PRIVATE = Deno.env.get('VAPID_PRIVATE_KEY') ?? '';
const VAPID_SUBJECT = Deno.env.get('VAPID_SUBJECT') ?? 'mailto:hongsytop@gmail.com';

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

  // public_key 는 인증 없이 접근 가능
  if (action === 'public_key') {
    if (!VAPID_PUBLIC) return j(500, { error: 'vapid_not_configured' });
    return j(200, { public_key: VAPID_PUBLIC });
  }

  // 그 외는 사용자 JWT 필요
  const auth = req.headers.get('Authorization');
  if (!auth) return j(401, { error: 'missing_authorization' });
  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: auth } },
  });
  const { data: { user } } = await userClient.auth.getUser();
  if (!user) return j(401, { error: 'invalid_user' });

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE);

  try {
    switch (action) {
      case 'send_test':
        return await sendTest(user.id, admin);
      default:
        return j(400, { error: 'unknown_action' });
    }
  } catch (e) {
    return j(500, { error: 'internal', detail: String(e) });
  }
});

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

function j(status: number, payload: unknown) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders },
  });
}
