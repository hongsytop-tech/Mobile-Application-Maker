// Google Tasks → 메모 자동 동기화 백엔드.
//
// actions:
//   - connect    : { code } → 인증코드를 refresh_token 으로 교환·저장 후 즉시 1회 동기화 (user JWT)
//   - status     : 연동 상태 반환 (user JWT)
//   - disconnect : 토큰 삭제 (user JWT)
//   - sync_all   : 모든 연동 사용자의 Google Tasks 를 확인해 새 항목을 메모로 추가
//                  (pg_cron 이 SCHEDULER_SECRET 으로 호출)
//
// Secrets (Supabase Dashboard → Edge Functions → Settings):
//   GOOGLE_CLIENT_ID      : 웹 OAuth 클라이언트 ID (GOOGLE_WEB_CLIENT_ID 와 동일)
//   GOOGLE_CLIENT_SECRET  : 웹 OAuth 클라이언트 시크릿 (필수 — Google Cloud Console 에서 발급)
//   SCHEDULER_SECRET      : sync_all cron 호출용 (web-push 와 동일 값)

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';

const CLIENT_ID = Deno.env.get('GOOGLE_CLIENT_ID') ??
  Deno.env.get('GOOGLE_WEB_CLIENT_ID') ?? '';
const CLIENT_SECRET = Deno.env.get('GOOGLE_CLIENT_SECRET') ?? '';
const SCHEDULER_SECRET = Deno.env.get('SCHEDULER_SECRET') ?? '';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const TOKEN_URL = 'https://oauth2.googleapis.com/token';
const TASKS_BASE = 'https://tasks.googleapis.com/tasks/v1';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

  let body: any;
  try {
    body = await req.json();
  } catch {
    return json({ error: 'invalid_json' }, 400);
  }
  const action = body.action as string;
  const admin = createClient(SUPABASE_URL, SERVICE_ROLE);

  // sync_all 은 SCHEDULER_SECRET 인증 (사용자 JWT 불필요)
  if (action === 'sync_all') {
    const auth = req.headers.get('Authorization') ?? '';
    if (!SCHEDULER_SECRET || auth !== `Bearer ${SCHEDULER_SECRET}`) {
      return json({ error: 'scheduler_unauthorized' }, 401);
    }
    try {
      return await syncAll(admin);
    } catch (e) {
      return json({ error: 'internal', detail: String(e) }, 500);
    }
  }

  // 그 외는 사용자 JWT 필요
  if (!CLIENT_ID || !CLIENT_SECRET) {
    return json({ error: 'server_misconfig', detail: 'GOOGLE_CLIENT_ID/SECRET missing' }, 500);
  }
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return json({ error: 'missing_authorization' }, 401);
  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user } } = await userClient.auth.getUser();
  if (!user) return json({ error: 'invalid_user' }, 401);

  try {
    switch (action) {
      case 'connect':
        return await connect(user.id, body.code, admin);
      case 'status':
        return await status(user.id, admin);
      case 'disconnect':
        return await disconnect(user.id, admin);
      default:
        return json({ error: 'unknown_action' }, 400);
    }
  } catch (e) {
    return json({ error: 'internal', detail: String(e) }, 500);
  }
});

/// 인증코드 → refresh_token 교환 후 저장 + 즉시 1회 동기화.
async function connect(userId: string, code: string, admin: any) {
  if (!code) return json({ error: 'missing_code' }, 400);

  const params = new URLSearchParams({
    grant_type: 'authorization_code',
    code,
    client_id: CLIENT_ID,
    client_secret: CLIENT_SECRET,
    // GIS 팝업(code) 플로우의 토큰 교환은 redirect_uri 로 'postmessage' 를 사용.
    redirect_uri: 'postmessage',
  });
  const res = await fetch(TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: params,
  });
  const data = await res.json();
  if (!res.ok) return json({ error: 'token_exchange_failed', detail: data }, 400);

  const refreshToken: string | undefined = data.refresh_token;
  if (!refreshToken) {
    // offline 접근/consent 가 없으면 refresh_token 이 안 옴 → 재동의 유도
    return json({ error: 'no_refresh_token' }, 400);
  }

  await admin.from('google_tasks_sync').upsert({
    user_id: userId,
    refresh_token: refreshToken,
    linked_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
    last_error: null,
  }, { onConflict: 'user_id' });

  // 방금 연동한 사용자 즉시 1회 동기화
  let imported = 0;
  try {
    const row = await loadRow(userId, admin);
    if (row) imported = await syncUser(admin, row, data.access_token as string);
  } catch (e) {
    // 동기화 실패해도 연동 자체는 성공으로 반환
    console.error('initial sync failed', e);
  }

  return json({ ok: true, linked: true, imported });
}

