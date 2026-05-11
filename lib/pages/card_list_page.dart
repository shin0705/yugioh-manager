// lib/pages/card_list_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../main.dart' show AppColors, DarkColors, AppTheme;
import '../constants/card_constants.dart';
import '../widgets/card_filter_dialog.dart';
import '../widgets/card_io_sheet.dart';
import '../widgets/card_detail_dialog.dart';
import 'edit_card_page.dart';
import 'add_card_page.dart';

// ── 빠른 필터 정의 ──────────────────────────────────────────
class _QuickFilter {
  final String label;
  final String? type;
  final String? subType;
  final Color color;
  final Color bgColor;

  const _QuickFilter({
    required this.label,
    this.type,
    this.subType,
    required this.color,
    required this.bgColor,
  });
}

const _quickFilters = [
  _QuickFilter(label: '전체',  color: Color(0xFF6366F1), bgColor: Color(0xFFEEF2FF)),
  _QuickFilter(label: '일반',  type: '몬스터', subType: '일반',  color: Color(0xFFB45309), bgColor: Color(0xFFFEF3C7)),
  _QuickFilter(label: '효과',  type: '몬스터', subType: '효과',  color: Color(0xFFD97706), bgColor: Color(0xFFFFF7ED)),
  _QuickFilter(label: '의식',  type: '몬스터', subType: '의식',  color: Color(0xFF0284C7), bgColor: Color(0xFFE0F2FE)),
  _QuickFilter(label: '융합',  subType: '융합',  color: Color(0xFF7C3AED), bgColor: Color(0xFFF5F3FF)),
  _QuickFilter(label: '싱크로', subType: '싱크로', color: Color(0xFF475569), bgColor: Color(0xFFF1F5F9)),
  _QuickFilter(label: '엑시즈', subType: '엑시즈', color: Color(0xFFE2E8F0), bgColor: Color(0xFF1E293B)),
  _QuickFilter(label: '링크',  subType: '링크',  color: Color(0xFF1D4ED8), bgColor: Color(0xFFEFF6FF)),
  _QuickFilter(label: '마법',  type: '마법', color: Color(0xFF059669), bgColor: Color(0xFFECFDF5)),
  _QuickFilter(label: '함정',  type: '함정', color: Color(0xFF9333EA), bgColor: Color(0xFFFAF5FF)),
];

// ── 테마 헬퍼 확장 (card_list 전용) ─────────────────────────
extension _DarkAdaptive on BuildContext {
  Color get bg         => AppTheme.isDark(this) ? DarkColors.bg         : const Color(0xFFF8FAFC);
  Color get surface    => AppTheme.isDark(this) ? DarkColors.surface    : Colors.white;
  Color get surfaceAlt => AppTheme.isDark(this) ? DarkColors.surfaceAlt : const Color(0xFFF1F5F9);
  Color get border     => AppTheme.isDark(this) ? DarkColors.border     : const Color(0xFFE2E8F0);
  Color get borderLight=> AppTheme.isDark(this) ? DarkColors.borderLight: const Color(0xFFF1F5F9);
  Color get textPri    => AppTheme.isDark(this) ? DarkColors.textPrimary   : const Color(0xFF0F172A);
  Color get textSec    => AppTheme.isDark(this) ? DarkColors.textSecondary : const Color(0xFF475569);
  Color get textMut    => AppTheme.isDark(this) ? DarkColors.textMuted     : const Color(0xFF94A3B8);
  Color get accentCol  => AppColors.accent;
  Color get accentLt   => AppTheme.isDark(this) ? AppColors.accent.withOpacity(0.15) : const Color(0xFFEEF2FF);
}

class CardListPage extends StatefulWidget {
  const CardListPage({super.key});

  @override
  State<CardListPage> createState() => _CardListPageState();
}

class _CardListPageState extends State<CardListPage> {
  final FirestoreService _service = FirestoreService();

  String _searchQuery      = '';
  CardFilter _filter       = const CardFilter();
  String _quickFilterLabel = '전체';
  final Set<String> _selectedCardIds = <String>{};
  bool _isSelectionMode = false;

