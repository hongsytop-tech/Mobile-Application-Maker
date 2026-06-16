// Kakao 알림 연동 백엔드.
//
// actions:
//   - exchange   : { code, redirect_uri } → Kakao 토큰 교환 후 저장
//   - send_test  : 저장된 토큰으로 "나에게 보내기" 메모 전송 (테스트)
//   - unlink     : DB에서 토큰 제거 + Kakao unlink API 호출
//   - status     : 연동 상태 + scopes 반환
//
// Secrets (Supabase Dashboard → Edge Functions → Settings):
//   KAKAO_REST_API_KEY   : 필수
//   KAKAO_CLIENT_SECRET  : 선택 (Kakao 콘솔에서 ON 으로 설정한 경우만)
//
// 인증: 호출자의 Supabase JWT (Authorization: Bearer ...) 로 user_id 확인.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';

const KAKAO_REST_KEY = Deno.env.get('KAKAO_REST_API_KEY') ?? '';
const KAKAO_CLIENT_SECRET = Deno.env.get('KAKAO_CLIENT_SECRET') ?? '';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return json({ error: 'method_not_allowed' }, 405);
  }
  if (!KAKAO_REST_KEY) {
    return json({ error: 'server_misconfig', detail: 'KAKAO_REST_API_KEY missing' }, 500);
  }

  const auth = req.headers.get('Authorization');
  if (!auth) return json({ error: 'missing_authorization' }, 401);

  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: auth } },
  });
  const { data: { user } } = await userClient.auth.getUser();
  if (!user) return json({ error: 'invalid_user' }, 401);

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE);

  let body: any;
  try {
    body = await req.json();
  } catch {
    return json({ error: 'invalid_json' }, 400);
  }

  const action = body.action as string;
  try {
    switch (action) {
      case 'exchange':
        return await exchangeAndStore(user.id, body.code, body.redirect_uri, admin);
      case 'send_test':
        return await sendTest(user.id, admin);
      case 'unlink':
        return await unlink(user.id, admin);
      case 'status':
        return await status(user.id, admin);
      default:
        return json({ error: 'unknown_action' }, 400);
    }
  } catch (e) {
    return json({ error: 'internal', detail: String(e) }, 500);
  }
});

async function exchangeAndStore(
  userId: string,
  code: string,
  redirectUri: string,
  admin: any,
) {
  if (!code || !redirectUri) return json({ error: 'missing_params' }, 400);

  const params = new URLSearchParams({
    grant_type: 'authorization_code',
    client_id: KAKAO_REST_KEY,
    redirect_uri: redirectUri,
    code,
  });
  if (KAKAO_CLIENT_SECRET) params.set('client_secret', KAKAO_CLIENT_SECRET);

  const res = await fetch('https://kauth.kakao.com/oauth/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: params,
  });
  const data = await res.json();
  if (!res.ok) return json({ error: 'kakao_token_failed', detail: data }, 400);

  const accessToken: string = data.access_token;
  const refreshToken: string = data.refresh_token;
  const expiresIn: number = data.expires_in;
  const refreshExpiresIn: number | undefined = data.refresh_token_expires_in;
  const scope: string[] = (data.scope as string | undefined)?.split(' ') ?? [];

  // Kakao user id
  let kakaoUserId: number | null = null;
  try {
    const meRes = await fetch('https://kapi.kakao.com/v2/user/me', {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    const me = await meRes.json();
    if (meRes.ok) kakaoUserId = me.id ?? null;
  } catch (_) {}

  const expiresAt = new Date(Date.now() + expiresIn * 1000).toISOString();
  const refreshExpiresAt = refreshExpiresIn
    ? new Date(Date.now() + refreshExpiresIn * 1000).toISOString()
    : null;

  const { error } = await admin.from('kakao_tokens').upsert({
    user_id: userId,
    access_token: accessToken,
    refresh_token: refreshToken,
    expires_at: expiresAt,
    refresh_token_expires_at: refreshExpiresAt,
    scopes: scope,
    kakao_user_id: kakaoUserId,
    linked_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  });
  if (error) return json({ error: 'db_upsert_failed', detail: error.message }, 500);

  return json({ ok: true, scopes: scope, has_talk_message: scope.includes('talk_message') });
}

async function sendTest(userId: string, admin: any) {
  const tokens = await loadTokens(userId, admin);
  if (!tokens) return json({ error: 'not_linked' }, 400);

  const accessToken = await ensureFreshToken(tokens, admin);

  const template = {
    object_type: 'text',
    text: '🎉 카카오톡 알림 연동 완료\n\n앞으로 문구·할일 알림을 카카오톡으로 받으실 수 있어요.',
    link: {
      web_url: 'https://hongsytop-tech.github.io/Mobile-Application-Maker/',
      mobile_web_url: 'https://hongsytop-tech.github.io/Mobile-Application-Maker/',
    },
    button_title: '앱 열기',
  };

  const res = await fetch('https://kapi.kakao.com/v2/api/talk/memo/default/send', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({ template_object: JSON.stringify(template) }),
  });
  const data = await res.json();
  if (!res.ok) return json({ error: 'send_failed', detail: data }, 400);
  return json({ ok: true });
}

