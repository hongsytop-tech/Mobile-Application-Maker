import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/services/sync_manager.dart';
import '../../todo/widgets/wheel_time_picker.dart';
import '../providers/quote_providers.dart';
import '../services/notification_service.dart';
import '../services/quote_rotation_service.dart';

class QuoteRotationSettingsScreen extends ConsumerStatefulWidget {
  const QuoteRotationSettingsScreen({super.key});

  @override
  ConsumerState<QuoteRotationSettingsScreen> createState() =>
      _QuoteRotationSettingsScreenState();
}

class _QuoteRotationSettingsScreenState
    extends ConsumerState<QuoteRotationSettingsScreen> {
  /// 디스크에 저장된 마지막 상태
  QuoteRotationSettings _saved = const QuoteRotationSettings();

  /// 현재 화면에서 편집 중인 상태 (저장 버튼 누르기 전)
  QuoteRotationSettings _draft = const QuoteRotationSettings();

  bool _loaded = false;
  bool _saving = false;
  StreamSubscription<DateTime>? _pullSub;

  bool get _dirty =>
      _draft.enabled != _saved.enabled ||
      _draft.mode != _saved.mode ||
      _draft.hour != _saved.hour ||
      _draft.minute != _saved.minute ||
      _draft.intervalHours != _saved.intervalHours ||
      _draft.intervalMinutes != _saved.intervalMinutes;

  @override
  void initState() {
    super.initState();
    _reloadFromDisk();
    // 다른 기기 변경분이 pull 로 도착하면 화면도 즉시 갱신
    _pullSub = SyncManager.instance.pullCompleted.listen((_) => _reloadFromDisk());
  }

  @override
  void dispose() {
    _pullSub?.cancel();
    super.dispose();
  }

  Future<void> _reloadFromDisk() async {
    final s = await QuoteRotationService.load();
    if (!mounted) return;
    setState(() {
      _saved = s;
      // pull 로 디스크가 갱신된 경우 → 항상 draft 도 갱신.
      // 사용자가 편집 중이라도 다른 기기 변경분이 명확히 반영되는 게 우선.
      _draft = s;
      _loaded = true;
    });
  }

  void _patch(QuoteRotationSettings next) {
    setState(() => _draft = next);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      if (_draft.enabled && NotificationService.supported) {
        await NotificationService.requestPermission();
      }
      await QuoteRotationService.save(_draft);
      final quotes = ref.read(quotesProvider).value ?? const [];
      // 설정 변경 → 옛 스케줄 모두 제거 후 새로 등록
      await QuoteRotationService.reschedule(quotes, cleanFirst: true);
      if (mounted) {
        setState(() => _saved = _draft);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('순차 알림 설정 저장 완료')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _discard() {
    setState(() => _draft = _saved);
  }

  Future<bool> _confirmLeaveIfDirty() async {
    if (!_dirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('저장하지 않은 변경이 있어요'),
        content: const Text('변경을 버리고 나갈까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('계속 편집'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('버리고 나가기'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _pickTime() async {
    final picked = await pickWheelTime(
      context,
      initialHour: _draft.hour,
      initialMinute: _draft.minute,
    );
    if (picked != null) {
      _patch(_draft.copyWith(hour: picked.hour, minute: picked.minute));
    }
  }

  @override
  Widget build(BuildContext context) {
    final quotes = ref.watch(quotesProvider).value ?? const [];
    if (!_loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: !_dirty,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final ok = await _confirmLeaveIfDirty();
        if (ok && mounted) {
          setState(() => _draft = _saved);
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('문구 순차 알림')),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _dirty
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.06)
                  : Colors.grey.shade50,
              border: Border(
                top: BorderSide(
                  color: _dirty
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.4)
                      : Colors.grey.shade300,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      _dirty ? Icons.edit_note : Icons.check_circle_outline,
                      size: 18,
                      color: _dirty
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _dirty ? '변경 사항이 있습니다' : '저장된 상태입니다',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _dirty
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: (_dirty && !_saving) ? _discard : null,
                        child: const Text('취소'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: (_dirty && !_saving) ? _save : null,
                        icon: _saving
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white),
                              )
                            : const Icon(Icons.save, size: 18),
                        label: const Text('설정 저장'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          children: [
            Icon(
              Icons.campaign,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 8),
            const Text(
              '저장한 문구들이 지정한 주기마다\n순환하면서 큰 알림으로 표시됩니다.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SwitchListTile(
                title: const Text('순차 알림 사용'),
                subtitle: Text(
                  quotes.isEmpty
                      ? '먼저 문구를 1개 이상 추가해 주세요'
                      : '총 ${quotes.length}개 문구가 순환됩니다',
                ),
                value: _draft.enabled,
                onChanged: quotes.isEmpty
                    ? null
                    : (v) => _patch(_draft.copyWith(enabled: v)),
              ),
            ),
            if (_draft.enabled) ...[
              const SizedBox(height: 20),
              Text('반복 주기',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<RotationMode>(
                segments: const [
                  ButtonSegment(
                    value: RotationMode.dailyAtTime,
                    label: Text('매일 지정 시각'),
                    icon: Icon(Icons.schedule),
                  ),
                  ButtonSegment(
                    value: RotationMode.interval,
                    label: Text('반복 간격'),
                    icon: Icon(Icons.repeat),
                  ),
                ],
                selected: {_draft.mode},
                showSelectedIcon: false,
                onSelectionChanged: (s) =>
                    _patch(_draft.copyWith(mode: s.first)),
              ),
              const SizedBox(height: 16),
              if (_draft.mode == RotationMode.dailyAtTime)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.access_time),
                    title: const Text('알림 시각'),
                    trailing: Text(
                      '${_draft.hour.toString().padLeft(2, '0')}:${_draft.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    onTap: _pickTime,
                  ),
                )
              else
                _IntervalPicker(
                  hours: _draft.intervalHours,
                  minutes: _draft.intervalMinutes,
                  onChanged: (h, m) => _patch(
                    _draft.copyWith(
                        intervalHours: h, intervalMinutes: m),
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                _dirty ? '다음 예정 알림 (저장 후 적용)' : '다음 예정 알림',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _UpcomingList(settings: _draft, quotes: quotes),
            ],
            if (!NotificationService.supported) ...[
              const SizedBox(height: 16),
              Text(
                'ℹ️ 웹에서는 알림이 동작하지 않습니다. 모바일 앱에서 사용해 주세요.',
                style:
                    TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
            ],
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

class _IntervalPicker extends StatelessWidget {
  final int hours;
  final int minutes;
  final void Function(int h, int m) onChanged;
  const _IntervalPicker({
    required this.hours,
    required this.minutes,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () async {
              final picked = await pickWheelDuration(
                context,
                initialHours: hours,
                initialMinutes: minutes,
              );
              if (picked != null) onChanged(picked.hour, picked.minute);
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timelapse, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    '${hours}시간 ${minutes}분마다',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Icon(Icons.expand_more, color: Colors.grey.shade500),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hours * 60 + minutes < 1
                ? '간격을 1분 이상으로 설정해 주세요'
                : '${hours > 0 ? "${hours}시간 " : ""}${minutes > 0 ? "${minutes}분" : ""}마다 알림',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '💡 너무 짧은 간격은 배터리 소모가 큽니다.',
            style:
                TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;
  const _StepRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.step = 1,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: value > min
                    ? () => onChanged((value - step).clamp(min, max))
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$value',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: value < max
                    ? () => onChanged((value + step).clamp(min, max))
                    : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UpcomingList extends StatelessWidget {
  final QuoteRotationSettings settings;
  final List quotes;
  const _UpcomingList({required this.settings, required this.quotes});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('MM.dd (E) HH:mm', 'ko_KR');
    final upcoming = QuoteRotationService.preview(
      quotes: List.from(quotes),
      settings: settings,
      count: 6,
    );
    if (upcoming.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          '예정된 알림이 없습니다.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: upcoming.map((e) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 90,
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    df.format(e.when),
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: Text(
                    e.text,
                    style: const TextStyle(fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
