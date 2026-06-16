import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/update_info.dart';
import '../providers/update_providers.dart';

class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 웹에선 OS 인스톨러 흐름이 없으므로 배너 자체 숨김
    if (kIsWeb) return const SizedBox.shrink();
    final asyncInfo = ref.watch(updateCheckProvider);
    return asyncInfo.when(
      loading: () => _DebugBanner(text: '업데이트 확인 중...', color: Colors.orange),
      error: (e, _) =>
          _DebugBanner(text: '업데이트 확인 실패: $e', color: Colors.red),
      data: (info) {
        if (info == null) {
          return const _DebugBanner(
              text: '업데이트 확인됨 (정보 없음 — 안드로이드 외 플랫폼?)',
              color: Colors.grey);
        }
        if (!info.hasUpdate || info.apkUrl.isEmpty) {
          return _DebugBanner(
            text:
                '최신 버전입니다 (현재 #${info.currentBuild} / 최신 #${info.latestBuild})',
            color: Colors.green,
          );
        }
        final primary = Theme.of(context).colorScheme.primary;
        return Material(
          color: primary.withOpacity(0.08),
          child: InkWell(
            onTap: () => _showDownloadSheet(context, info),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.system_update, color: primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '새 버전 (#${info.latestBuild}) 사용 가능',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: primary,
                          ),
                        ),
                        Text(
                          '현재 #${info.currentBuild} · 탭해서 업데이트',
                          style: TextStyle(
                            fontSize: 12,
                            color: primary.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: primary, size: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDownloadSheet(BuildContext context, UpdateInfo info) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _UpdateSheet(info: info),
    );
  }
}

class _DebugBanner extends ConsumerWidget {
  final String text;
  final Color color;
  const _DebugBanner({required this.text, required this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: color.withOpacity(0.1),
      child: InkWell(
        onTap: () => ref.invalidate(updateCheckProvider),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: color, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(color: color, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.refresh, color: color, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpdateSheet extends ConsumerStatefulWidget {
  final UpdateInfo info;
  const _UpdateSheet({required this.info});

  @override
  ConsumerState<_UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends ConsumerState<_UpdateSheet> {  double _progress = 0;
  int _received = 0;
  int _total = 0;
  bool _downloading = false;
  String? _error;
  final _cancelToken = CancelToken();

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)}KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB';
  }

  Future<void> _startDownload() async {
    setState(() {
      _downloading = true;
      _error = null;
    });
    try {
      final svc = ref.read(updateServiceProvider);
      final file = await svc.downloadApk(
        widget.info.apkUrl,
        onProgress: (p, r, t) {
          if (mounted) {
            setState(() {
              _progress = p;
              _received = r;
              _total = t;
            });
          }
        },
        cancelToken: _cancelToken,
      );
      if (!mounted) return;
      await svc.installApk(file);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _downloading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    if (_downloading) _cancelToken.cancel('Sheet closed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              '새 버전 #${info.latestBuild}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              '현재 설치된 버전: #${info.currentBuild}',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (info.releaseNotes.isNotEmpty) ...[
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    info.releaseNotes,
                    style: const TextStyle(fontSize: 12, height: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_downloading) ...[
              LinearProgressIndicator(value: _progress > 0 ? _progress : null),
              const SizedBox(height: 8),
              Text(
                _total > 0
                    ? '${_formatBytes(_received)} / ${_formatBytes(_total)} (${(_progress * 100).toStringAsFixed(0)}%)'
                    : '다운로드 중...',
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  _cancelToken.cancel('User cancel');
                  Navigator.of(context).pop();
                },
                child: const Text('취소'),
              ),
            ] else ...[
              if (_error != null) ...[
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(
                icon: const Icon(Icons.download),
                label: Text(
                  info.apkSizeBytes != null
                      ? '다운로드 및 설치 (${_formatBytes(info.apkSizeBytes!)})'
                      : '다운로드 및 설치',
                ),
                onPressed: _startDownload,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('나중에'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
