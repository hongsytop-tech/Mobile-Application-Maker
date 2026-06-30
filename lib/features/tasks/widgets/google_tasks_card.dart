import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../memo/providers/memo_providers.dart';
import '../services/google_tasks_service.dart';
import '../services/tasks_import_store.dart';

/// 마이페이지의 "구글 Tasks 가져오기" 카드.
/// 운전 중 음성으로 Google Tasks 에 적어둔 일정을 메모로 가져온다.
class GoogleTasksCard extends ConsumerStatefulWidget {
  const GoogleTasksCard({super.key});

  @override
  ConsumerState<GoogleTasksCard> createState() => _GoogleTasksCardState();
}

class _GoogleTasksCardState extends ConsumerState<GoogleTasksCard> {
  bool _busy = false;
  String? _msg;

  @override
  void initState() {
    super.initState();
    // 버튼 탭 시 즉시 팝업이 뜨도록 GIS 스크립트를 미리 로드.
    if (GoogleTasksService.isConfigured) {
      GoogleTasksService.preload();
    }
  }

  Future<void> _import() async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      final tasks = await GoogleTasksService.fetchActiveTasks();
      final imported = await TasksImportStore.loadImportedIds();

      final fresh = tasks.where((t) => !imported.contains(t.id)).toList();
      if (fresh.isEmpty) {
        setState(() => _msg = tasks.isEmpty
            ? '가져올 Tasks 항목이 없어요.'
            : '새로 가져올 항목이 없어요. (이미 ${tasks.length}건 가져옴)');
        return;
      }

      final notifier = ref.read(memosProvider.notifier);
      for (final t in fresh) {
        // 제목 = Task 제목, 내용 = Task 메모(notes)
        await notifier.add(title: t.title, content: t.notes);
      }
      await TasksImportStore.addImportedIds(fresh.map((t) => t.id));

      setState(() => _msg = '✅ ${fresh.length}건을 메모로 가져왔어요.');
    } on GoogleTasksException catch (e) {
      setState(() => _msg = '가져오기 실패: ${e.message}');
    } catch (e) {
      setState(() => _msg = '가져오기 실패: $e');
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
                '구글 Tasks 가져오기',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
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
          FilledButton.icon(
            onPressed: (_busy || !configured) ? null : _import,
            icon: _busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download, size: 18),
            label: Text(_busy ? '가져오는 중...' : '지금 가져오기'),
          ),
        ],
      ),
    );
  }
}
