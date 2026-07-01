import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../memo/providers/memo_providers.dart';
import '../services/google_tasks_service.dart';
import '../services/tasks_importer.dart';

/// 마이페이지의 "구글 Tasks 연동" 카드.
/// - 자동 연동: 서버가 15분마다 Google Tasks 를 확인해 메모로 추가 (앱 안 열어도 동작)
/// - 지금 가져오기: 즉시 1회 가져오기 (클라이언트)
class GoogleTasksCard extends ConsumerStatefulWidget {
  const GoogleTasksCard({super.key});

  @override
  ConsumerState<GoogleTasksCard> createState() => _GoogleTasksCardState();
}

class _GoogleTasksCardState extends ConsumerState<GoogleTasksCard> {
  bool _busy = false;
  bool _checkingLink = true;
  bool _linked = false;
  String? _msg;

  @override
  void initState() {
    super.initState();
    if (GoogleTasksService.isConfigured) {
      GoogleTasksService.preload();
      _refreshLinkStatus();
    } else {
      _checkingLink = false;
    }
  }

  Future<void> _refreshLinkStatus() async {
    final linked = await GoogleTasksService.isAutoLinked();
    if (mounted) {
      setState(() {
        _linked = linked;
        _checkingLink = false;
      });
    }
  }

  /// 즉시 1회 가져오기 (클라이언트 토큰 방식).
  Future<void> _importNow() async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      await ref.read(memosProvider.future);
      final r = await TasksImporter.importNew(ref.read(memosProvider.notifier));
      setState(() {
        if (r.imported > 0) {
          _msg = '✅ ${r.imported}건을 메모로 가져왔어요.';
        } else if (r.total == 0) {
          _msg = '가져올 Tasks 항목이 없어요.';
        } else {
          _msg = '새로 가져올 항목이 없어요. (이미 ${r.total}건 가져옴)';
        }
      });
    } on GoogleTasksException catch (e) {
      setState(() => _msg = '가져오기 실패: ${e.message}');
    } catch (e) {
      setState(() => _msg = '가져오기 실패: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 자동 연동 켜기 (백엔드 refresh_token 저장).
  Future<void> _connectAuto() async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      final imported = await GoogleTasksService.connectAuto();
      // 연동 직후 서버가 즉시 넣은 메모를 반영하려면 클라우드에서 pull 필요.
      setState(() {
        _linked = true;
        _msg = imported > 0
            ? '✅ 자동 연동됨 — 방금 $imported건을 가져왔어요. 15분마다 자동으로 가져옵니다.'
            : '✅ 자동 연동됨 — 이제 15분마다 자동으로 가져옵니다.';
      });
    } on GoogleTasksException catch (e) {
      setState(() => _msg = '연동 실패: ${e.message}');
    } catch (e) {
      setState(() => _msg = '연동 실패: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnectAuto() async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      await GoogleTasksService.disconnectAuto();
      setState(() {
        _linked = false;
        _msg = '자동 연동을 해제했어요.';
      });
    } catch (e) {
      setState(() => _msg = '해제 실패: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final configured = GoogleTasksService.isConfigured;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.checklist_rtl, size: 18, color: Colors.grey.shade700),
              const SizedBox(width: 6),
              Text(
                '구글 Tasks 연동',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              if (_linked) ...[
                const SizedBox(width: 6),
                Icon(Icons.check_circle, size: 15, color: Colors.green.shade600),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '운전 중 "Hey Google, 할 일 추가해줘"로 적어둔 일정을 메모로 가져옵니다.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          if (!configured) ...[
            const SizedBox(height: 6),
            Text(
              '⚠️ 구글 클라이언트 ID(GOOGLE_WEB_CLIENT_ID)가 설정되지 않았습니다. '
              'GitHub Secret 등록 후 재배포가 필요합니다.',
              style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
            ),
          ],
          if (_linked) ...[
            const SizedBox(height: 6),
            Text('✅ 자동 연동됨 — 앱을 열지 않아도 15분마다 자동으로 가져옵니다.',
                style: TextStyle(fontSize: 11, color: primary)),
          ],
          if (_msg != null) ...[
            const SizedBox(height: 8),
            Text(
              _msg!,
              style: TextStyle(
                fontSize: 12,
                color: _msg!.startsWith('✅') ? primary : Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (_checkingLink)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(4),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (!_linked)
            FilledButton.icon(
              onPressed: (_busy || !configured) ? null : _connectAuto,
              icon: _busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sync, size: 18),
              label: Text(_busy ? '연동 중...' : '자동 연동 켜기'),
            )
          else
            OutlinedButton.icon(
              onPressed: _busy ? null : _disconnectAuto,
              icon: const Icon(Icons.link_off, size: 18),
              label: const Text('자동 연동 해제'),
            ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: (_busy || !configured) ? null : _importNow,
            icon: const Icon(Icons.download, size: 16),
            label: const Text('지금 즉시 가져오기'),
          ),
        ],
      ),
    );
  }
}
