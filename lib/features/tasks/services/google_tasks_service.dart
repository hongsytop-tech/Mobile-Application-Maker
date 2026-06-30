import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'tasks_token.dart';

/// Google Tasks 한 건.
class GoogleTask {
  final String id;
  final String title;
  final String notes;
  final String status; // 'needsAction' | 'completed'
  final DateTime? updated;

  const GoogleTask({
    required this.id,
    required this.title,
    required this.notes,
    required this.status,
    this.updated,
  });

  factory GoogleTask.fromJson(Map<String, dynamic> j) => GoogleTask(
        id: j['id'] as String,
        title: (j['title'] as String? ?? '').trim(),
        notes: (j['notes'] as String? ?? '').trim(),
        status: j['status'] as String? ?? 'needsAction',
        updated: j['updated'] == null
            ? null
            : DateTime.tryParse(j['updated'] as String),
      );
}

class GoogleTasksException implements Exception {
  final String message;
  const GoogleTasksException(this.message);
  @override
  String toString() => message;
}

/// Google Tasks 읽기 전용 연동.
/// 앱 로그인(Supabase)과는 완전히 별개로, Tasks 읽기 권한만 받아 일정을 가져온다.
class GoogleTasksService {
  static const _scope = 'https://www.googleapis.com/auth/tasks.readonly';
  static const _base = 'https://tasks.googleapis.com/tasks/v1';

  static String get _clientId =>
      dotenv.maybeGet('GOOGLE_WEB_CLIENT_ID') ?? '';

  static bool get isConfigured {
    final id = _clientId;
    return id.isNotEmpty && !id.startsWith('your_');
  }

  /// GIS 스크립트를 미리 로드해 둔다 (버튼 탭 시 즉시 팝업).
  static Future<void> preload() async {
    try {
      await preloadTasksAuth();
    } catch (_) {}
  }

  /// Tasks 읽기 권한 access token 을 받는다 (웹: GIS 토큰 클라이언트).
  static Future<String> _accessToken() async {
    final clientId = _clientId;
    if (clientId.isEmpty) {
      throw const GoogleTasksException(
          'GOOGLE_WEB_CLIENT_ID 가 설정되지 않았습니다.');
    }
    try {
      return await getTasksAccessToken(clientId, _scope);
    } catch (e) {
      throw GoogleTasksException(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// 모든 task list 의 미완료(needsAction) 항목을 한꺼번에 가져온다.
  static Future<List<GoogleTask>> fetchActiveTasks() async {
    final token = await _accessToken();
    final headers = {'Authorization': 'Bearer $token'};

    // 1) task list 목록
    final listsRes = await http.get(
      Uri.parse('$_base/users/@me/lists?maxResults=100'),
      headers: headers,
    );
    if (listsRes.statusCode != 200) {
      throw GoogleTasksException(
          'task list 조회 실패 (${listsRes.statusCode})');
    }
    final listsJson =
        jsonDecode(utf8.decode(listsRes.bodyBytes)) as Map<String, dynamic>;
    final lists = (listsJson['items'] as List? ?? const [])
        .map((e) => (e as Map<String, dynamic>)['id'] as String)
        .toList();

    // 2) 각 리스트의 미완료 항목
    final all = <GoogleTask>[];
    for (final listId in lists) {
      final res = await http.get(
        Uri.parse('$_base/lists/$listId/tasks'
            '?showCompleted=false&showHidden=false&maxResults=100'),
        headers: headers,
      );
      if (res.statusCode != 200) {
        if (kDebugMode) {
          print('tasks 조회 실패 list=$listId code=${res.statusCode}');
        }
        continue;
      }
      final json =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      for (final item in (json['items'] as List? ?? const [])) {
        final t = GoogleTask.fromJson(item as Map<String, dynamic>);
        // 제목이 빈 항목은 건너뜀
        if (t.title.isNotEmpty && t.status != 'completed') {
          all.add(t);
        }
      }
    }
    return all;
  }
}