async function unlink(userId: string, admin: any) {
  const tokens = await loadTokens(userId, admin);
  if (tokens) {
    try {
      const accessToken = await ensureFreshToken(tokens, admin);
      // 카카오 unlink (앱 연결 해제) — 실패해도 DB 는 제거
      await fetch('https://kapi.kakao.com/v1/user/unlink', {
        method: 'POST',
        headers: { Authorization: `Bearer ${accessToken}` },
      });
    } catch (_) {}
  }
  await admin.from('kakao_tokens').delete().eq('user_id', userId);
  return json({ ok: true });
}

async function status(userId: string, admin: any) {
  const tokens = await loadTokens(userId, admin);
  if (!tokens) return json({ linked: false });
  return json({
    linked: true,
    scopes: tokens.scopes ?? [],
    has_talk_message: (tokens.scopes ?? []).includes('talk_message'),
    linked_at: tokens.linked_at,
    kakao_user_id: tokens.kakao_user_id,
  });
}

async function loadTokens(userId: string, admin: any): Promise<any | null> {
  const { data, error } = await admin
    .from('kakao_tokens')
    .select('*')
    .eq('user_id', userId)
    .maybeSingle();
  if (error || !data) return null;
  return data;
}

async function ensureFreshToken(tokens: any, admin: any): Promise<string> {
  const expiresAt = new Date(tokens.expires_at).getTime();
  if (expiresAt > Date.now() + 60_000) return tokens.access_token;

  const params = new URLSearchParams({
    grant_type: 'refresh_token',
    client_id: KAKAO_REST_KEY,
    refresh_token: tokens.refresh_token,
  });
  if (KAKAO_CLIENT_SECRET) params.set('client_secret', KAKAO_CLIENT_SECRET);

  const res = await fetch('https://kauth.kakao.com/oauth/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: params,
  });
  const data = await res.json();
  if (!res.ok) throw new Error(`refresh_failed: ${JSON.stringify(data)}`);

  const newAccess: string = data.access_token;
  const newExpiresIn: number = data.expires_in;
  // refresh_token 은 만료가 임박할 때만 갱신값이 옴
  const newRefresh: string = data.refresh_token ?? tokens.refresh_token;
  const newRefreshExpiresIn: number | undefined = data.refresh_token_expires_in;

  const newExpiresAt = new Date(Date.now() + newExpiresIn * 1000).toISOString();
  const newRefreshExpiresAt = newRefreshExpiresIn
    ? new Date(Date.now() + newRefreshExpiresIn * 1000).toISOString()
    : tokens.refresh_token_expires_at;

  await admin
    .from('kakao_tokens')
    .update({
      access_token: newAccess,
      refresh_token: newRefresh,
      expires_at: newExpiresAt,
      refresh_token_expires_at: newRefreshExpiresAt,
      updated_at: new Date().toISOString(),
    })
    .eq('user_id', tokens.user_id);

  return newAccess;
}

function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders },
  });
}
