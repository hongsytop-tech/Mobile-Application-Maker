import 'dart:math';

import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../auth/services/supabase_service.dart';
import 'kakao_oauth_stub.dart'
    if (dart.library.html) 'kakao_oauth_web.dart';

/// 카카오톡 메모(나에게 보내기) API 연동 클라이언트.
///
/// - [startLinkFlow] : 카카오 OAuth 페이지로 이동 (현재는 웹만 지원)
/// - [handleRedirectIfAny] : 앱 시작 시 호출. URL 에 ?code=…&state=kakao_… 이 있으면
///   Edge Function 으로 토큰 교환 후 URL 을 정리.
/// - [status] / [sendTest] / [unlink] : Edge Function 호출 래퍼.
class KakaoLinkService {
  static const _statePrefix = 'kakao_';
  static const _stateStorageKey = 'kakao_oauth_state';
  static const _scope = 'talk_message';

  static String get _restKey =>
      dotenv.maybeGet('KAKAO_REST_API_KEY') ?? '';

  static bool get isConfigured => _restKey.isNotEmpty;

  /// 웹: 카카오 로그인 페이지로 redirect. 모바일: UnsupportedError.
  static Future<void> startLinkFlow() async {
    if (_restKey.isEmpty) {
      throw StateError('KAKAO_REST_API_KEY 가 설정되지 않았습니다.');
    }
    final state = _statePrefix + _randomState();
    final redirectUri = currentOrigin();
    saveOauthState(_stateStorageKey, state);
    final url = Uri.https('kauth.kakao.com', '/oauth/authorize', {
      'client_id': _restKey,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': _scope,
      'state': state,
    }).toString();
    redirectToUrl(url);
  }

  /// URL 에 카카오 콜백 파라미터가 있으면 처리하고 true 반환.
  static Future<KakaoCallbackResult?> handleRedirectIfAny() async {
    final params = readQueryParams();
    final code = params['code'];
    final state = params['state'];
    if (code == null || state == null) return null;
    if (!state.startsWith(_statePrefix)) return null;

    final expected = readOauthState(_stateStorageKey);
    clearOauthState(_stateStorageKey);
    clearQueryParams();
    if (expected == null || expected != state) {
      return const KakaoCallbackResult(ok: false, error: 'state_mismatch');
    }

    try {
      final res = await SupabaseService.client.functions.invoke(
        'kakao-link',
        body: {
          'action': 'exchange',
          'code': code,
          'redirect_uri': currentOrigin(),
        },
      );
      final data = res.data as Map?;
      if (data?['ok'] == true) {
        return KakaoCallbackResult(
          ok: true,
          hasTalkMessage: data?['has_talk_message'] == true,
        );
      }
      return KakaoCallbackResult(ok: false, error: '${data?['error']}');
    } catch (e) {
      return KakaoCallbackResult(ok: false, error: '$e');
    }
  }

  static Future<KakaoLinkStatus> status() async {
    try {
      final res = await SupabaseService.client.functions
          .invoke('kakao-link', body: {'action': 'status'});
      final data = res.data as Map?;
      if (data?['linked'] == true) {
        return KakaoLinkStatus(
          linked: true,
          hasTalkMessage: data?['has_talk_message'] == true,
          scopes: ((data?['scopes'] as List?) ?? const [])
              .map((e) => '$e')
              .toList(),
        );
      }
      return const KakaoLinkStatus(linked: false);
    } catch (_) {
      return const KakaoLinkStatus(linked: false);
    }
  }

  static Future<bool> sendTest() async {
    final res = await SupabaseService.client.functions
        .invoke('kakao-link', body: {'action': 'send_test'});
    final data = res.data as Map?;
    if (data?['ok'] == true) return true;
    throw StateError('${data?['error'] ?? 'unknown'} ${data?['detail'] ?? ''}');
  }

  static Future<void> unlink() async {
    await SupabaseService.client.functions
        .invoke('kakao-link', body: {'action': 'unlink'});
  }

  static String _randomState() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}

class KakaoLinkStatus {
  final bool linked;
  final bool hasTalkMessage;
  final List<String> scopes;
  const KakaoLinkStatus({
    required this.linked,
    this.hasTalkMessage = false,
    this.scopes = const [],
  });
}

class KakaoCallbackResult {
  final bool ok;
  final bool hasTalkMessage;
  final String? error;
  const KakaoCallbackResult({
    required this.ok,
    this.hasTalkMessage = false,
    this.error,
  });
}
