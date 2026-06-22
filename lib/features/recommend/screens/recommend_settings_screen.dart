import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../quotes/services/notification_service.dart';
import '../../todo/widgets/wheel_time_picker.dart';
import '../data/recommended_quotes.dart';
import '../models/recommend_settings.dart';
import '../providers/recommend_providers.dart';

/// "오늘의 추천 문구" 알림 설정 화면.
class RecommendSettingsScreen extends ConsumerWidget {
  const RecommendSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(quoteRecommendSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('오늘의 추천 문구')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (s) => _Body(settings: s),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  final RecommendSettings settings;
  const _Body({required this.settings});

  Future<void> _pickTime(BuildContext context, WidgetRef ref) async {
    final picked = await pickWheelTime(context,
        initialHour: settings.hour, initialMinute: settings.minute);
    if (picked == null) return;
    await _save(ref, settings.copyWith(hour: picked.hour, minute: picked.minute));
  }

  Future<void> _pickInterval(BuildContext context, WidgetRef ref) async {
    final picked = await pickWheelDuration(context,
        initialHours: settings.intervalHours,
        initialMinutes: settings.intervalMinutes);
    if (picked == null) return;
    await _save(
        ref,
        settings.copyWith(
            intervalHours: picked.hour, intervalMinutes: picked.minute));
  }

  Future<void> _save(WidgetRef ref, RecommendSettings s) async {
    if (s.enabled && NotificationService.supported) {
      await NotificationService.requestPermission();
    }
    await ref.read(quoteRecommendSettingsProvider.notifier).save(s);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = settings;
    final primary = Theme.of(context).colorScheme.primary;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Icon(Icons.schedule,
                        size: 16, color: Colors.grey.shade700),
                    const SizedBox(width: 6),
                    Text(
                      '발송 시각 설정',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: SegmentedButton<RecommendMode>(
                  segments: const [
                    ButtonSegment(
                      value: RecommendMode.daily,
                      label: Text('매일 지정 시각'),
                      icon: Icon(Icons.schedule),
                    ),
                    ButtonSegment(
                      value: RecommendMode.interval,
                      label: Text('반복 간격'),
                      icon: Icon(Icons.repeat),
                    ),
                  ],
                  selected: {s.mode},
                  showSelectedIcon: false,
                  onSelectionChanged: (set) =>
                      _save(ref, s.copyWith(mode: set.first)),
                ),
              ),
              if (s.mode == RecommendMode.daily)
                ListTile(
                  leading: const Icon(Icons.access_time),
                  title: const Text('알림 시각'),
                  trailing: Text(
                    '${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  onTap: () => _pickTime(context, ref),
                )
              else
                ListTile(
                  leading: const Icon(Icons.timelapse),
                  title: const Text('반복 간격'),
                  trailing: Text(
                    '${s.intervalHours}시간 ${s.intervalMinutes}분',
                    style: const TextStyle(fontSize: 16),
                  ),
                  onTap: () => _pickInterval(context, ref),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 12, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '알림 켜고 끄기는 마이페이지 → 추천 알림 에서.',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(Icons.auto_awesome, size: 16, color: primary),
            const SizedBox(width: 6),
            Text('추천 문구 미리보기',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700)),
            const Spacer(),
            Text('총 ${kRecommendedQuotes.length}개',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ],
        ),
        const SizedBox(height: 8),
        for (final q in kRecommendedQuotes.take(5))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(q,
                  style: const TextStyle(fontSize: 14, height: 1.5)),
            ),
          ),
        Text(
          '…외 ${kRecommendedQuotes.length - 5}개를 순서대로 돌아가며 보내드려요.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
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
