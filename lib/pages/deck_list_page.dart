// lib/pages/deck_list_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/deck_model.dart';
import '../services/deck_service.dart';
import '../main.dart' show AppColors, DarkColors, AppTheme;
import 'deck_detail_page.dart';
import '../widgets/deck_share_dialog.dart';

// ── 덱 색상 팔레트 ────────────────────────────────────────────
class DeckPalette {
  final int value;
  final String label;
  const DeckPalette(this.value, this.label);
}

const kDeckColors = [
  DeckPalette(0xFF22C55E, '초록'), DeckPalette(0xFF3B82F6, '파랑'),
  DeckPalette(0xFFA855F7, '보라'), DeckPalette(0xFFE8823A, '주황'),
  DeckPalette(0xFFEF4444, '빨강'), DeckPalette(0xFFEC4899, '분홍'),
  DeckPalette(0xFF06B6D4, '하늘'), DeckPalette(0xFF84CC16, '연두'),
  DeckPalette(0xFFF59E0B, '노랑'), DeckPalette(0xFF6366F1, '인디고'),
  DeckPalette(0xFF14B8A6, '청록'), DeckPalette(0xFF64748B, '회색'),
];

Color _deckColor(int value)  => Color(value);
Color _deckBg(int value)     => Color(value).withOpacity(0.12);
Color _deckBorder(int value) => Color(value).withOpacity(0.35);

// ── 테마 헬퍼 ────────────────────────────────────────────────
extension _T on BuildContext {
  bool   get isDark    => AppTheme.isDark(this);
  Color  get surface   => AppTheme.surface(this);
  Color  get surfaceAlt=> AppTheme.surfaceAlt(this);
  Color  get bg        => AppTheme.bg(this);
  Color  get border    => AppTheme.border(this);
  Color  get textPri   => AppTheme.textPrimary(this);
  Color  get textSec   => AppTheme.textSecondary(this);
  Color  get textMut   => AppTheme.textMuted(this);
  Color  get accentLt  => isDark ? AppColors.accent.withOpacity(0.15) : AppColors.accentLight;
}

// ── 색상 선택 위젯 ────────────────────────────────────────────
class _ColorPicker extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;
  const _ColorPicker({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10, runSpacing: 10,
      children: kDeckColors.map((p) {
        final isSelected = selected == p.value;
        return GestureDetector(
          onTap: () => onSelect(p.value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: Color(p.value), shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent, width: 2.5),
              boxShadow: isSelected
                  ? [BoxShadow(color: Color(p.value).withOpacity(0.55), blurRadius: 8, spreadRadius: 1)]
                  : [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 3, offset: const Offset(0, 1))],
            ),
            child: isSelected
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                : null,
          ),
        );
      }).toList(),
    );
  }
}

// ── 대표 이미지 선택 ──────────────────────────────────────────
class _CoverImagePicker extends StatelessWidget {
  final List<Map<String, dynamic>> cardDataList;
  final String? selectedImageUrl;
  final ValueChanged<String?> onSelect;

  const _CoverImagePicker({
    required this.cardDataList, required this.selectedImageUrl, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    if (cardDataList.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ctx.surfaceAlt, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ctx.border)),
        child: Center(child: Text(
          '덱에 카드를 추가하면 대표 이미지를 선택할 수 있습니다',
          style: TextStyle(color: ctx.textMut, fontSize: 11), textAlign: TextAlign.center)),
      );
    }

    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: cardDataList.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            final isSelected = selectedImageUrl == null || selectedImageUrl!.isEmpty;
            return GestureDetector(
              onTap: () => onSelect(null),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 58, margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: isSelected ? ctx.accentLt : ctx.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? AppColors.accent : ctx.border,
                    width: isSelected ? 2 : 1)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.hide_image_outlined, size: 20,
                      color: isSelected ? AppColors.accent : ctx.textMut),
                  const SizedBox(height: 4),
                  Text('없음', style: TextStyle(
                    fontSize: 9, color: isSelected ? AppColors.accent : ctx.textMut,
                    fontWeight: FontWeight.w600)),
                ]),
              ),
            );
          }
          final card     = cardDataList[i - 1];
          final imageUrl = (card['imageUrl'] ?? '') as String;
          if (imageUrl.isEmpty) return const SizedBox.shrink();
          final isSelected = selectedImageUrl == imageUrl;
          return GestureDetector(
            onTap: () => onSelect(imageUrl),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 58, margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? AppColors.accent : ctx.border,
                  width: isSelected ? 2.5 : 1),
                boxShadow: isSelected
                    ? [BoxShadow(color: AppColors.accent.withOpacity(0.35), blurRadius: 8)]
                    : null),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.network(imageUrl, width: 58, height: 90, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: ctx.surfaceAlt,
                    child: Icon(Icons.broken_image_outlined, color: ctx.textMut, size: 20))),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── 덱 생성/수정 다이얼로그 ───────────────────────────────────
