
// ---- Web Push handler ----
self.addEventListener('push', (event) => {
  let data = {};
  try { data = event.data ? event.data.json() : {}; } catch (e) {}
  const title = data.title || '알림';
  // SW 스코프(예: https://.../Mobile-Application-Maker/) 기준 절대경로로 아이콘 지정
  const iconUrl = new URL('icons/Icon-192.png', self.registration.scope).toString();
  // 베지(상태바 작은 아이콘)는 단색 실루엣 PNG. deploy-web.yml 에서 ImageMagick 으로 생성.
  const badgeUrl = new URL('icons/notification_badge.png', self.registration.scope).toString();
  const options = {
    body: data.body || '',
    icon: iconUrl,
    badge: badgeUrl,
    tag: data.tag || 'default',
    data: { url: data.url || './' },
    requireInteraction: false,
  };
  // 진동: 서버가 vibrate 패턴을 보내준 경우 그대로 사용.
  // 무진동은 [0] (0ms 1회) — 길이 0 인 빈 배열은 안드로이드 크롬에서 알림 자체 차단됨.
  if (Array.isArray(data.vibrate) && data.vibrate.length > 0) {
    options.vibrate = data.vibrate;
  }
  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const url = (event.notification.data && event.notification.data.url) || './';
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const c of clientList) {
        if ('focus' in c) return c.focus();
      }
      if (self.clients.openWindow) return self.clients.openWindow(url);
    })
  );
});
