import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../diary/providers/diary_providers.dart';
import '../../kakao/widgets/kakao_link_card.dart';
import '../../push/widgets/web_push_card.dart';
import '../../quotes/providers/quote_providers.dart';
import '../../reading/providers/book_providers.dart';
import '../../todo/providers/todo_providers.dart';
import '../providers/auth_providers.dart';
import '../services/supabase_service.dart';
import '../services/sync_manager.dart';
import '../services/sync_service.dart';
import 'auth_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _busy = false;
  String? _statusMsg;

  Future<void> _backup() async {
    setState(() {
      _busy = true;
      _statusMsg = null;
    });
    try {
      final stats = await SyncService.backupToCloud();
      setState(() => _statusMsg =
          '☁️ 백업 완료 — 총 ${stats.total}개 항목 (${_perKeyText(stats.perKey)})');
    } catch (e) {
      setState(() => _statusMsg = '백업 실패: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('클라우드에서 복원할까요?'),
        content: const Text(
          '현재 폰의 데이터를 클라우드의 데이터로 덮어씁니다.\n'
          '계속하시려면 "복원"을 누르세요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('복원'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() {
      _busy = true;
      _statusMsg = null;
    });
    try {
      final stats = await SyncService.restoreFromCloud();
      // 데이터 providers 무효화 → 새로 읽음
      ref.invalidate(booksProvider);
      ref.invalidate(quotesProvider);
      ref.invalidate(diariesProvider);
      ref.invalidate(todoCategoriesProvider);
      ref.invalidate(todoItemsProvider);
      // 순차 알림 설정 화면 등 pullCompleted 구독자에게 갱신 신호
      SyncManager.instance.notifyPullCompleted();
      setState(() => _statusMsg =
          '⬇️ 복원 완료 — 총 ${stats.total}개 항목 (${_perKeyText(stats.perKey)})');
    } catch (e) {
      setState(() => _statusMsg = '복원 실패: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _perKeyText(Map<String, int> m) {
    final labels = {
      'books': '책',
      'quotes': '문구',
      'diaries': '일기',
      'todo_categories': '카테고리',
      'todo_items': '할일',
    };
    return m.entries
        .where((e) => e.value > 0)
        .map((e) => '${labels[e.key] ?? e.key} ${e.value}')
        .join(', ');
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('로그아웃 하시겠습니까?'),
        content: const Text(
          '폰에 저장된 데이터는 그대로 유지됩니다.\n'
          '다음 로그인 후 "복원하기"로 클라우드 데이터를 받을 수 있습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await SupabaseService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('내 정보 · 백업')),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (user) {
          if (user == null) {
            return _LoggedOutView();
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor:
                          Theme.of(context).colorScheme.primary,
                      child: const Icon(Icons.person, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('로그인됨',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                          Text(
                            user.email ?? '(이메일 없음)',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const _AutoSyncCard(),
              const SizedBox(height: 12),
              const WebPushCard(),
              const SizedBox(height: 12),
              const KakaoLinkCard(),
              const SizedBox(height: 24),
              Text('수동 백업 / 복원',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                '평소엔 자동으로 동기화됩니다. 아래는 즉시 강제 실행용입니다.',
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _busy ? null : _backup,
                icon: const Icon(Icons.cloud_upload),
                label: const Text('지금 백업하기 (기기 → 클라우드)'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : _restore,
                icon: const Icon(Icons.cloud_download),
                label: const Text('클라우드에서 복원 (덮어쓰기)'),
              ),
              if (_statusMsg != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_statusMsg!,
                      style: const TextStyle(fontSize: 13)),
                ),
              ],
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text('로그아웃',
                    style: TextStyle(color: Colors.red)),
              ),
              const SizedBox(height: 12),
              Text(
                'ℹ️ 로그인 상태에서는 데이터가 자동으로 클라우드에 동기화됩니다.\n'
                '다른 기기·웹에서 같은 계정으로 로그인하면 데이터가 자동으로 불러와집니다.',
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade600, height: 1.5),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LoggedOutView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              '로그인 후 데이터를 클라우드에 백업할 수 있어요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AuthScreen()),
              ),
              icon: const Icon(Icons.login),
              label: const Text('로그인 / 회원가입'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AutoSyncCard extends StatelessWidget {
  const _AutoSyncCard();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SyncStatus>(
      valueListenable: SyncManager.instance.status,
      builder: (context, status, _) {
        return ValueListenableBuilder<DateTime?>(
          valueListenable: SyncManager.instance.lastSyncedAt,
          builder: (context, lastAt, __) {
            final (icon, color, text) = switch (status) {
              SyncStatus.syncing => (
                  Icons.cloud_sync,
                  Colors.blue,
                  '동기화 중...'
                ),
              SyncStatus.synced => (
                  Icons.cloud_done,
                  Colors.green,
                  lastAt != null
                      ? '동기화됨 · ${_time(lastAt)}'
                      : '동기화됨'
                ),
              SyncStatus.error => (
                  Icons.cloud_off,
                  Colors.red,
                  '동기화 오류 (다시 시도됩니다)'
                ),
              SyncStatus.offline => (
                  Icons.cloud_off,
                  Colors.grey,
                  '오프라인'
                ),
              SyncStatus.idle => (
                  Icons.cloud_queue,
                  Colors.grey,
                  '자동 동기화 켜짐'
                ),
            };
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(
                          color: color, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static String _time(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
