import 'dart:async';

/// 비-웹 stub.
class WebUpdateDetector {
  static Stream<bool> get available => const Stream<bool>.empty();
  static void init() {}
  static Future<void> apply() async {}
}
