// lib/widgets/korean_card_effect_widget.dart

import 'package:flutter/material.dart';
import '../services/yugioh_api_service.dart';
import '../main.dart' show AppColors;

class KoreanCardEffectWidget extends StatefulWidget {
  final String cardName;
  final String engName;
  final String engDesc;
  final YugiohApiService api;

  const KoreanCardEffectWidget({
    super.key,
    required this.cardName,
    required this.engName,
    required this.engDesc,
    required this.api,
  });

  @override
  State<KoreanCardEffectWidget> createState() => _KoreanCardEffectWidgetState();
}

class _KoreanCardEffectWidgetState extends State<KoreanCardEffectWidget> {
  String? _koText;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchKorean();
  }

  Future<void> _fetchKorean() async {
    try {
      final result = await widget.api.fetchKoreanCardText(
        widget.cardName,
        engName: widget.engName,
      );
      if (mounted) {
        setState(() {
          _koText = result.isNotEmpty ? result : null;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _koText = null;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 로딩 중
    if (_loading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.accent),
            ),
            SizedBox(width: 8),
            Text(
              '한글 효과 로딩 중...',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      );
    }

    // 한글 효과 로드 성공
    if (_koText != null && _koText!.isNotEmpty) {
      return _EffectBox(
        label: '한글 효과',
        labelColor: AppColors.magic,
        labelBg: AppColors.magicBg,
        text: _koText!,
      );
    }

    // 한글 없으면 영문 desc fallback
    if (widget.engDesc.isNotEmpty) {
      return _EffectBox(
        label: '영문 효과',
        labelColor: AppColors.textSecondary,
        labelBg: AppColors.surfaceAlt,
        text: widget.engDesc,
      );
    }

    return const SizedBox.shrink();
  }
}

class _EffectBox extends StatelessWidget {
  final String label;
  final Color labelColor;
  final Color labelBg;
  final String text;

  const _EffectBox({
    required this.label,
    required this.labelColor,
    required this.labelBg,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: labelBg,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: labelColor.withOpacity(0.3)),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: labelColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
