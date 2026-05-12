import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import '../services/firestore_service.dart';
import '../main.dart' show AppColors, AppTheme;

// ── 테마 헬퍼 ────────────────────────────────────────────────
extension _T on BuildContext {
  bool  get isDark     => AppTheme.isDark(this);
  Color get bg         => AppTheme.bg(this);
  Color get surface    => AppTheme.surface(this);
  Color get surfaceAlt => AppTheme.surfaceAlt(this);
  Color get border     => AppTheme.border(this);
  Color get textPri    => AppTheme.textPrimary(this);
  Color get textSec    => AppTheme.textSecondary(this);
  Color get textMut    => AppTheme.textMuted(this);
  Color get accentLt   => isDark ? AppColors.accent.withOpacity(0.15) : AppColors.accentLight;
  Color get monsterBg  => isDark ? AppColors.monster.withOpacity(0.15) : AppColors.monsterBg;
  Color get magicBg    => isDark ? AppColors.magic.withOpacity(0.15)   : AppColors.magicBg;
  Color get trapBg     => isDark ? AppColors.trap.withOpacity(0.15)    : AppColors.trapBg;
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctx     = context;
    final service = FirestoreService();

    return Scaffold(
      backgroundColor: ctx.bg,
      body: StreamBuilder<QuerySnapshot>(
        stream: service.getCards(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: AppColors.accent));
          }

          final docs = snapshot.data!.docs;

          int totalCards    = 0;
          int monsterCount  = 0;
          int magicCount    = 0;
          int trapCount     = 0;
          final subTypeCount   = <String, int>{};
          final attributeCount = <String, int>{};
          final locationCount  = <String, int>{};

