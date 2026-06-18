import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 위아래 스크롤 휠로 시/분을 선택하고, 직접 숫자 입력도 가능한 시간 선택기.
/// 반환: (hour, minute) 또는 취소 시 null.
Future<({int hour, int minute})?> pickWheelTime(
  BuildContext context, {
  required int initialHour,
  required int initialMinute,
}) {
  return showModalBottomSheet<({int hour, int minute})>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _WheelTimePicker(
      initialHour: initialHour,
      initialMinute: initialMinute,
      title: '알림 시각',
      duration: false,
    ),
  );
}

/// 반복 간격(시간/분) 선택. 반환: (hours, minutes) 또는 취소 시 null.
Future<({int hour, int minute})?> pickWheelDuration(
  BuildContext context, {
  required int initialHours,
  required int initialMinutes,
}) {
  return showModalBottomSheet<({int hour, int minute})>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _WheelTimePicker(
      initialHour: initialHours,
      initialMinute: initialMinutes,
      title: '반복 간격',
      duration: true,
    ),
  );
}

class _WheelTimePicker extends StatefulWidget {
  final int initialHour;
  final int initialMinute;
  final String title;
  final bool duration;
  const _WheelTimePicker({
    required this.initialHour,
    required this.initialMinute,
    required this.title,
    required this.duration,
  });

  @override
  State<_WheelTimePicker> createState() => _WheelTimePickerState();
}

class _WheelTimePickerState extends State<_WheelTimePicker> {
  late int _hour = widget.initialHour.clamp(0, 23);
  late int _minute = widget.initialMinute.clamp(0, 59);

  late final FixedExtentScrollController _hourCtrl =
      FixedExtentScrollController(initialItem: _hour);
  late final FixedExtentScrollController _minuteCtrl =
      FixedExtentScrollController(initialItem: _minute);

  late final TextEditingController _hourText =
      TextEditingController(text: _two(_hour));
  late final TextEditingController _minuteText =
      TextEditingController(text: _two(_minute));

  // 텍스트 필드 포커스 추적 — 사용자가 입력 중일 때 휠이 텍스트를 덮어쓰지 않도록.
  final FocusNode _hourFocus = FocusNode();
  final FocusNode _minuteFocus = FocusNode();

  static String _two(int v) => v.toString().padLeft(2, '0');

  @override
  void initState() {
    super.initState();
    // 입력 끝나고 포커스를 잃으면 두 자리로 정리
    _hourFocus.addListener(() {
      if (!_hourFocus.hasFocus) _hourText.text = _two(_hour);
    });
    _minuteFocus.addListener(() {
      if (!_minuteFocus.hasFocus) _minuteText.text = _two(_minute);
    });
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    _hourText.dispose();
    _minuteText.dispose();
    _hourFocus.dispose();
    _minuteFocus.dispose();
    super.dispose();
  }

  /// 휠 스크롤로 변경됨 → 값 + 텍스트 갱신 (단, 입력 중이면 텍스트는 건드리지 않음)
  void _onHourWheel(int v) {
    setState(() => _hour = v.clamp(0, 23));
    if (!_hourFocus.hasFocus) _hourText.text = _two(_hour);
  }

  void _onMinuteWheel(int v) {
    setState(() => _minute = v.clamp(0, 59));
    if (!_minuteFocus.hasFocus) _minuteText.text = _two(_minute);
  }

  /// 텍스트 입력으로 변경됨 → 값 + 휠만 갱신 (텍스트는 그대로 두어 "14" 입력 보존)
  void _onHourText(int v) {
    final c = v.clamp(0, 23);
    setState(() => _hour = c);
    if (_hourCtrl.hasClients && _hourCtrl.selectedItem != c) {
      _hourCtrl.jumpToItem(c);
    }
  }

  void _onMinuteText(int v) {
    final c = v.clamp(0, 59);
    setState(() => _minute = c);
    if (_minuteCtrl.hasClients && _minuteCtrl.selectedItem != c) {
      _minuteCtrl.jumpToItem(c);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(widget.title,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            // 휠
            SizedBox(
              height: 160,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _wheel(
                    controller: _hourCtrl,
                    count: 24,
                    onChanged: _onHourWheel,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(widget.duration ? '시간' : ':',
                        style: TextStyle(
                            fontSize: widget.duration ? 16 : 28,
                            fontWeight: FontWeight.bold,
                            color: primary)),
                  ),
                  _wheel(
                    controller: _minuteCtrl,
                    count: 60,
                    onChanged: _onMinuteWheel,
                  ),
                  if (widget.duration)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text('분',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: primary)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 직접 입력
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text('직접 입력  ',
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
                _numField(
                  controller: _hourText,
                  focusNode: _hourFocus,
                  max: 23,
                  onChanged: _onHourText,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text(':', style: TextStyle(fontSize: 18)),
                ),
                _numField(
                  controller: _minuteText,
                  focusNode: _minuteFocus,
                  max: 59,
                  onChanged: _onMinuteText,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      // 확인 시 입력칸 텍스트를 다시 파싱 (한자리 입력도 확실히 반영)
                      final h = int.tryParse(_hourText.text.trim());
                      final m = int.tryParse(_minuteText.text.trim());
                      final hour = (h ?? _hour).clamp(0, 23);
                      final minute = (m ?? _minute).clamp(0, 59);
                      Navigator.pop(context, (hour: hour, minute: minute));
                    },
                    child: const Text('확인'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int count,
    required ValueChanged<int> onChanged,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: 64,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: 44,
        perspective: 0.005,
        diameterRatio: 1.4,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: onChanged,
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: count,
          builder: (context, i) => Center(
            child: Text(
              _two(i),
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: primary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _numField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return SizedBox(
      width: 56,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 2,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          counterText: '',
          isDense: true,
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(vertical: 8),
        ),
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        onChanged: (s) {
          final v = int.tryParse(s);
          if (v == null) return;
          if (v > max) return;
          onChanged(v);
        },
      ),
    );
  }
}
