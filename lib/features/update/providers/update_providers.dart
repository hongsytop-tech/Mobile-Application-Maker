import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/update_info.dart';
import '../services/update_service.dart';

final updateServiceProvider = Provider((_) => UpdateService());

/// 앱 시작 시 1회 실행. 명시적 새로고침은 ref.invalidate() 사용.
/// 진단을 위해 에러를 그대로 전파한다 (배너에서 메시지 표시).
final updateCheckProvider = FutureProvider<UpdateInfo?>((ref) async {
  return ref.read(updateServiceProvider).checkForUpdate();
});