Future<({String name, int color, String coverImageUrl})?> _showDeckDialog(
  BuildContext context, {
  String initialName = '', int initialColor = Deck.defaultColor,
  String initialCoverImageUrl = '', bool isEdit = false, String deckId = '',
}) async {
  final ctrl       = TextEditingController(text: initialName);
  int pickedColor  = initialColor;
  String? pickedImageUrl = initialCoverImageUrl.isEmpty ? null : initialCoverImageUrl;

  List<Map<String, dynamic>> deckCards = [];
  if (deckId.isNotEmpty) {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final deckSnap = await FirebaseFirestore.instance
            .collection('users').doc(uid).collection('decks').doc(deckId).get();
        final cardIds   = List<String>.from((deckSnap.data()?['cardIds'] ?? []) as List);
        final uniqueIds = cardIds.toSet().toList();
        if (uniqueIds.isNotEmpty) {
          final cardsSnap = await FirebaseFirestore.instance
              .collection('users').doc(uid).collection('cards')
              .where(FieldPath.documentId, whereIn: uniqueIds).get();
          deckCards = cardsSnap.docs
              .map((d) {
                final data = d.data();
                return {'name': data['name'] ?? '', 'imageUrl': data['imageUrl'] ?? ''};
              })
              .where((c) => (c['imageUrl'] as String).isNotEmpty)
              .toList();
          if ((pickedImageUrl == null || pickedImageUrl!.isEmpty) && deckCards.isNotEmpty) {
            pickedImageUrl = deckCards.first['imageUrl'] as String;
          }
        }
      }
    } catch (_) {}
  }

  return showDialog<({String name, int color, String coverImageUrl})>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setInner) {
        final surface    = AppTheme.surface(ctx);
        final surfaceAlt = AppTheme.surfaceAlt(ctx);
        final border     = AppTheme.border(ctx);
        final textPri    = AppTheme.textPrimary(ctx);
        final textMut    = AppTheme.textMuted(ctx);

        return AlertDialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isEdit ? '덱 수정' : '새 덱 생성',
              style: TextStyle(color: textPri, fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    style: TextStyle(color: textPri),
                    decoration: InputDecoration(
                      hintText: '덱 이름 입력',
                      hintStyle: TextStyle(color: textMut),
                      filled: true, fillColor: surfaceAlt,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.accent)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('덱 색상', style: TextStyle(color: AppTheme.textSecondary(ctx),
                      fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  _ColorPicker(selected: pickedColor, onSelect: (v) => setInner(() => pickedColor = v)),
                  if (deckCards.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text('대표 카드 이미지', style: TextStyle(color: AppTheme.textSecondary(ctx),
                        fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    _CoverImagePicker(
                      cardDataList: deckCards,
                      selectedImageUrl: pickedImageUrl,
                      onSelect: (url) => setInner(() => pickedImageUrl = url),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('취소', style: TextStyle(color: AppTheme.textSecondary(ctx))),
            ),
            ElevatedButton(
              onPressed: () {
                final name = ctrl.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(ctx, (name: name, color: pickedColor, coverImageUrl: pickedImageUrl ?? ''));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(pickedColor), foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(isEdit ? '수정 완료' : '생성', style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    ),
  );
}

// ── 메인 페이지 ──────────────────────────────────────────────
class DeckListPage extends StatelessWidget {
  final service = DeckService();
  DeckListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    return Scaffold(
      backgroundColor: ctx.bg,
      body: Column(
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
            decoration: BoxDecoration(
              color: ctx.surface,
              border: Border(bottom: BorderSide(color: ctx.border)),
            ),
            child: Row(
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('덱 관리', style: TextStyle(
                    color: ctx.textPri, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                  const SizedBox(height: 2),
                  Text('나만의 덱을 구성하세요', style: TextStyle(color: ctx.textSec, fontSize: 13)),
                ]),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () => showDeckLoadDialog(ctx),
                  icon: Icon(Icons.download_for_offline_rounded, size: 16, color: ctx.textSec),
                  label: Text('코드로 불러오기',
                      style: TextStyle(fontWeight: FontWeight.w600, color: ctx.textSec)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: ctx.border),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => _addDeck(ctx),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('덱 생성', style: TextStyle(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.magic, foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder(
              stream: service.getDecks(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator(color: AppColors.accent));
                }
                final decks = snapshot.data!;
                if (decks.isEmpty) {
                  return Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          color: ctx.isDark
                              ? AppColors.magic.withOpacity(0.15)
                              : AppColors.magicBg,
                          borderRadius: BorderRadius.circular(16)),
                        child: const Icon(Icons.view_list_rounded, size: 32, color: AppColors.magic),
                      ),
                      const SizedBox(height: 16),
                      Text('덱을 생성해보세요',
                          style: TextStyle(color: ctx.textSec, fontSize: 16, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Text('우측 상단 버튼으로 새 덱을 만들 수 있습니다',
                          style: TextStyle(color: ctx.textMut, fontSize: 13)),
                    ]),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(28),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 300, mainAxisExtent: 160,
                    crossAxisSpacing: 16, mainAxisSpacing: 16),
                  itemCount: decks.length,
                  itemBuilder: (context, index) {
                    final deck = decks[index];
                    return _DeckCard(
                      deck: deck,
                      onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => DeckDetailPage(deck: deck))),
                      onEdit: () => _editDeck(context, deck),
                      onShare: () => showDeckShareDialog(context, deck: deck),
                      onCopy: () => _copyDeck(context, deck),
                      onDelete: () => _confirmDelete(context, deck.id, deck.name),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addDeck(BuildContext context) async {
    final result = await _showDeckDialog(context);
    if (result != null) {
      await service.addDeck(result.name, color: result.color, coverImageUrl: result.coverImageUrl);
    }
  }

  Future<void> _editDeck(BuildContext context, Deck deck) async {
    final result = await _showDeckDialog(context,
      initialName: deck.name, initialColor: deck.color,
      initialCoverImageUrl: deck.coverImageUrl, isEdit: true, deckId: deck.id);
    if (result != null) {
      await service.updateDeck(deck.id,
        name: result.name, color: result.color, coverImageUrl: result.coverImageUrl);
    }
  }

  Future<void> _copyDeck(BuildContext context, Deck deck) async {
    final ctrl = TextEditingController(text: '${deck.name} (복사)');
    final ctx  = context;
    final newName = await showDialog<String>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: ctx.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('덱 복사', style: TextStyle(color: ctx.textPri, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl, autofocus: true,
          style: TextStyle(color: ctx.textPri),
          decoration: InputDecoration(
            hintText: '새 덱 이름', hintStyle: TextStyle(color: ctx.textMut),
            filled: true, fillColor: ctx.surfaceAlt,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: ctx.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: ctx.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.accent)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
            child: Text('취소', style: TextStyle(color: ctx.textSec))),
          ElevatedButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) Navigator.pop(ctx, name);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0EA5E9), foregroundColor: Colors.white,
              elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('복사', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (newName != null) await service.copyDeck(deck, newName);
  }

  Future<void> _confirmDelete(BuildContext context, String id, String name) async {
    final ctx = context;
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: ctx.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('덱 삭제', style: TextStyle(color: ctx.textPri, fontWeight: FontWeight.w700)),
        content: Text('"$name" 덱을 삭제하시겠습니까?', style: TextStyle(color: ctx.textSec)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: Text('취소', style: TextStyle(color: ctx.textSec))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (confirmed == true) await service.deleteDeckWithRestore(id);
  }
}

// ── 덱 카드 위젯 ──────────────────────────────────────────────
class _DeckCard extends StatefulWidget {
  final Deck deck;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onShare;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  const _DeckCard({
    required this.deck, required this.onTap, required this.onEdit,
    required this.onShare, required this.onCopy, required this.onDelete,
  });

  @override
  State<_DeckCard> createState() => _DeckCardState();
}

class _DeckCardState extends State<_DeckCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final ctx         = context;
    final color       = _deckColor(widget.deck.color);
    final bgColor     = _deckBg(widget.deck.color);
    final borderColor = _deckBorder(widget.deck.color);
    final hasCover    = widget.deck.coverImageUrl.isNotEmpty;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: ctx.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _hovered ? borderColor : ctx.border, width: _hovered ? 1.5 : 1),
            boxShadow: [BoxShadow(
              color: _hovered
                  ? color.withOpacity(0.15)
                  : Colors.black.withOpacity(ctx.isDark ? 0.3 : 0.04),
              blurRadius: _hovered ? 14 : 6,
              offset: const Offset(0, 2))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Stack(
              children: [
                if (hasCover)
                  Positioned.fill(
                    child: Row(children: [
                      const Spacer(flex: 3),
                      Expanded(flex: 2,
                        child: ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            begin: Alignment.centerLeft, end: Alignment.centerRight,
                            colors: [Colors.transparent,
                              Colors.white.withOpacity(0.18), Colors.white.withOpacity(0.38)],
                            stops: const [0.0, 0.3, 1.0],
                          ).createShader(bounds),
                          blendMode: BlendMode.dstIn,
                          child: Image.network(widget.deck.coverImageUrl,
                            fit: BoxFit.cover, height: double.infinity,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                        )),
                    ]),
                  ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderColor),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: hasCover
                                ? Image.network(widget.deck.coverImageUrl, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _defaultIcon(bgColor, color))
                                : _defaultIcon(bgColor, color),
                          ),
                        ),
                        const Spacer(),
                        _IconBtn(icon: Icons.edit_rounded,
                            color: AppColors.accent,
                            bgColor: ctx.isDark ? AppColors.accent.withOpacity(0.15) : AppColors.accentLight,
                            onTap: widget.onEdit, tooltip: '덱 수정'),
                        const SizedBox(width: 5),
                        _IconBtn(icon: Icons.share_rounded, color: color, bgColor: bgColor,
                            onTap: widget.onShare, tooltip: '공유'),
                        const SizedBox(width: 5),
                        _IconBtn(icon: Icons.copy_rounded,
                            color: const Color(0xFF0EA5E9),
                            bgColor: ctx.isDark
                                ? const Color(0xFF0EA5E9).withOpacity(0.15)
                                : const Color(0xFFE0F2FE),
                            onTap: widget.onCopy, tooltip: '복사'),
                        const SizedBox(width: 5),
                        _IconBtn(icon: Icons.delete_outline,
                            color: Colors.redAccent,
                            bgColor: ctx.isDark
                                ? Colors.redAccent.withOpacity(0.15)
                                : const Color(0xFFFEE2E2),
                            onTap: widget.onDelete, tooltip: '삭제'),
                      ]),

                      const Spacer(),

                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: Container(height: 3, width: 28, color: color),
                      ),
                      const SizedBox(height: 8),
                      Text(widget.deck.name,
                        style: TextStyle(color: ctx.textPri, fontSize: 15, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis, maxLines: 1),
                      const SizedBox(height: 4),
                      Row(children: [
                        Text('카드 ${widget.deck.cardIds.length}장',
                          style: TextStyle(color: ctx.textSec, fontSize: 12)),
                        const Spacer(),
                        Container(width: 8, height: 8,
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        Text(
                          kDeckColors.where((p) => p.value == widget.deck.color)
                              .firstOrNull?.label ?? '',
                          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _defaultIcon(Color bg, Color fg) => Container(
    color: bg, child: Icon(Icons.view_list_rounded, color: fg, size: 22));
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;
  final String tooltip;

  const _IconBtn({required this.icon, required this.color, required this.bgColor,
      required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(7)),
        child: Icon(icon, size: 14, color: color),
      ),
    ),
  );
}