          for (final doc in docs) {
            final data      = doc.data() as Map<String, dynamic>;
            final count     = (data['count']     ?? 0) as int;
            final type      = (data['type']      ?? '') as String;
            final subType   = (data['subType']   ?? '') as String;
            final attribute = (data['attribute'] ?? '') as String;
            final location  = (data['location']  ?? '') as String;

            totalCards += count;
            if (type == '몬스터') monsterCount += count;
            if (type == '마법')   magicCount   += count;
            if (type == '함정')   trapCount    += count;

            if (subType.isNotEmpty) {
              subTypeCount[subType] = (subTypeCount[subType] ?? 0) + count;
            }
            if (attribute.isNotEmpty && attribute != '없음') {
              attributeCount[attribute] = (attributeCount[attribute] ?? 0) + count;
            }
            if (location.isNotEmpty) {
              locationCount[location] = (locationCount[location] ?? 0) + count;
            }
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 헤더 ──
                Container(
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
                  decoration: BoxDecoration(
                    color: ctx.surface,
                    border: Border(bottom: BorderSide(color: ctx.border)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('통계',
                        style: TextStyle(
                          color: ctx.textPri, fontSize: 22,
                          fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                      const SizedBox(height: 2),
                      Text('보유 카드 현황을 한눈에 확인하세요',
                        style: TextStyle(color: ctx.textSec, fontSize: 13)),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── 하이라이트 카드 ──
                      _HighlightCard(
                        totalCards: totalCards,
                        monsterCount: monsterCount,
                        magicCount: magicCount,
                        trapCount: trapCount,
                      ),

                      const SizedBox(height: 28),

                      // ── 총계 카드 4개 ──
                      Row(children: [
                        _StatCard(
                          label: '총 카드 수', value: '$totalCards', unit: '장',
                          icon: Icons.style_rounded,
                          color: AppColors.accent, bgColor: ctx.accentLt),
                        const SizedBox(width: 16),
                        _StatCard(
                          label: '몬스터', value: '$monsterCount', unit: '장',
                          icon: Icons.catching_pokemon_rounded,
                          color: AppColors.monster, bgColor: ctx.monsterBg),
                        const SizedBox(width: 16),
                        _StatCard(
                          label: '마법', value: '$magicCount', unit: '장',
                          icon: Icons.auto_fix_high_rounded,
                          color: AppColors.magic, bgColor: ctx.magicBg),
                        const SizedBox(width: 16),
                        _StatCard(
                          label: '함정', value: '$trapCount', unit: '장',
                          icon: Icons.warning_amber_rounded,
                          color: AppColors.trap, bgColor: ctx.trapBg),
                      ]),

                      const SizedBox(height: 28),

                      // ── 유형별 + 속성별 (2열) ──
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _SectionCard(
                              title: '유형별 분포',
                              icon: Icons.category_rounded,
                              child: subTypeCount.isEmpty
                                  ? _EmptyState('카드를 추가해보세요')
                                  : _DonutChart(
                                      data: subTypeCount,
                                      colors: [
                                        AppColors.monster,
                                        AppColors.magic,
                                        AppColors.trap,
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _SectionCard(
                              title: '속성별 분포',
                              icon: Icons.bolt_rounded,
                              child: attributeCount.isEmpty
                                  ? _EmptyState('몬스터 카드를 추가해보세요')
                                  : Column(
                                      children: attributeCount.entries
                                          .toList()
                                          .sorted()
                                          .map((e) => _BarRow(
                                                label: e.key,
                                                count: e.value,
                                                total: totalCards,
                                                color: _attributeColor(e.key),
                                              ))
                                          .toList(),
                                    ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ── 위치별 ──
                      _SectionCard(
                        title: '위치별 보유 현황',
                        icon: Icons.location_on_rounded,
                        child: locationCount.isEmpty
                            ? _EmptyState('카드를 추가해보세요')
                            : Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: locationCount.entries
                                    .map((e) => _LocationTile(
                                          location: e.key,
                                          count: e.value,
                                        ))
                                    .toList(),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _attributeColor(String attr) {
    switch (attr) {
      case '빛':  return const Color(0xFFD97706);
      case '어둠': return const Color(0xFF7C3AED);
      case '불':  return const Color(0xFFDC2626);
      case '물':  return const Color(0xFF2563EB);
      case '땅':  return const Color(0xFF92400E);
      case '바람': return const Color(0xFF0D9488);
      case '신':  return const Color(0xFFD97706);
      default:   return AppColors.accent;
    }
  }
}

// ── 정렬 헬퍼 ─────────────────────────────────────────────────
extension SortedEntries on List<MapEntry<String, int>> {
  List<MapEntry<String, int>> sorted() =>
      this..sort((a, b) => b.value.compareTo(a.value));
}

// ── 하이라이트 카드 ──────────────────────────────────────────
class _HighlightCard extends StatelessWidget {
  final int totalCards;
  final int monsterCount;
  final int magicCount;
  final int trapCount;

  const _HighlightCard({
    required this.totalCards,
    required this.monsterCount,
    required this.magicCount,
    required this.trapCount,
  });

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ctx.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ctx.border),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(ctx.isDark ? 0.3 : 0.08),
          blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '총 $totalCards장의 카드를',
                  style: TextStyle(
                    color: ctx.textPri,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '보유하고 있어요!',
                  style: TextStyle(
                    color: ctx.textPri,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    _MiniStat(
                      icon: Icons.catching_pokemon_rounded,
                      color: AppColors.monster,
                      label: '몬스터',
                      value: '$monsterCount',
                    ),
                    _MiniStat(
                      icon: Icons.auto_fix_high_rounded,
                      color: AppColors.magic,
                      label: '마법',
                      value: '$magicCount',
                    ),
                    _MiniStat(
                      icon: Icons.warning_amber_rounded,
                      color: AppColors.trap,
                      label: '함정',
                      value: '$trapCount',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.style_rounded,
              size: 60,
              color: AppColors.accent.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 미니 스탯 ──────────────────────────────────────────────────
class _MiniStat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _MiniStat({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(height: 4),
        Text(value,
          style: TextStyle(
            color: ctx.textPri,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          )),
        Text(label,
          style: TextStyle(
            color: ctx.textMut,
            fontSize: 11,
          )),
      ],
    );
  }
}

// ── 도넛 차트 ──────────────────────────────────────────────────
class _DonutChart extends StatelessWidget {
  final Map<String, int> data;
  final List<Color> colors;

  const _DonutChart({
    required this.data,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    final total = data.values.fold<int>(0, (a, b) => a + b);
    final sortedEntries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(180, 180),
                painter: _DonutChartPainter(
                  data: sortedEntries,
                  colors: colors,
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '총 $total장',
                    style: TextStyle(
                      color: ctx.textPri,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ...sortedEntries.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final percentage = ((item.value / total) * 100).toStringAsFixed(1);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: colors[index % colors.length],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.key,
                    style: TextStyle(
                      color: ctx.textSec,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  '${item.value}장 ($percentage%)',
                  style: TextStyle(
                    color: ctx.textPri,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
}

// ── 도넛 차트 페인터 ─────────────────────────────────────────
class _DonutChartPainter extends CustomPainter {
  final List<MapEntry<String, int>> data;
  final List<Color> colors;

  _DonutChartPainter({
    required this.data,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final innerRadius = radius * 0.6;
    final outerRadius = radius * 0.95;

    final total = data.fold<int>(0, (sum, item) => sum + item.value);
    var currentAngle = -math.pi / 2;

    for (var i = 0; i < data.length; i++) {
      final item = data[i];
      final sweepAngle = (item.value / total) * 2 * math.pi;
      final color = colors[i % colors.length];

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      final path = Path();
      final startAngle = currentAngle;
      final endAngle = currentAngle + sweepAngle;

      // 외부 호
      path.arcTo(
        Rect.fromCircle(center: center, radius: outerRadius),
        startAngle,
        sweepAngle,
        false,
      );

      // 내부 호 (반대 방향)
      path.arcTo(
        Rect.fromCircle(center: center, radius: innerRadius),
        endAngle,
        -sweepAngle,
        false,
      );

      path.close();
      canvas.drawPath(path, paint);

      currentAngle = endAngle;
    }

    // 중앙 배경 (흰색 원)
    final centerPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, innerRadius, centerPaint);
  }

  @override
  bool shouldRepaint(_DonutChartPainter oldDelegate) => false;
}

// ── 통계 카드 ─────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _StatCard({
    required this.label, required this.value, required this.unit,
    required this.icon, required this.color, required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: ctx.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ctx.border),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(ctx.isDark ? 0.25 : 0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(value,
                  style: TextStyle(
                    color: ctx.textPri, fontSize: 28,
                    fontWeight: FontWeight.w800, letterSpacing: -1)),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(unit, style: TextStyle(color: ctx.textSec, fontSize: 14)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: ctx.textMut, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ── 섹션 카드 ─────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ctx.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ctx.border),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(ctx.isDark ? 0.25 : 0.04),
          blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 18, color: AppColors.accent),
            const SizedBox(width: 8),
            Text(title,
              style: TextStyle(color: ctx.textPri, fontSize: 15, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ── 바 행 ─────────────────────────────────────────────────────
class _BarRow extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _BarRow({required this.label, required this.count, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    final ctx   = context;
    final ratio = total > 0 ? count / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        SizedBox(
          width: 72,
          child: Text(label,
            style: TextStyle(color: ctx.textSec, fontSize: 12, fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: ctx.surfaceAlt,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text('$count',
          style: TextStyle(color: ctx.textPri, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ── 위치 타일 ─────────────────────────────────────────────────
class _LocationTile extends StatelessWidget {
  final String location;
  final int count;

  const _LocationTile({required this.location, required this.count});

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: ctx.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ctx.border),
      ),
      child: Column(children: [
        Text('$count',
          style: TextStyle(color: ctx.textPri, fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(location, style: TextStyle(color: ctx.textSec, fontSize: 12)),
      ]),
    );
  }
}

// ── 빈 상태 ──────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState(this.message);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Center(
      child: Text(message,
        style: TextStyle(color: context.textMut, fontSize: 13)),
    ),
  );
}
