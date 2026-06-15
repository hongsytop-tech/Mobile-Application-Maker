import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/book.dart';
import '../providers/stats_providers.dart';
import '../widgets/book_cover.dart';
import 'book_detail_screen.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(statPeriodProvider);
    final stats = ref.watch(readingStatsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('독서 통계')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 기간 선택
          SegmentedButton<StatPeriod>(
            segments: StatPeriod.values
                .map((p) => ButtonSegment(value: p, label: Text(p.label)))
                .toList(),
            selected: {period},
            showSelectedIcon: false,
            onSelectionChanged: (s) =>
                ref.read(statPeriodProvider.notifier).state = s.first,
          ),
          const SizedBox(height: 20),

          // 요약 카드
          Row(
            children: [
              _StatCard(
                label: '${period.label} 완독',
                value: '${stats.finishedCount}',
                unit: '권',
                color: const Color(0xFF4F46E5),
                icon: Icons.check_circle,
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: '읽는 중',
                value: '${stats.readingCount}',
                unit: '권',
                color: const Color(0xFF0EA5E9),
                icon: Icons.menu_book,
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: '위시리스트',
                value: '${stats.wishlistCount}',
                unit: '권',
                color: const Color(0xFFF59E0B),
                icon: Icons.bookmark,
              ),
            ],
          ),
          const SizedBox(height: 28),

          // 월별 완독 차트
          Text('${DateTime.now().year}년 월별 완독',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: _MonthlyChart(monthly: stats.monthlyFinished),
          ),
          const SizedBox(height: 28),

          // 완독 책 리스트
          Text('${period.label} 완독한 책',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (stats.finishedBooks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  '${period.label}에 완독한 책이 없어요.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            )
          else
            ...stats.finishedBooks.map((b) => _FinishedTile(book: b)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: color)),
                const SizedBox(width: 2),
                Text(unit, style: TextStyle(fontSize: 12, color: color)),
              ],
            ),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _MonthlyChart extends StatelessWidget {
  final List<int> monthly;
  const _MonthlyChart({required this.monthly});

  @override
  Widget build(BuildContext context) {
    final maxVal = monthly.fold<int>(0, (m, v) => v > m ? v : m);
    final maxY = (maxVal < 4 ? 4 : maxVal + 1).toDouble();

    return BarChart(
      BarChartData(
        maxY: maxY,
        minY: 0,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, _, rod, __) => BarTooltipItem(
              '${rod.toY.round()}권',
              const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, _) {
                final m = value.toInt() + 1;
                if (m % 2 == 1 || m == 12) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('$m',
                        style: const TextStyle(
                            fontSize: 10, color: Colors.grey)),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY <= 4 ? 1 : (maxY / 4).ceilToDouble(),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(12, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: monthly[i].toDouble(),
                width: 12,
                color: const Color(0xFF4F46E5),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(3),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _FinishedTile extends StatelessWidget {
  final Book book;
  const _FinishedTile({required this.book});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy.MM.dd');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: BookCover(url: book.thumbnail, width: 40, height: 58),
      title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        book.finishedAt != null ? '완독 ${df.format(book.finishedAt!)}' : '',
        style: const TextStyle(fontSize: 12),
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => BookDetailScreen(bookId: book.id)),
      ),
    );
  }
}
