import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/update_info.dart';
import '../services/update_service.dart';

final updateServiceProvider = Provider((_) => UpdateService());

/// 앱 시작 시 1회 실행. 명시적 새로고침은 ref.invalidate() 사용.
final updateCheckProvider = FutureProvider<UpdateInfo?>((ref) async {
  try {
    return await ref.read(updateServiceProvider).checkForUpdate();
  } catch (_) {
    return null; // 조용히 실패 (네트워크 오류 등)
  }
});
