/// 비-웹 stub.
Future<bool> isPushSupported() async => false;
Future<String> currentPermission() async => 'unsupported';
Future<Map<String, String>?> subscribe(String vapidPublicBase64) async => null;
Future<bool> unsubscribe() async => false;
Future<bool> hasActiveSubscription() async => false;
