import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../main.dart' show AppColors;

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: StreamBuilder<QuerySnapshot>(
        stream: service.getCards(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.accent));
          }

          final docs = snapshot.data!.docs;

          int totalCards = 0;
          int monsterCount = 0;
          int magicCount = 0;
          int trapCount = 0;

          // 서브타입별 집계
          Map<String, int> subTypeCount = {};
          // 속성별 집계
          Map<String, int> attributeCount = {};
          // 위치별 집계
          Map<String, int> locationCount = {};

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final count = (data['count'] ?? 0) as int;
            final type = (data['type'] ?? '') as String;
            final subType = (data['subType'] ?? '') as String;
            final attribute = (data['attribute'] ?? '') as String;
            final location = (data['location'] ?? '') as String;

            totalCards += count;

            if (type == '몬스터') monsterCount += count;
            if (type == '마법') magicCount += count;
            if (type == '함정') trapCount += count;

            if (subType.isNotEmpty) {
              subTypeCount[subType] = (subTypeCount[subType] ?? 0) + count;
            }
            if (attribute.isNotEmpty && attribute != '없음') {
              attributeCount[attribute] =
                  (attributeCount[attribute] ?? 0) + count;
            }
            if (location.isNotEmpty) {
              locationCount[location] = (locationCount[location] ?? 0) + count;
            }
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 헤더
                Container(
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        '통계',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text('보유 카드 현황을 한눈에 확인하세요',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 총계 카드 3개
                      Row(
                        children: [
                          _StatCard(
                            label: '총 카드 수',
                            value: '$totalCards',
                            unit: '장',
                            icon: Icons.style_rounded,
                            color: AppColors.accent,
                            bgColor: AppColors.accentLight,
                          ),
                          const SizedBox(width: 16),
                          _StatCard(
                            label: '몬스터',
                            value: '$monsterCount',
                            unit: '장',
                            icon: Icons.catching_pokemon_rounded,
                            color: AppColors.monster,
                            bgColor: AppColors.monsterBg,
                          ),
                          const SizedBox(width: 16),
                          _StatCard(
                            label: '마법',
                            value: '$magicCount',
                            unit: '장',
                            icon: Icons.auto_fix_high_rounded,
                            color: AppColors.magic,
                            bgColor: AppColors.magicBg,
                          ),
                          const SizedBox(width: 16),
                          _StatCard(
                            label: '함정',
                            value: '$trapCount',
                            unit: '장',
                            icon: Icons.warning_amber_rounded,
                            color: AppColors.trap,
                            bgColor: AppColors.trapBg,
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // 서브타입 + 속성 분포 (2열)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _SectionCard(
                              title: '유형별 분포',
                              icon: Icons.category_rounded,
                              child: subTypeCount.isEmpty
                                  ? _EmptyState('카드를 추가해보세요')
                                  : Column(
                                      children: subTypeCount.entries
                                          .toList()
                                          .sorted()
                                          .map((e) => _BarRow(
                                                label: e.key,
                                                count: e.value,
                                                total: totalCards,
                                                color: AppColors.accent,
                                              ))
                                          .toList(),
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

                      // 위치별
                      _SectionCard(
                        title: '위치별 보유 현황',
                        icon: Icons.location_on_rounded,
                        child: locationCount.isEmpty
                            ? _EmptyState('카드를 추가해보세요')
                            : Row(
                                children: locationCount.entries
                                    .map((e) => Expanded(
                                          child: _LocationTile(
                                            location: e.key,
                                            count: e.value,
                                          ),
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

// 정렬 헬퍼
extension SortedEntries on List<MapEntry<String, int>> {
  List<MapEntry<String, int>> sorted() {
    return this..sort((a, b) => b.value.compareTo(a.value));
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(unit,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 14)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard(
      {required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _BarRow(
      {required this.label,
      required this.count,
      required this.total,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final ratio = total > 0 ? count / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 72,
                child: Text(label,
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    backgroundColor: AppColors.surfaceAlt,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('$count',
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

class _LocationTile extends StatelessWidget {
  final String location;
  final int count;

  const _LocationTile({required this.location, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(location,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState(this.message);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(message,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
      ),
    );
  }
}