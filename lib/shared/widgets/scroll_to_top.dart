import 'package:flutter/material.dart';

/// 스크롤 가능한 [child] 를 감싸면, 일정 이상 내려갔을 때 우하단에
/// "맨 위로" 버튼이 나타난다. ScrollController 를 직접 만들 필요 없이,
/// NotificationListener 로 스크롤을 감지하고 Scrollable.maybeOf 로 위치를 잡는다.
class ScrollToTop extends StatefulWidget {
  const ScrollToTop({
    required this.child,
    this.showOffset = 300,
    this.bottom = 16,
    this.right = 16,
    super.key,
  });

  final Widget child;
  final double showOffset;
  final double bottom;
  final double right;

  @override
  State<ScrollToTop> createState() => _ScrollToTopState();
}

class _ScrollToTopState extends State<ScrollToTop> {
  ScrollPosition? _position;
  bool _show = false;

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    final ctx = n.context;
    if (ctx != null) _position = Scrollable.maybeOf(ctx)?.position;
    final show = n.metrics.pixels > widget.showOffset;
    if (show != _show && mounted) setState(() => _show = show);
    return false;
  }

  void _toTop() {
    final p = _position;
    if (p != null && p.hasPixels) {
      p.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: widget.child,
        ),
        if (_show)
          Positioned(
            right: widget.right,
            bottom: widget.bottom,
            child: FloatingActionButton.small(
              heroTag: null, // 여러 화면 동시 활성 시 hero 충돌 방지
              tooltip: '맨 위로',
              backgroundColor: Colors.white,
              foregroundColor: Theme.of(context).colorScheme.primary,
              elevation: 3,
              shape: const CircleBorder(),
              onPressed: _toTop,
              child: const Icon(Icons.arrow_upward),
            ),
          ),
      ],
    );
  }
}
