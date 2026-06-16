import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/web_update_detector_stub.dart'
    if (dart.library.html) '../services/web_update_detector_web.dart';

/// 웹 전용: 새 Service Worker 버전 감지 시 상단 배너 노출.
/// 탭하면 페이지를 새로고침하여 새 버전 적용.
class WebUpdateBanner extends StatefulWidget {
  const WebUpdateBanner({super.key});

  @override
  State<WebUpdateBanner> createState() => _WebUpdateBannerState();
}

class _WebUpdateBannerState extends State<WebUpdateBanner> {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) return;
    WebUpdateDetector.available.listen((_) {
      if (mounted) setState(() => _show = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || !_show) return const SizedBox.shrink();
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: primary.withOpacity(0.12),
      child: InkWell(
        onTap: () => WebUpdateDetector.apply(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.download_done, color: primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '새 버전 준비됨',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: primary,
                      ),
                    ),
                    Text(
                      '탭해서 적용',
                      style: TextStyle(
                        fontSize: 12,
                        color: primary.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.refresh, color: primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
