import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';

/// 현재 로그인된 User (null이면 미로그인). Supabase Auth 이벤트에 반응.
final currentUserProvider = StreamProvider<User?>((ref) async* {
  if (!SupabaseService.isConfigured) {
    yield null;
    return;
  }
  yield SupabaseService.currentUser;
  await for (final state in SupabaseService.authChanges) {
    yield state.session?.user;
  }
});
