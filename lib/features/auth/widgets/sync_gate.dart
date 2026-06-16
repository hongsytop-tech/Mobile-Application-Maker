import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../diary/providers/diary_providers.dart';
import '../../quotes/providers/quote_providers.dart';
import '../../reading/providers/book_providers.dart';
import '../../todo/providers/todo_providers.dart';
import '../providers/auth_providers.dart';
import '../services/sync_manager.dart';

/// 로그인 상태를 감시하여 로그인 직후 클라우드 데이터를 자동으로 내려받는다.
/// child를 그대로 렌더링하며, 동기화는 백그라운드로 진행.
class SyncGate extends ConsumerStatefulWidget {
  final Widget child;
  const SyncGate({super.key, required this.child});

  @override
  ConsumerState<SyncGate> createState() => _SyncGateState();
}

class _SyncGateState extends ConsumerState<SyncGate> {
  String? _lastUserId;
  bool _pulling = false;

  Future<void> _onLogin() async {
    if (_pulling) return;
    _pulling = true;
    try {
      final restored = await SyncManager.instance.pullOnLogin();
      if (restored != null && mounted) {
        // 클라우드 데이터로 로컬을 채웠으니 화면 갱신
        ref.invalidate(booksProvider);
        ref.invalidate(quotesProvider);
        ref.invalidate(diariesProvider);
        ref.invalidate(todoCategoriesProvider);
        ref.invalidate(todoItemsProvider);
      }
    } finally {
      _pulling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<User?>>(currentUserProvider, (prev, next) {
      final user = next.valueOrNull;
      final newId = user?.id;
      if (newId != null && newId != _lastUserId) {
        // 새 로그인 → pull
        _lastUserId = newId;
        _onLogin();
      } else if (newId == null && _lastUserId != null) {
        // 로그아웃
        _lastUserId = null;
        SyncManager.instance.reset();
      }
    });
    return widget.child;
  }
}
