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
    ),
  );
}

class _WheelTimePicker extends StatefulWidget {
  final int initialHour;
  final int initialMinute;
  const _WheelTimePicker({
    required this.initialHour,
    required this.initialMinute,
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

  static String _two(int v) => v.toString().padLeft(2, '0');

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    _hourText.dispose();
    _minuteText.dispose();
    super.dispose();
  }

  void _setHour(int h, {bool moveWheel = true, bool setText = true}) {
    final v = h.clamp(0, 23);
    setState(() => _hour = v);
    if (moveWheel && _hourCtrl.hasClients && _hourCtrl.selectedItem != v) {
      _hourCtrl.jumpToItem(v);
    }
    if (setText && _hourText.text != _two(v)) {
      _hourText.text = _two(v);
    }
  }

  void _setMinute(int m, {bool moveWheel = true, bool setText = true}) {
    final v = m.clamp(0, 59);
    setState(() => _minute = v);
    if (moveWheel && _minuteCtrl.hasClients && _minuteCtrl.selectedItem != v) {
      _minuteCtrl.jumpToItem(v);
    }
    if (setText && _minuteText.text != _two(v)) {
      _minuteText.text = _two(v);
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
            Text('알림 시각',
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
                    onChanged: (v) => _setHour(v, moveWheel: false),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(':',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: primary)),
                  ),
                  _wheel(
                    controller: _minuteCtrl,
                    count: 60,
                    onChanged: (v) => _setMinute(v, moveWheel: false),
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
                  max: 23,
                  onChanged: (v) => _setHour(v, setText: false),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text(':', style: TextStyle(fontSize: 18)),
                ),
                _numField(
                  controller: _minuteText,
                  max: 59,
                  onChanged: (v) => _setMinute(v, setText: false),
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
                    onPressed: () => Navigator.pop(
                        context, (hour: _hour, minute: _minute)),
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
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return SizedBox(
      width: 56,
      child: TextField(
        controller: controller,
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
