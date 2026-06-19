import 'dart:async';

/// 비-웹 stub.
class WebUpdateDetector {
  static Stream<bool> get available => const Stream<bool>.empty();
  static bool get hasUpdate => false;
  static void init() {}
  static Future<bool> checkForUpdate() async => false;
  static Future<void> apply() async {}
}
