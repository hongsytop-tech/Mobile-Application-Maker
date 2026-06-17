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

  // applicationServerKey 는 padding 없는 base64url 문자열로 직접 전달.
  // (Uint8List 로 넘기면 dart:html 가 padded base64 문자열로 변환해서 오류 발생)
  final cleanKey = vapidPublicBase64
      .replaceAll('+', '-')
      .replaceAll('/', '_')
      .replaceAll('=', '');

  // 기존 구독이 있으면 VAPID 키 일치 여부 확인.
  // VAPID 키가 바뀌어 옛 구독을 재사용하면 푸시 서비스가 시그니처 불일치로
  // 메시지를 조용히 버리므로, 키가 다르면 폐기하고 재구독한다.
  html.PushSubscription? sub;
  try {
    sub = await pm.getSubscription();
  } catch (_) {}
  if (sub != null) {
    final mismatch = !_subscriptionMatchesKey(sub, cleanKey);
    if (mismatch) {
      try {
        await sub.unsubscribe();
      } catch (_) {}
      sub = null;
    }
  }
  sub ??= await pm.subscribe({
    'userVisibleOnly': true,
    'applicationServerKey': cleanKey,
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

bool _subscriptionMatchesKey(
    html.PushSubscription sub, String currentCleanKey) {
  try {
    final opts = sub.options;
    if (opts == null) return true; // 비교 불가능하면 그대로 사용
    final keyBuf = opts.applicationServerKey;
    if (keyBuf == null) return true;
    final existing = _bufToBase64Url(keyBuf);
    return existing == currentCleanKey;
  } catch (_) {
    return true;
  }
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
