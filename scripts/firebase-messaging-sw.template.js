// Generated with public Firebase WEB client configuration, never server keys.
// Register before the Firebase SDK so its default click handler cannot redirect.
self.addEventListener('notificationclick', (event) => {
  event.stopImmediatePropagation();
  event.notification.close();
  const data = event.notification.data?.FCM_MSG?.data ?? event.notification.data;
  const uuid = /^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$/;
  if (!data || !uuid.test(data.signal_id) || !uuid.test(data.event_id) ||
      !['SIGNAL_PUBLISHED', 'TP', 'SL', 'CANCELLED'].includes(data.type)) return;
  const target = new URL('/signals/' + data.signal_id, self.location.origin).href;
  // The page performs login + fresh server entitlement checks; no API/auth cache.
  event.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(async (windows) => {
    for (const client of windows) {
      if (new URL(client.url).origin === self.location.origin) {
        await client.navigate(target);
        return client.focus();
      }
    }
    return self.clients.openWindow(target);
  }));
});
importScripts('https://www.gstatic.com/firebasejs/12.3.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/12.3.0/firebase-messaging-compat.js');
firebase.initializeApp(__FIREBASE_WEB_CONFIG__);
firebase.messaging();
// FCM displays notification payloads. Do not call showNotification again.
