import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recommend_settings.dart';
import '../services/quote_recommend_service.dart';

/// "오늘의 추천 문구" 설정 provider.
final quoteRecommendSettingsProvider = AsyncNotifierProvider<
    QuoteRecommendSettingsNotifier, RecommendSettings>(
  QuoteRecommendSettingsNotifier.new,
);

class QuoteRecommendSettingsNotifier extends AsyncNotifier<RecommendSettings> {
  @override
  Future<RecommendSettings> build() => QuoteRecommendService.load();

  Future<void> save(RecommendSettings s) async {
    state = AsyncData(s);
    await QuoteRecommendService.save(s);
    await QuoteRecommendService.reschedule();
  }
}
