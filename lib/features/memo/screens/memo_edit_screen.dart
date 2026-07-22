import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/memo.dart';
import '../providers/memo_providers.dart';
import '../services/memo_markup.dart';

class MemoEditScreen extends ConsumerStatefulWidget {
  final Memo? memo;

  /// 새 메모를 이 폴더 소속으로 만들 때 지정.
  final String? folderId;
  const MemoEditScreen({super.key, this.memo, this.folderId});

  @override
  ConsumerState<MemoEditScreen> createState() => _MemoEditScreenState();
}

class _MemoEditScreenState extends ConsumerState<MemoEditScreen>
    with WidgetsBindingObserver {
  late final TextEditingController _titleCtrl;
  late final RichMemoEditingController _contentCtrl;
  final FocusNode _contentFocus = FocusNode();
  bool _dirty = false;
  bool _saving = false;

  /// 처음 저장 시 생성된 메모. 이후 자동저장은 이 ID 에 update 로 들어가야
  /// "자동저장이 일어날 때마다 새 메모가 만들어지는" 버그를 막을 수 있다.
  Memo? _createdMemo;

  bool get _isNew => widget.memo == null && _createdMemo == null;
  Memo? get _currentExisting => widget.memo ?? _createdMemo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _titleCtrl = TextEditingController(text: widget.memo?.title ?? '');
    _contentCtrl = RichMemoEditingController(text: widget.memo?.content ?? '');
    _titleCtrl.addListener(_markDirty);
    _contentCtrl.addListener(_markDirty);
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _contentFocus.dispose();
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 백그라운드 진입 시 자동 저장
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      if (_dirty) _save(silent: true);
    }
  }

  Future<void> _save({bool silent = false}) async {
    if (_saving) return;
    _saving = true;
    try {
      final title = _titleCtrl.text.trim();
      final content = _contentCtrl.text;
      final notifier = ref.read(memosProvider.notifier);
      final existing = _currentExisting;
      if (existing == null) {
        // 진짜 신규 — 첫 저장. 만들어진 메모를 기억해 이후 자동저장은 update 로.
        if (title.isEmpty && content.isEmpty) return;
        final created = await notifier.add(
            title: title, content: content, folderId: widget.folderId);
        _createdMemo = created;
      } else {
        await notifier.save(existing.copyWith(
          title: title,
          content: content,
          updatedAt: DateTime.now(),
        ));
      }
      if (mounted) {
        setState(() => _dirty = false);
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('저장됨'),
                duration: Duration(milliseconds: 800)),
          );
        }
      }
    } finally {
      _saving = false;
    }
  }

  /// 복사 — 선택 영역이 있으면 선택분, 없으면 내용 전체를 클립보드로.
  /// (CanvasKit 모바일 웹에서 선택 툴바가 안 떠 복사가 안 되던 문제 우회)
  Future<void> _copyContent() async {
    final sel = _contentCtrl.selection;
    final text = _contentCtrl.text;
    final hasSel = sel.isValid && !sel.isCollapsed;
    final toCopy = hasSel ? sel.textInside(text) : text;
    if (toCopy.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: toCopy));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(hasSel ? '선택한 내용을 복사했어요' : '전체 내용을 복사했어요'),
        duration: const Duration(milliseconds: 900),
      ));
    }
  }

  /// 붙여넣기 — 클립보드 텍스트를 현재 커서/선택 위치에 삽입.
  Future<void> _pasteContent() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final pasteText = data?.text;
    if (pasteText == null || pasteText.isEmpty) return;
    final text = _contentCtrl.text;
    final sel = _contentCtrl.selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final newText = text.replaceRange(start, end, pasteText);
    _contentCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + pasteText.length),
    );
    if (!_contentFocus.hasFocus) _contentFocus.requestFocus();
  }

  /// 선택 영역(없으면 커서 위치)에 서식 마커를 토글 적용.
  void _applyFmt(String mark) {
    _contentCtrl.value = applyMemoMarker(_contentCtrl.value, mark);
    if (!_contentFocus.hasFocus) _contentFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        // 뒤로가기 시 자동 저장
        if (_dirty) await _save(silent: true);
        if (mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? '새 메모' : '메모 편집'),
          actions: [
            IconButton(
              icon: const Icon(Icons.copy_all_outlined),
              tooltip: '복사 (선택 없으면 전체)',
              onPressed: _copyContent,
            ),
            IconButton(
              icon: const Icon(Icons.content_paste),
              tooltip: '붙여넣기',
              onPressed: _pasteContent,
            ),
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: '저장',
              onPressed: _dirty ? _save : null,
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  hintText: '제목 (선택)',
                  border: InputBorder.none,
                ),
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
                maxLines: 1,
                magnifierConfiguration: TextMagnifierConfiguration.disabled,
              ),
              const Divider(height: 16),
              // 서식 툴바 (선택 영역에 진하게/기울임/밑줄 토글)
              Row(
                children: [
                  _FmtButton(
                    icon: Icons.format_bold,
                    tooltip: '진하게',
                    onTap: () => _applyFmt('**'),
                  ),
                  _FmtButton(
                    icon: Icons.format_italic,
                    tooltip: '기울임',
                    onTap: () => _applyFmt('*'),
                  ),
                  _FmtButton(
                    icon: Icons.format_underlined,
                    tooltip: '밑줄',
                    onTap: () => _applyFmt('__'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // expands:true 로 본문 TextField 가 남은 세로 공간 전체를 채운다.
              // (예전엔 Listener 로 빈 곳 탭→커서이동을 했으나, 모바일에서
              //  복사 버튼 탭까지 가로채 선택이 풀려 복사가 안 되던 문제로 제거)
              Expanded(
                child: TextField(
                  controller: _contentCtrl,
                  focusNode: _contentFocus,
                  maxLines: null,
                  expands: true,
                  decoration: const InputDecoration(
                    hintText: '내용을 입력하세요...',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  textAlignVertical: TextAlignVertical.top,
                  // 한글 IME 가 커서를 다음 줄로 밀어내는 문제 회피.
                  autocorrect: false,
                  enableSuggestions: false,
                  enableIMEPersonalizedLearning: false,
                  // CanvasKit 렌더러에서 선택 돋보기가 사라지지 않는 버그 회피.
                  magnifierConfiguration:
                      TextMagnifierConfiguration.disabled,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FmtButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _FmtButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 22),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      color: Colors.grey.shade700,
      onPressed: onTap,
    );
  }
}