  List<QueryDocumentSnapshot> _filterAndSort(List<QueryDocumentSnapshot> docs) {
    final qf = _quickFilters.firstWhere(
      (f) => f.label == _quickFilterLabel,
      orElse: () => _quickFilters.first,
    );

    List<QueryDocumentSnapshot> result = docs.where((doc) {
      final data      = doc.data() as Map<String, dynamic>;
      final name      = (data['name']      ?? '') as String;
      final type      = (data['type']      ?? '') as String;
      final subType   = (data['subType']   ?? '') as String;
      final attribute = (data['attribute'] ?? '') as String;
      final location  = (data['location']  ?? '') as String;
      final race      = (data['race']      ?? '') as String;
      final level     = (data['level']     ?? 0)  as int;
      final desc      = (data['desc']      ?? '') as String;
      final memo      = (data['memo']      ?? '') as String;

      final q = _searchQuery.toLowerCase();
      if (!name.toLowerCase().contains(q) &&
          !desc.toLowerCase().contains(q) &&
          !memo.toLowerCase().contains(q)) return false;

      if (_quickFilterLabel != '전체') {
        if (qf.type    != null && type    != qf.type)    return false;
        if (qf.subType != null && subType != qf.subType) return false;
      }
      if (_filter.types.isNotEmpty      && !_filter.types.contains(type))           return false;
      if (_filter.subTypes.isNotEmpty   && !_filter.subTypes.contains(subType))     return false;
      if (_filter.attributes.isNotEmpty && !_filter.attributes.contains(attribute)) return false;
      if (_filter.races.isNotEmpty      && !_filter.races.contains(race))           return false;
      if (_filter.levels.isNotEmpty     && !_filter.levels.contains(level))         return false;
      if (_filter.location != '전체'    && location != _filter.location)            return false;
      return true;
    }).toList();

    result.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      switch (_filter.sort) {
        case '레벨순':
          return ((bData['level'] ?? 0) as int).compareTo((aData['level'] ?? 0) as int);
        case '수량순':
          return ((bData['count'] ?? 0) as int).compareTo((aData['count'] ?? 0) as int);
        default:
          return (aData['name'] ?? '').compareTo(bData['name'] ?? '');
      }
    });
    return result;
  }

  Future<void> _changeCount(String docId, int currentCount, int delta) async {
    final newCount = (currentCount + delta).clamp(0, 99);
    await _service.updateCard(docId, {'count': newCount});
  }

  Future<void> _confirmDelete(String docId, String name) async {
    final c = context;
    final confirmed = await showDialog<bool>(
      context: c,
      builder: (_) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('카드 삭제',
            style: TextStyle(color: c.textPri, fontWeight: FontWeight.w700, fontSize: 16)),
        content: Text('"$name"을(를) 삭제하시겠습니까?',
            style: TextStyle(color: c.textSec, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text('취소', style: TextStyle(color: c.textSec)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('삭제',
                style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true) await _service.deleteCard(docId);
  }

  Future<void> _openFilter(List<String> locations) async {
    final result = await showCardFilterDialog(context, _filter, locations);
    if (result != null) setState(() => _filter = result);
  }

  void _toggleSelection(String docId) {
    setState(() {
      if (_selectedCardIds.contains(docId)) {
        _selectedCardIds.remove(docId);
        if (_selectedCardIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedCardIds.add(docId);
        _isSelectionMode = true;
      }
    });
  }

  void _toggleSelectAll(List<QueryDocumentSnapshot> cards) {
    setState(() {
      if (_selectedCardIds.length == cards.length) {
        _selectedCardIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedCardIds.clear();
        _selectedCardIds.addAll(cards.map((doc) => doc.id));
        _isSelectionMode = true;
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedCardIds.isEmpty) return;
    final c = context;
    final confirmed = await showDialog<bool>(
      context: c,
      builder: (_) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('카드 일괄 삭제',
            style: TextStyle(color: c.textPri, fontWeight: FontWeight.w700, fontSize: 16)),
        content: Text('${_selectedCardIds.length}개의 카드를 삭제하시겠습니까?',
            style: TextStyle(color: c.textSec, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text('취소', style: TextStyle(color: c.textSec)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('삭제',
                style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      for (final docId in _selectedCardIds) {
        await _service.deleteCard(docId);
      }
      setState(() {
        _selectedCardIds.clear();
        _isSelectionMode = false;
      });
    }
  }

  // ── 카드 행 빌드 ────────────────────────────────────────
  Widget _buildCardRow(QueryDocumentSnapshot doc) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    return isMobile ? _buildMobileCard(doc) : _buildDesktopCard(doc);
  }

  Widget _buildDesktopCard(QueryDocumentSnapshot doc) {
    final ctx       = context;
    final data      = doc.data() as Map<String, dynamic>;
    final name      = (data['name']      ?? '') as String;
    final type      = (data['type']      ?? '') as String;
    final subType   = (data['subType']   ?? '') as String;
    final attribute = (data['attribute'] ?? '') as String;
    final level     = (data['level']     ?? 0)  as int;
    final race      = (data['race']      ?? '') as String;
    final count     = (data['count']     ?? 1)  as int;
    final location  = (data['location']  ?? '') as String;
    final imageUrl  = (data['imageUrl']  ?? '') as String;
    final memo      = (data['memo']      ?? '') as String;
    final isExtra   = isExtraCard(subType);
    final isSharedUnowned = (data['_sharedCard'] == true) && (count == 0);

    final barColor = isSharedUnowned
        ? ctx.textMut
        : (isExtra ? subTypeColor(subType) : typeColor(type));

    return Opacity(
      opacity: isSharedUnowned ? 0.55 : 1.0,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: isSharedUnowned ? ctx.surfaceAlt : ctx.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ctx.border),
          boxShadow: isSharedUnowned
              ? null
              : [BoxShadow(color: Colors.black.withOpacity(AppTheme.isDark(ctx) ? 0.25 : 0.055),
                  blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    child: Row(
                      children: [
                        if (_isSelectionMode)
                          GestureDetector(
                            onTap: () => _toggleSelection(doc.id),
                            child: Container(
                              width: 20, height: 20,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: _selectedCardIds.contains(doc.id)
                                    ? AppColors.accent
                                    : ctx.surface,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: _selectedCardIds.contains(doc.id)
                                      ? AppColors.accent
                                      : ctx.border,
                                  width: 1.5,
                                ),
                              ),
                              child: _selectedCardIds.contains(doc.id)
                                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                                  : null,
                            ),
                          ),

                        // 카드 이미지
                        _CardImageWidget(imageUrl: imageUrl, grayscale: isSharedUnowned),
                        const SizedBox(width: 12),

                        // 이름 + 서브타입
                        Expanded(
                          flex: 28,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: () => showDialog(
                                  context: ctx,
                                  builder: (_) => CardDetailDialog(cardData: data, docId: doc.id),
                                ),
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    color: isSharedUnowned ? ctx.textMut : ctx.textPri,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                    decoration: TextDecoration.underline,
                                    decorationColor: (isSharedUnowned ? ctx.textMut : ctx.textPri).withOpacity(0.4),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Row(children: [
                                if (subType.isNotEmpty) _SubTypeTag(subType: subType),
                                if (isExtra) ...[
                                  const SizedBox(width: 4),
                                  _MiniChip(label: '엑스트라',
                                      color: const Color(0xFF1D4ED8),
                                      bg: const Color(0xFFEFF6FF)),
                                ],
                              ]),
                            ],
                          ),
                        ),

                        // 속성
                        Expanded(
                          flex: 9,
                          child: attribute.isNotEmpty
                              ? Center(child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isSharedUnowned ? ctx.surfaceAlt : attributeBgColor(attribute),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(attribute,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isSharedUnowned ? ctx.textMut : attributeColor(attribute),
                                      fontWeight: FontWeight.w700),
                                    textAlign: TextAlign.center),
                                ))
                              : Center(child: Text('–', style: TextStyle(color: ctx.textMut, fontSize: 13))),
                        ),

                        // 레벨
                        Expanded(
                          flex: 7,
                          child: Center(
                            child: level > 0
                                ? Row(mainAxisSize: MainAxisSize.min, children: [
                                    const Text('★', style: TextStyle(color: Color(0xFFD97706), fontSize: 11)),
                                    Text('$level', style: const TextStyle(
                                        color: Color(0xFFD97706), fontSize: 12, fontWeight: FontWeight.w800)),
                                  ])
                                : Text('–', style: TextStyle(color: ctx.textMut, fontSize: 13)),
                          ),
                        ),

                        // 타입
                        Expanded(
                          flex: 10,
                          child: Center(child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSharedUnowned ? ctx.surfaceAlt : typeBgColor(type),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(type,
                              style: TextStyle(
                                color: isSharedUnowned ? ctx.textMut : typeColor(type),
                                fontSize: 11, fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center),
                          )),
                        ),

                        // 종족
                        Expanded(
                          flex: 14,
                          child: Text(race.isNotEmpty ? race : '–',
                            style: TextStyle(color: ctx.textSec, fontSize: 12),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis),
                        ),

                        // 수량
                        Expanded(
                          flex: 14,
                          child: _CountControl(
                            count: count,
                            isSharedUnowned: isSharedUnowned,
                            onDecrement: () => _changeCount(doc.id, count, -1),
                            onIncrement: () => _changeCount(doc.id, count, 1),
                          ),
                        ),

                        // 위치
                        Expanded(
                          flex: 9,
                          child: Center(child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                            decoration: BoxDecoration(
                              color: ctx.surfaceAlt,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(location.isNotEmpty ? location : '–',
                              style: TextStyle(color: ctx.textSec, fontSize: 11, fontWeight: FontWeight.w500),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis),
                          )),
                        ),

                        // 메모
                        if (memo.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Tooltip(
                            message: memo,
                            child: Container(
                              width: 22, height: 22,
                              decoration: BoxDecoration(color: ctx.surfaceAlt, borderRadius: BorderRadius.circular(5)),
                              child: Icon(Icons.sticky_note_2_outlined, size: 12, color: ctx.textMut),
                            ),
                          ),
                        ],
                        const SizedBox(width: 10),

                        // 수정/삭제
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          _ActionBtn(
                            icon: Icons.edit_outlined,
                            color: AppColors.accent,
                            bg: AppTheme.isDark(ctx) ? AppColors.accent.withOpacity(0.15) : const Color(0xFFEEF2FF),
                            onTap: () => Navigator.push(ctx,
                              MaterialPageRoute(builder: (_) => EditCardPage(docId: doc.id, data: data))),
                          ),
                          const SizedBox(width: 6),
                          _ActionBtn(
                            icon: Icons.delete_outline_rounded,
                            color: const Color(0xFFEF4444),
                            bg: AppTheme.isDark(ctx) ? const Color(0xFFEF4444).withOpacity(0.15) : const Color(0xFFFEF2F2),
                            onTap: () => _confirmDelete(doc.id, name),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileCard(QueryDocumentSnapshot doc) {
    final ctx       = context;
    final data      = doc.data() as Map<String, dynamic>;
    final name      = (data['name']      ?? '') as String;
    final type      = (data['type']      ?? '') as String;
    final subType   = (data['subType']   ?? '') as String;
    final attribute = (data['attribute'] ?? '') as String;
    final level     = (data['level']     ?? 0)  as int;
    final race      = (data['race']      ?? '') as String;
    final count     = (data['count']     ?? 1)  as int;
    final location  = (data['location']  ?? '') as String;
    final imageUrl  = (data['imageUrl']  ?? '') as String;
    final memo      = (data['memo']      ?? '') as String;
    final isExtra   = isExtraCard(subType);
    final isSharedUnowned = (data['_sharedCard'] == true) && (count == 0);
    final cardColor = isSharedUnowned ? ctx.textMut
        : (isExtra ? subTypeColor(subType) : typeColor(type));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSharedUnowned ? ctx.surfaceAlt : ctx.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ctx.border),
        boxShadow: isSharedUnowned
            ? null
            : [BoxShadow(color: Colors.black.withOpacity(AppTheme.isDark(ctx) ? 0.25 : 0.055),
                blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
              ),
            ),
            if (_isSelectionMode)
              GestureDetector(
                onTap: () => _toggleSelection(doc.id),
                child: Container(
                  width: 24, height: 24,
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    color: _selectedCardIds.contains(doc.id) ? AppColors.accent : ctx.surface,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _selectedCardIds.contains(doc.id) ? AppColors.accent : ctx.border,
                      width: 1.5,
                    ),
                  ),
                  child: _selectedCardIds.contains(doc.id)
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : null,
                ),
              ),
            Container(
              width: 60, height: 84,
              margin: const EdgeInsets.only(left: 4, right: 12, top: 12, bottom: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: imageUrl.isNotEmpty
                    ? _FallbackNetworkImage(url: imageUrl, width: 60, height: 84,
                        fit: BoxFit.cover, grayscale: isSharedUnowned)
                    : Container(color: ctx.surfaceAlt,
                        child: Icon(Icons.image_not_supported, color: ctx.textMut, size: 20)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => showDialog(
                        context: ctx,
                        builder: (_) => CardDetailDialog(cardData: data, docId: doc.id),
                      ),
                      child: Text(name,
                        style: TextStyle(
                          color: isSharedUnowned ? ctx.textMut : ctx.textPri,
                          fontWeight: FontWeight.w700, fontSize: 15,
                          decoration: TextDecoration.underline,
                          decorationColor: (isSharedUnowned ? ctx.textMut : ctx.textPri).withOpacity(0.4)),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(height: 6),
                    Row(children: [
                      if (subType.isNotEmpty)
                        _MobileTag(label: subType, color: cardColor),
                      if (isExtra) ...[
                        const SizedBox(width: 6),
                        _MobileTag(label: '엑스트라', color: const Color(0xFF1D4ED8)),
                      ],
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      if (attribute.isNotEmpty)
                        _MobileInfoItem(label: '속성', value: attribute),
                      if (level > 0) ...[
                        const SizedBox(width: 12),
                        _MobileInfoItem(label: '레벨', value: '★$level'),
                      ],
                      if (race.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        _MobileInfoItem(label: '종족', value: race),
                      ],
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSharedUnowned ? ctx.surfaceAlt : typeBgColor(type),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('$count장',
                          style: TextStyle(
                            color: isSharedUnowned ? ctx.textMut : typeColor(type),
                            fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      if (location.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: ctx.surfaceAlt, borderRadius: BorderRadius.circular(6)),
                          child: Text(location,
                            style: TextStyle(color: ctx.textSec, fontSize: 11, fontWeight: FontWeight.w500),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      const Spacer(),
                      if (memo.isNotEmpty) ...[
                        Tooltip(
                          message: memo,
                          child: Container(
                            width: 24, height: 24,
                            decoration: BoxDecoration(color: ctx.surfaceAlt, borderRadius: BorderRadius.circular(4)),
                            child: Icon(Icons.sticky_note_2_outlined, size: 14, color: ctx.textMut),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      _MobileActionButton(
                        icon: Icons.edit_outlined, color: AppColors.accent,
                        onTap: () => Navigator.push(ctx,
                          MaterialPageRoute(builder: (_) => EditCardPage(docId: doc.id, data: data))),
                      ),
                      const SizedBox(width: 4),
                      _MobileActionButton(
                        icon: Icons.delete_outline_rounded, color: const Color(0xFFEF4444),
                        onTap: () => _confirmDelete(doc.id, name),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    return Scaffold(
      backgroundColor: ctx.bg,
      body: StreamBuilder<QuerySnapshot>(
        stream: _service.getCards(),
        builder: (context, snapshot) {
          final allDocs = snapshot.hasData ? snapshot.data!.docs : <QueryDocumentSnapshot>[];

          final locations = allDocs
              .map((d) => ((d.data() as Map<String, dynamic>)['location'] ?? '') as String)
              .where((l) => l.isNotEmpty)
              .toSet()
              .toList()
            ..sort();

          final result     = _filterAndSort(allDocs);
          final totalCount = result.fold<int>(0, (sum, doc) {
            final d = doc.data() as Map<String, dynamic>;
            return sum + ((d['count'] ?? 0) as int);
          });

          return Column(
            children: [
              _Header(
                locations: locations,
                filter: _filter,
                searchQuery: _searchQuery,
                isSelectionMode: _isSelectionMode,
                selectedCount: _selectedCardIds.length,
                resultCount: result.length,
                onSearchChanged: (v) => setState(() => _searchQuery = v),
                onFilterTap: () => _openFilter(locations),
                onFilterClear: () => setState(() => _filter = const CardFilter()),
                onSelectModeToggle: () => setState(() => _isSelectionMode = true),
                onSelectAll: () => _toggleSelectAll(result),
                onDeleteSelected: _deleteSelected,
                onSelectModeCancel: () => setState(() {
                  _selectedCardIds.clear();
                  _isSelectionMode = false;
                }),
              ),
              _QuickFilterBar(
                filters: _quickFilters,
                selected: _quickFilterLabel,
                onSelect: (label) => setState(() => _quickFilterLabel = label),
              ),
              _TableHeader(),
              Expanded(
                child: !snapshot.hasData
                    ? Center(child: CircularProgressIndicator(color: ctx.accentCol, strokeWidth: 2.5))
                    : result.isEmpty
                        ? _EmptyState(hasAnyCard: allDocs.isNotEmpty)
                        : Column(children: [
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
                                itemCount: result.length,
                                itemBuilder: (context, index) => _buildCardRow(result[index]),
                              ),
                            ),
                            _Footer(cardCount: result.length, totalCount: totalCount),
                          ]),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Fallback 네트워크 이미지 ─────────────────────────────────
class _FallbackNetworkImage extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool grayscale;

  const _FallbackNetworkImage({
    required this.url, this.width, this.height,
    this.fit = BoxFit.cover, this.grayscale = false,
  });

  @override
  State<_FallbackNetworkImage> createState() => _FallbackNetworkImageState();
}

class _FallbackNetworkImageState extends State<_FallbackNetworkImage> {
  int _index = 0;
  late List<String> _candidates;

  @override
  void initState() {
    super.initState();
    _candidates = _buildCandidates(widget.url);
  }

  List<String> _buildCandidates(String url) {
    if (url.isEmpty) return [];
    try {
      final uri     = Uri.parse(url);
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
    final ctx = context;
    if (_candidates.isEmpty || _index >= _candidates.length) return _placeholder(ctx);
    Widget img = Image.network(
      _candidates[_index],
      width: widget.width, height: widget.height, fit: widget.fit,
      loadingBuilder: (_, child, progress) => progress == null ? child : _loading(ctx),
      errorBuilder: (_, __, ___) {
        if (_index < _candidates.length - 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _index++);
          });
          return _loading(ctx);
        }
        return _placeholder(ctx);
      },
    );
    if (widget.grayscale) return Opacity(opacity: 0.35, child: img);
    return img;
  }

  Widget _loading(BuildContext ctx) => Container(
    width: widget.width, height: widget.height, color: ctx.surfaceAlt,
    child: Center(child: SizedBox(width: 14, height: 14,
        child: CircularProgressIndicator(strokeWidth: 1.5, color: ctx.textMut))),
  );

  Widget _placeholder(BuildContext ctx) => Container(
    width: widget.width, height: widget.height, color: ctx.surfaceAlt,
    child: Icon(Icons.image_not_supported, color: ctx.textMut, size: 18),
  );
}

// ── 카드 이미지 위젯 ─────────────────────────────────────────
class _CardImageWidget extends StatelessWidget {
  final String imageUrl;
  final bool grayscale;
  const _CardImageWidget({required this.imageUrl, this.grayscale = false});

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) return _NoImagePlaceholder();
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: _FallbackNetworkImage(
        url: imageUrl, width: 30, height: 43, fit: BoxFit.cover, grayscale: grayscale),
    );
  }
}

class _NoImagePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ctx = context;
    return Container(
      width: 30, height: 43,
      decoration: BoxDecoration(
        color: ctx.surfaceAlt,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: ctx.border),
      ),
      child: Icon(Icons.style_outlined, size: 13, color: ctx.textMut),
    );
  }
}

// ── 헤더 ─────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final List<String> locations;
  final CardFilter filter;
  final String searchQuery;
  final bool isSelectionMode;
  final int selectedCount;
  final int resultCount;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onFilterTap;
  final VoidCallback onFilterClear;
  final VoidCallback onSelectModeToggle;
  final VoidCallback onSelectAll;
  final VoidCallback onDeleteSelected;
  final VoidCallback onSelectModeCancel;

  const _Header({
    required this.locations, required this.filter, required this.searchQuery,
    required this.isSelectionMode, required this.selectedCount, required this.resultCount,
    required this.onSearchChanged, required this.onFilterTap, required this.onFilterClear,
    required this.onSelectModeToggle, required this.onSelectAll,
    required this.onDeleteSelected, required this.onSelectModeCancel,
  });

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    final hasFilter = filter.activeCount > 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      decoration: BoxDecoration(
        color: ctx.surface,
        border: Border(bottom: BorderSide(color: ctx.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: ctx.accentLt, borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.style_rounded, size: 20, color: ctx.accentCol),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('카드 관리', style: TextStyle(
                    color: ctx.textPri, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.8)),
                  Text('보유 카드를 관리하세요', style: TextStyle(color: ctx.textSec, fontSize: 12.5)),
                ],
              ),
              const Spacer(),
              if (isSelectionMode) ...[
                OutlinedButton.icon(
                  onPressed: onSelectAll,
                  icon: Icon(Icons.select_all_rounded, size: 15, color: ctx.textSec),
                  label: Text(selectedCount == resultCount ? '전체 해제' : '전체 선택',
                      style: TextStyle(color: ctx.textSec, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: ctx.border),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: selectedCount == 0 ? null : onDeleteSelected,
                  icon: const Icon(Icons.delete_rounded, size: 15),
                  label: Text('삭제 ($selectedCount)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selectedCount == 0 ? ctx.surfaceAlt : const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: onSelectModeCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ctx.textSec,
                    side: BorderSide(color: ctx.border),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('취소', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: ctx.textSec)),
                ),
              ] else ...[
                OutlinedButton.icon(
                  onPressed: onSelectModeToggle,
                  icon: Icon(Icons.checklist_rounded, size: 15, color: ctx.textSec),
                  label: Text('선택 모드',
                      style: TextStyle(color: ctx.textSec, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: ctx.border),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () => showCardIOSheet(context),
                  icon: Icon(Icons.swap_vert_rounded, size: 15, color: ctx.textSec),
                  label: Text('내보내기 / 가져오기',
                      style: TextStyle(color: ctx.textSec, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: ctx.border),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AddCardPage())),
                  icon: const Icon(Icons.add_rounded, size: 17),
                  label: const Text('카드 추가'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent, foregroundColor: Colors.white,
                    elevation: 0, textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: ctx.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ctx.border),
                  ),
                  child: TextField(
                    style: TextStyle(color: ctx.textPri, fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText: '카드 이름/효과 검색...',
                      hintStyle: TextStyle(color: ctx.textMut, fontSize: 13.5),
                      prefixIcon: Icon(Icons.search_rounded, color: ctx.textMut, size: 17),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: onSearchChanged,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onFilterTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: hasFilter ? AppColors.accent : ctx.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: hasFilter ? AppColors.accent : ctx.border),
                  ),
                  child: Row(children: [
                    Icon(Icons.tune_rounded, size: 15,
                        color: hasFilter ? Colors.white : ctx.textSec),
                    const SizedBox(width: 6),
                    Text(
                      hasFilter ? '상세필터 ${filter.activeCount}개' : '상세 필터',
                      style: TextStyle(
                        color: hasFilter ? Colors.white : ctx.textSec,
                        fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ]),
                ),
              ),
              if (hasFilter) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onFilterClear,
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: ctx.surfaceAlt, borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ctx.border)),
                    child: Icon(Icons.close_rounded, size: 15, color: ctx.textSec),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── 빠른 필터 바 ─────────────────────────────────────────────
class _QuickFilterBar extends StatelessWidget {
  final List<_QuickFilter> filters;
  final String selected;
  final ValueChanged<String> onSelect;

  const _QuickFilterBar({required this.filters, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    final isDark = AppTheme.isDark(ctx);
    return Container(
      width: double.infinity,
      color: isDark ? DarkColors.surfaceAlt : const Color(0xFFF1F5F9),
      padding: const EdgeInsets.only(left: 24, top: 10, bottom: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: filters.map((qf) {
            final isSelected = selected == qf.label;
            final isXyz = qf.label == '엑시즈';
            return Padding(
              padding: const EdgeInsets.only(right: 7),
              child: GestureDetector(
                onTap: () => onSelect(qf.label),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isXyz ? qf.bgColor : (isDark ? qf.color.withOpacity(0.2) : qf.bgColor))
                        : ctx.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? (isXyz ? qf.color : qf.bgColor)
                          : ctx.border,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    qf.label,
                    style: TextStyle(
                      color: isSelected
                          ? (isXyz ? Colors.white : qf.color)
                          : ctx.textSec,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── 테이블 헤더 ──────────────────────────────────────────────
class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ctx = context;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 9),
      decoration: BoxDecoration(
        color: ctx.surfaceAlt,
        border: Border(
          top: BorderSide(color: ctx.border),
          bottom: BorderSide(color: ctx.border),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 50),
          _H('이름', flex: 28),
          _H('속성', flex: 9),
          _H('레벨', flex: 7),
          _H('타입', flex: 10),
          _H('종족', flex: 14),
          _H('수량', flex: 14),
          _H('위치', flex: 9),
          const SizedBox(width: 76),
        ],
      ),
    );
  }
}

class _H extends StatelessWidget {
  final String label;
  final int flex;
  const _H(this.label, {required this.flex});

  @override
  Widget build(BuildContext context) => Expanded(
    flex: flex,
    child: Text(label,
      style: TextStyle(color: context.textMut, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.4),
      textAlign: TextAlign.center),
  );
}

// ── 수량 컨트롤 ──────────────────────────────────────────────
class _CountControl extends StatelessWidget {
  final int count;
  final bool isSharedUnowned;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _CountControl({
    required this.count, required this.isSharedUnowned,
    required this.onDecrement, required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SmallIconBtn(icon: Icons.remove, enabled: count > 0, onTap: onDecrement),
        Container(
          width: 28, alignment: Alignment.center,
          child: Text('$count',
            style: TextStyle(
              color: isSharedUnowned ? ctx.textMut : ctx.textPri,
              fontWeight: FontWeight.w800, fontSize: 13)),
        ),
        _SmallIconBtn(icon: Icons.add, enabled: count < 99, onTap: onIncrement),
      ],
    );
  }
}

class _SmallIconBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _SmallIconBtn({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 22, height: 22,
        decoration: BoxDecoration(
          color: enabled ? ctx.surfaceAlt : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: enabled ? ctx.border : ctx.borderLight)),
        child: Icon(icon, size: 12, color: enabled ? ctx.textSec : ctx.textMut),
      ),
    );
  }
}

// ── 액션 버튼 ─────────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  const _ActionBtn({required this.icon, required this.color, required this.bg, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 30, height: 30,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Icon(icon, size: 15, color: color),
    ),
  );
}

// ── 미니 칩 ──────────────────────────────────────────────────
class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;

  const _MiniChip({required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
    child: Text(label, style: TextStyle(fontSize: 9.5, color: color, fontWeight: FontWeight.w700)),
  );
}

// ── 서브타입 태그 ─────────────────────────────────────────────
class _SubTypeTag extends StatelessWidget {
  final String subType;
  const _SubTypeTag({required this.subType});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: subTypeBgColor(subType),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: subTypeColor(subType).withOpacity(0.25)),
    ),
    child: Text(subType,
      style: TextStyle(fontSize: 10, color: subTypeTextColor(subType), fontWeight: FontWeight.w700)),
  );
}

// ── 모바일 전용 위젯들 ────────────────────────────────────────
class _MobileTag extends StatelessWidget {
  final String label;
  final Color color;
  const _MobileTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
  );
}

class _MobileInfoItem extends StatelessWidget {
  final String label;
  final String value;
  const _MobileInfoItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: ctx.textMut, fontSize: 9, fontWeight: FontWeight.w600)),
        const SizedBox(height: 1),
        Text(value, style: TextStyle(color: ctx.textPri, fontSize: 11, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _MobileActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _MobileActionButton({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Icon(icon, size: 14, color: color),
    ),
  );
}

// ── 빈 상태 ──────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool hasAnyCard;
  const _EmptyState({required this.hasAnyCard});

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(color: ctx.accentLt, borderRadius: BorderRadius.circular(16)),
            child: Icon(Icons.style_outlined, size: 28, color: ctx.accentCol),
          ),
          const SizedBox(height: 14),
          Text(
            hasAnyCard ? '검색/필터 결과가 없습니다' : '카드를 추가해보세요',
            style: TextStyle(color: ctx.textSec, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            hasAnyCard ? '다른 조건으로 검색해 보세요' : '우측 상단 버튼으로 카드를 등록하세요',
            style: TextStyle(color: ctx.textMut, fontSize: 12.5)),
        ],
      ),
    );
  }
}

// ── 하단 푸터 ─────────────────────────────────────────────────
class _Footer extends StatelessWidget {
  final int cardCount;
  final int totalCount;
  const _Footer({required this.cardCount, required this.totalCount});

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
      decoration: BoxDecoration(
        color: ctx.surface,
        border: Border(top: BorderSide(color: ctx.border)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: ctx.accentLt, borderRadius: BorderRadius.circular(8)),
            child: Text('$cardCount종',
              style: TextStyle(color: ctx.accentCol, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 6),
          Text('카드 종류', style: TextStyle(color: ctx.textSec, fontSize: 12.5)),
          const Spacer(),
          Text('총 수량', style: TextStyle(color: ctx.textSec, fontSize: 12.5)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: ctx.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ctx.border),
            ),
            child: Text('$totalCount장',
              style: TextStyle(color: ctx.textPri, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}