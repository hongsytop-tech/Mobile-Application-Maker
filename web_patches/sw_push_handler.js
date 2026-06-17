
// ---- Web Push handler ----
self.addEventListener('push', (event) => {
  let data = {};
  try { data = event.data ? event.data.json() : {}; } catch (e) {}
  const title = data.title || '알림';
  // SW 스코프(예: https://.../Mobile-Application-Maker/) 기준 절대경로로 아이콘 지정
  const iconUrl = new URL('icons/Icon-192.png', self.registration.scope).toString();
  const options = {
    body: data.body || '',
    icon: iconUrl,
    badge: iconUrl,
    tag: data.tag || 'default',
    data: { url: data.url || './' },
    requireInteraction: false,
  };
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