async function status(userId: string, admin: any) {
  const row = await loadRow(userId, admin);
  if (!row) return json({ linked: false });
  return json({
    linked: true,
    last_synced_at: row.last_synced_at,
    last_error: row.last_error,
    linked_at: row.linked_at,
  });
}

async function disconnect(userId: string, admin: any) {
  await admin.from('google_tasks_sync').delete().eq('user_id', userId);
  return json({ ok: true });
}

/// 모든 연동 사용자를 순회하며 동기화.
async function syncAll(admin: any) {
  const { data: rows, error } = await admin.from('google_tasks_sync').select('*');
  if (error) return json({ error: 'query_failed', detail: error.message }, 500);
  if (!rows || rows.length === 0) return json({ ok: true, users: 0, imported: 0 });

  let totalImported = 0;
  for (const row of rows) {
    try {
      const accessToken = await freshAccessToken(row.refresh_token);
      totalImported += await syncUser(admin, row, accessToken);
    } catch (e) {
      await admin.from('google_tasks_sync')
        .update({ last_error: String(e).slice(0, 500), updated_at: new Date().toISOString() })
        .eq('user_id', row.user_id);
    }
  }
  return json({ ok: true, users: rows.length, imported: totalImported });
}

/// 한 사용자의 미완료 Tasks 중 새 항목을 메모로 추가. 반환: 추가한 개수.
async function syncUser(admin: any, row: any, accessToken: string): Promise<number> {
  const already = new Set<string>(
    Array.isArray(row.imported_task_ids) ? row.imported_task_ids : [],
  );
  const tasks = await fetchActiveTasks(accessToken);
  const fresh = tasks.filter((t) => t.title && !already.has(t.id));
  if (fresh.length === 0) {
    await admin.from('google_tasks_sync')
      .update({ last_synced_at: new Date().toISOString(), last_error: null })
      .eq('user_id', row.user_id);
    return 0;
  }

  // user_data.memos 에 append (문자열화된 Memo JSON 배열)
  const { data: ud } = await admin.from('user_data')
    .select('memos').eq('user_id', row.user_id).maybeSingle();
  const memos: string[] = Array.isArray(ud?.memos) ? ud.memos : [];
  for (const t of fresh) {
    memos.push(makeMemoString(t.title, t.notes));
  }
  await admin.from('user_data').upsert({
    user_id: row.user_id,
    memos,
    updated_at: new Date().toISOString(),
  }, { onConflict: 'user_id' });

  const newIds = [...already, ...fresh.map((t) => t.id)];
  await admin.from('google_tasks_sync').update({
    imported_task_ids: newIds,
    last_synced_at: new Date().toISOString(),
    last_error: null,
    updated_at: new Date().toISOString(),
  }).eq('user_id', row.user_id);

  return fresh.length;
}

interface GTask { id: string; title: string; notes: string; }

async function fetchActiveTasks(accessToken: string): Promise<GTask[]> {
  const headers = { Authorization: `Bearer ${accessToken}` };
  const listRes = await fetch(`${TASKS_BASE}/users/@me/lists?maxResults=100`, { headers });
  if (!listRes.ok) throw new Error(`tasklists_failed ${listRes.status}`);
  const listJson = await listRes.json();
  const listIds: string[] = (listJson.items ?? []).map((e: any) => e.id);

  const out: GTask[] = [];
  for (const id of listIds) {
    const res = await fetch(
      `${TASKS_BASE}/lists/${id}/tasks?showCompleted=false&showHidden=false&maxResults=100`,
      { headers },
    );
    if (!res.ok) continue;
    const json = await res.json();
    for (const item of (json.items ?? [])) {
      if (item.status === 'completed') continue;
      const title = (item.title ?? '').trim();
      if (!title) continue;
      out.push({ id: item.id, title, notes: (item.notes ?? '').trim() });
    }
  }
  return out;
}

function makeMemoString(title: string, content: string): string {
  const now = new Date().toISOString();
  const memo = {
    id: crypto.randomUUID(),
    title,
    content,
    createdAt: now,
    updatedAt: now,
    // 작을수록 위 — 최근 항목이 위로 오도록 음수 타임스탬프
    order: -Date.now(),
  };
  return JSON.stringify(memo);
}

async function freshAccessToken(refreshToken: string): Promise<string> {
  const params = new URLSearchParams({
    grant_type: 'refresh_token',
    client_id: CLIENT_ID,
    client_secret: CLIENT_SECRET,
    refresh_token: refreshToken,
  });
  const res = await fetch(TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: params,
  });
  const data = await res.json();
  if (!res.ok) throw new Error(`refresh_failed: ${JSON.stringify(data)}`);
  return data.access_token as string;
}

async function loadRow(userId: string, admin: any): Promise<any | null> {
  const { data, error } = await admin.from('google_tasks_sync')
    .select('*').eq('user_id', userId).maybeSingle();
  if (error || !data) return null;
  return data;
}

function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders },
  });
}
