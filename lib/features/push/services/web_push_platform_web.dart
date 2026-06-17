import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

Future<bool> isPushSupported() async {
  final sw = html.window.navigator.serviceWorker;
  return sw != null;
}

Future<String> currentPermission() async {
  return html.Notification.permission ?? 'default';
}

/// 사용자 권한 요청 + Push 구독. 성공 시 {endpoint, p256dh, auth, user_agent} 반환.
Future<Map<String, String>?> subscribe(String vapidPublicBase64) async {
  if ((html.Notification.permission ?? 'default') != 'granted') {
    final perm = await html.Notification.requestPermission();
    if (perm != 'granted') return null;
  }
  final sw = html.window.navigator.serviceWorker;
  if (sw == null) return null;
  final reg = await sw.ready;
  final pm = reg.pushManager;
  if (pm == null) return null;

  // 기존 구독이 있으면 재사용. 없으면 새로 구독.
  html.PushSubscription? sub;
  try {
    sub = await pm.getSubscription();
  } catch (_) {}
  sub ??= await pm.subscribe({
    'userVisibleOnly': true,
    'applicationServerKey': _urlBase64ToUint8List(vapidPublicBase64),
  });

  final endpoint = sub.endpoint;
  final p256dhBuf = sub.getKey('p256dh');
  final authBuf = sub.getKey('auth');
  if (endpoint == null || p256dhBuf == null || authBuf == null) return null;

  return {
    'endpoint': endpoint,
    'p256dh': _bufToBase64Url(p256dhBuf),
    'auth': _bufToBase64Url(authBuf),
    'user_agent': html.window.navigator.userAgent,
  };
}

Future<bool> unsubscribe() async {
  final sw = html.window.navigator.serviceWorker;
  if (sw == null) return false;
  final reg = await sw.ready;
  final pm = reg.pushManager;
  if (pm == null) return false;
  final sub = await pm.getSubscription();
  if (sub == null) return true;
  return (await sub.unsubscribe()) == true;
}

Future<bool> hasActiveSubscription() async {
  final sw = html.window.navigator.serviceWorker;
  if (sw == null) return false;
  final reg = await sw.ready;
  final pm = reg.pushManager;
  if (pm == null) return false;
  final sub = await pm.getSubscription();
  return sub != null;
}

Uint8List _urlBase64ToUint8List(String b64) {
  final padding = '=' * ((4 - b64.length % 4) % 4);
  final padded = (b64 + padding).replaceAll('-', '+').replaceAll('_', '/');
  return base64Decode(padded);
}

String _bufToBase64Url(ByteBuffer buf) {
  final bytes = buf.asUint8List();
  return base64Url.encode(bytes).replaceAll('=', '');
}
