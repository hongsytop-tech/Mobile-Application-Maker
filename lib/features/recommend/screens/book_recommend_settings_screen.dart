import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../quotes/services/notification_service.dart';
import '../../todo/widgets/wheel_time_picker.dart';
import '../data/recommended_books.dart';
import '../models/recommend_settings.dart';
import '../providers/recommend_providers.dart';
import '../services/book_recommend_service.dart';
import 'book_recommend_detail_screen.dart';

/// "오늘의 추천 책" 알림 설정.
class BookRecommendSettingsScreen extends ConsumerWidget {
  const BookRecommendSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bookRecommendSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('오늘의 추천 책')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (s) => _Body(settings: s),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  final BookRecommendSettings settings;
  const _Body({required this.settings});

  Future<void> _save(WidgetRef ref, BookRecommendSettings s) async {
    if (s.enabled && NotificationService.supported) {
      await NotificationService.requestPermission();
    }
    await ref.read(bookRecommendSettingsProvider.notifier).save(s);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = settings;
    final primary = Theme.of(context).colorScheme.primary;
    final today = BookRecommendService.todaysBook;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 오늘의 책 미리보기 카드
        Material(
          color: primary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BookRecommendDetailScreen(book: today),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primary.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_stories, color: primary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('오늘의 책',
                            style: TextStyle(
                                fontSize: 12, color: primary)),
                        const SizedBox(height: 2),
                        Text(today.title,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text(today.author,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey.shade400),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('추천 책 알림 받기'),
                subtitle: const Text('매일 추천 책 한 권을 알려드려요'),
                value: s.enabled,
                onChanged: (v) => _save(ref, s.copyWith(enabled: v)),
              ),
              if (s.enabled) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.access_time),
                  title: const Text('알림 시각'),
                  trailing: Text(
                    '${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  onTap: () async {
                    final picked = await pickWheelTime(context,
                        initialHour: s.hour, initialMinute: s.minute);
                    if (picked != null) {
                      await _save(ref,
                          s.copyWith(hour: picked.hour, minute: picked.minute));
                    }
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(Icons.menu_book, size: 16, color: primary),
            const SizedBox(width: 6),
            Text('추천 책 목록',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700)),
            const Spacer(),
            Text('총 ${kRecommendedBooks.length}권',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ],
        ),
        const SizedBox(height: 8),
        for (final b in kRecommendedBooks)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BookRecommendDetailScreen(book: b),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(b.title,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            Text(b.author,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          size: 18, color: Colors.grey.shade400),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (!NotificationService.supported) ...[
          const SizedBox(height: 12),
          Text(
            'ℹ️ 웹(PWA)을 홈 화면에 추가한 뒤 알림을 켜면 시스템 알림으로 옵니다.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ],
    );
  }
}
