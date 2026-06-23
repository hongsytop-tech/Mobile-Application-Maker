import 'package:flutter/material.dart';

/// 스크롤 위치가 일정 이상 내려갔을 때만 노출되는 "맨 위로" 작은 FAB.
/// 기존 FAB 와 함께 쓸 수 있도록 mini 사이즈, heroTag 고유.
class ScrollToTopFab extends StatefulWidget {
  final ScrollController controller;
  final double showThreshold;
  final String heroTag;

  const ScrollToTopFab({
    super.key,
    required this.controller,
    this.showThreshold = 200,
    this.heroTag = 'scrollToTop',
  });

  @override
  State<ScrollToTopFab> createState() => _ScrollToTopFabState();
}

class _ScrollToTopFabState extends State<ScrollToTopFab> {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!widget.controller.hasClients) return;
    final next = widget.controller.offset > widget.showThreshold;
    if (next != _show) setState(() => _show = next);
  }

  Future<void> _scrollUp() async {
    if (!widget.controller.hasClients) return;
    await widget.controller.animateTo(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !_show,
      child: AnimatedOpacity(
        opacity: _show ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 180),
        child: FloatingActionButton.small(
          heroTag: widget.heroTag,
          tooltip: '맨 위로',
          onPressed: _scrollUp,
          backgroundColor: Colors.white,
          foregroundColor: Theme.of(context).colorScheme.primary,
          elevation: 3,
          shape: const CircleBorder(),
          child: const Icon(Icons.arrow_upward),
        ),
      ),
    );
  }
}
