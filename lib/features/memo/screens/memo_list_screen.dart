import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/services/sync_manager.dart';
import '../models/memo.dart';
import '../providers/memo_providers.dart';
import '../services/memo_url_helper.dart'
    if (dart.library.html) '../services/memo_url_helper_web.dart';
import 'memo_edit_screen.dart';

class MemoListScreen extends ConsumerWidget {
  const MemoListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncMemos = ref.watch(memosProvider);
    final sorted = ref.watch(sortedMemosProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('메모')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MemoEditScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('새 메모'),
      ),
      body: RefreshIndicator(
        onRefresh: () => SyncManager.instance.pullOnLogin(),
        child: asyncMemos.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('오류: $e')),
          data: (_) {
            if (sorted.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sticky_note_2_outlined,
                                size: 56, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              '아직 메모가 없어요.\n오른쪽 아래에서 새 메모를 추가해 보세요.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              itemCount: sorted.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _MemoCard(memo: sorted[i]),
            );
          },
        ),
      ),
    );
  }
}

class _MemoCard extends ConsumerWidget {
  final Memo memo;
  const _MemoCard({required this.memo});

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('이 메모를 삭제할까요?'),
        content: Text(memo.title.isEmpty ? '(제목 없음)' : memo.title,
            style: const TextStyle(fontSize: 13, color: Colors.grey)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                foregroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(memosProvider.notifier).remove(memo.id);
    }
  }

  Future<void> _showShortcut(BuildContext context) async {
    final url = buildMemoShareUrl(memo.id);
    final title = memo.title.trim().isEmpty ? '(제목 없음)' : memo.title;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('홈 화면 바로가기'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('"$title" 메모를 바로 열 수 있는 URL입니다.',
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SelectableText(
                url,
                style: const TextStyle(
                    fontSize: 11, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '홈 화면에 추가하는 방법',
              style:
                  TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              '1. 아래 "URL 복사" 버튼을 누르세요\n'
              '2. 모바일 브라우저(Safari/Chrome)에서 새 탭을 열고 주소창에 붙여넣기\n'
              '3. 브라우저 메뉴 → "홈 화면에 추가" 선택\n'
              '4. 홈 화면 아이콘을 누르면 이 메모가 바로 열립니다',
              style: TextStyle(fontSize: 12, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('닫기')),
          FilledButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('URL 복사'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('URL이 복사되었어요'),
                      duration: Duration(seconds: 2)),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final df = DateFormat('yyyy.MM.dd HH:mm');
    // 줄바꿈은 유지하고, 각 줄 내부의 연속 공백/탭만 압축. 앞뒤 공백/빈 줄만 정리.
    final preview = memo.content
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'[ \t]+'), ' ').trimRight())
        .join('\n')
        .trim();
    final title =
        memo.title.trim().isEmpty ? '(제목 없음)' : memo.title;

    return Material(
      color: Colors.white,
      elevation: 0,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MemoEditScreen(memo: memo)),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: memo.title.trim().isEmpty
                            ? Colors.grey
                            : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () => _showShortcut(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.add_to_home_screen_outlined,
                          size: 20, color: Colors.blue.shade400),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => _confirmDelete(context, ref),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.delete_outline,
                          size: 20, color: Colors.red.shade400),
                    ),
                  ),
                ],
              ),
              if (preview.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  preview,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time,
                      size: 12, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    df.format(memo.updatedAt),
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
