import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shell/menu_settings_provider.dart';
import '../../diary/providers/diary_providers.dart';
import '../../push/providers/notification_settings_providers.dart';
import '../../push/services/web_push_scheduler.dart';
import '../../push/services/web_push_service.dart';
import '../../quotes/models/quote.dart';
import '../../quotes/providers/quote_providers.dart';
import '../../quotes/services/quote_rotation_service.dart';
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
  StreamSubscription<DateTime>? _pullSub;

  @override
  void initState() {
    super.initState();
    // 백그라운드에서 복귀 시 자동 pull 이 끝나면 provider 무효화 + reschedule
    _pullSub = SyncManager.instance.pullCompleted.listen((_) {
      _refreshFromPulledData();
    });
  }

  @override
  void dispose() {
    _pullSub?.cancel();
    super.dispose();
  }

  void _refreshFromPulledData() {
    if (!mounted) return;
    ref.invalidate(booksProvider);
    ref.invalidate(quotesProvider);
    ref.invalidate(diariesProvider);
    ref.invalidate(todoCategoriesProvider);
    ref.invalidate(todoItemsProvider);
    // 알림 옵션 + 메뉴 설정도 다른 기기의 변경분을 즉시 반영
    ref.invalidate(notificationSettingsProvider);
    ref.invalidate(menuSettingsProvider);
    // 문구 순차 알림 + 개별 문구 + 할일 알림 재스케줄
    () async {
      try {
        final quotes = await ref.read(quotesProvider.future) as List<Quote>;
        await QuoteRotationService.reschedule(quotes);
        await WebPushScheduler.scheduleAll(quotes);
        final todos = await ref.read(todoItemsProvider.future);
        await WebPushScheduler.scheduleAllTodos(todos);
        final cats = await ref.read(todoCategoriesProvider.future);
        await WebPushScheduler.scheduleAllCategories(cats, todos);
      } catch (_) {}
    }();
  }

  Future<void> _onLogin() async {
    if (_pulling) return;
    _pulling = true;
    try {
      // pullOnLogin 이 끝나면 pullCompleted 스트림에서 _refreshFromPulledData 가 자동 실행됨
      await SyncManager.instance.pullOnLogin();
      // 웹 푸시 구독을 최신으로 유지 (cron 발송 시 no_subscription 방지)
      await WebPushService.ensureSubscribed();
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
