import 'package:flutter/material.dart';
import '../main.dart' show AppColors;
import '../services/yugioh_api_service.dart';
import '../widgets/korean_card_effect_widget.dart';

// ── 프록시 이미지 위젯 (CORS 우회) ──────────────────────────
class _ProxiedImage extends StatefulWidget {
  final String imageUrl;
  final double width;
  final double height;
  final BoxFit fit;

  const _ProxiedImage({
    required this.imageUrl,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
  });

  @override
  State<_ProxiedImage> createState() => _ProxiedImageState();
}

class _ProxiedImageState extends State<_ProxiedImage> {
  int _index = 0;
  late List<String> _candidates;

  @override
  void initState() {
    super.initState();
    _candidates = proxyImageUrlCandidates(widget.imageUrl);
  }

  List<String> proxyImageUrlCandidates(String url) {
    if (url.isEmpty) return [];
    try {
      final uri = Uri.parse(url);
      final encoded = Uri.encodeComponent(url);
      return [
        'https://images.weserv.nl/?url=${uri.host}${uri.path}',
        'https://corsproxy.io/?$encoded',
        'https://api.allorigins.win/raw?url=$encoded',
        url,
      ];
    } catch (_) {
      return [url];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrl.isEmpty || _candidates.isEmpty) {
      return const _ImagePlaceholder();
    }
    if (_index >= _candidates.length) {
      return const _ImagePlaceholder();
    }
    return Image.network(
      _candidates[_index],
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      loadingBuilder: (_, child, progress) => progress == null
          ? child
          : Container(
              width: widget.width,
              height: widget.height,
              color: AppColors.surfaceAlt,
              child: const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.textMuted),
                ),
              ),
            ),
      errorBuilder: (_, __, ___) {
        if (_index < _candidates.length - 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _index++);
          });
          return Container(
            width: widget.width,
            height: widget.height,
            color: AppColors.surfaceAlt,
          );
        }
        return const _ImagePlaceholder();
      },
    );
  }
}

class CardDetailDialog extends StatelessWidget {
  final Map<String, dynamic> cardData;
  final String docId;

  const CardDetailDialog({
    super.key,
    required this.cardData,
    required this.docId,
  });

  @override
  Widget build(BuildContext context) {
    final name = cardData['name'] ?? '';
    final engName = cardData['engName'] ?? '';
    final type = cardData['type'] ?? '';
    final subType = cardData['subType'] ?? '';
    final attribute = cardData['attribute'] ?? '';
    final level = cardData['level'] ?? 0;
    final race = cardData['race'] ?? '';
    final count = cardData['count'] ?? 1;
    final location = cardData['location'] ?? '';
    final imageUrl = cardData['imageUrl'] ?? '';
    final desc = cardData['desc'] ?? '';
    final memo = cardData['memo'] ?? '';

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 84,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: _ProxiedImage(
                        imageUrl: imageUrl,
                        width: 60,
                        height: 84,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (engName.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            engName,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (subType.isNotEmpty)
                              _TypeChip(
                                  label: subType,
                                  color: _getSubTypeColor(subType)),
                            if (type.isNotEmpty && subType.isEmpty)
                              _TypeChip(
                                  label: type, color: _getTypeColor(type)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close,
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            // 내용
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoGrid(context, {
                      '타입': type,
                      '유형': subType,
                      '속성': attribute,
                      '레벨': level > 0 ? '★$level' : '-',
                      '종족': race,
                      '수량': '$count장',
                      '위치': location.isNotEmpty ? location : '-',
                    }),
                    const SizedBox(height: 20),

                    if (desc.isNotEmpty || engName.isNotEmpty ||
                        name.isNotEmpty) ...[
                      const Text(
                        '카드 효과',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      KoreanCardEffectWidget(
                        cardName: name,
                        engName: engName,
                        engDesc: desc,
                        api: YugiohApiService(),
                      ),
                      const SizedBox(height: 20),
                    ],

                    if (memo.isNotEmpty) ...[
                      const Text(
                        '메모',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.accentLight.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.accent.withOpacity(0.3)),
                        ),
                        child: Text(
                          memo,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // 푸터
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        '닫기',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        '편집',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoGrid(BuildContext context, Map<String, String> info) {
    final entries = info.entries.toList();
    return Column(
      children: [
        for (int i = 0; i < entries.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                if (i < entries.length)
                  Expanded(
                    child: _InfoItem(
                      label: entries[i].key,
                      value: entries[i].value,
                    ),
                  ),
                if (i + 1 < entries.length) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: _InfoItem(
                      label: entries[i + 1].key,
                      value: entries[i + 1].value,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case '몬스터': return const Color(0xFFB45309);
      case '마법':   return const Color(0xFF059669);
      case '함정':   return const Color(0xFF9333EA);
      default:      return AppColors.textSecondary;
    }
  }

  Color _getSubTypeColor(String subType) {
    switch (subType) {
      case '일반':  return const Color(0xFFB45309);
      case '효과':  return const Color(0xFFD97706);
      case '융합':  return const Color(0xFF7C3AED);
      case '싱크로': return const Color(0xFF475569);
      case '엑시즈': return const Color(0xFFE2E8F0);
      case '링크':  return const Color(0xFF1D4ED8);
      case '의식':  return const Color(0xFF0284C7);
      default:     return AppColors.textSecondary;
    }
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final Color color;

  const _TypeChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;

  const _InfoItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceAlt,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported,
              color: AppColors.textMuted, size: 20),
          SizedBox(height: 2),
          Text('이미지\n없음',
              style: TextStyle(color: AppColors.textMuted, fontSize: 8),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}