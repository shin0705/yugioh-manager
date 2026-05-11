// lib/pages/deck_detail_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/deck_model.dart';
import '../services/deck_service.dart';
import '../services/yugioh_api_service.dart';
import '../main.dart' show AppColors;
import '../constants/card_constants.dart';

// ── 빠른 필터 정의 ─────────────────────────────────────────────
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
  _QuickFilter(label: '전체', color: Color(0xFF6366F1), bgColor: Color(0xFFEEF2FF)),
  _QuickFilter(label: '일반', type: '몬스터', subType: '일반', color: Color(0xFFB45309), bgColor: Color(0xFFFEF3C7)),
  _QuickFilter(label: '효과', type: '몬스터', subType: '효과', color: Color(0xFFD97706), bgColor: Color(0xFFFFF7ED)),
  _QuickFilter(label: '의식', type: '몬스터', subType: '의식', color: Color(0xFF0284C7), bgColor: Color(0xFFE0F2FE)),
  _QuickFilter(label: '융합', subType: '융합', color: Color(0xFF7C3AED), bgColor: Color(0xFFF5F3FF)),
  _QuickFilter(label: '싱크로', subType: '싱크로', color: Color(0xFF475569), bgColor: Color(0xFFF1F5F9)),
  _QuickFilter(label: '엑시즈', subType: '엑시즈', color: Color(0xFFE2E8F0), bgColor: Color(0xFF1E293B)),
  _QuickFilter(label: '링크', subType: '링크', color: Color(0xFF1D4ED8), bgColor: Color(0xFFEFF6FF)),
  _QuickFilter(label: '마법', type: '마법', color: Color(0xFF059669), bgColor: Color(0xFFECFDF5)),
  _QuickFilter(label: '함정', type: '함정', color: Color(0xFF9333EA), bgColor: Color(0xFFFAF5FF)),
];

class DeckDetailPage extends StatefulWidget {
  final Deck deck;
  const DeckDetailPage({super.key, required this.deck});

  @override
  State<DeckDetailPage> createState() => _DeckDetailPageState();
}

class _DeckDetailPageState extends State<DeckDetailPage> {
  final DeckService _deckService = DeckService();
  final YugiohApiService _api   = YugiohApiService();

  // ✅ 수정: 루트 'cards' 대신 유저별 경로 사용
  CollectionReference<Map<String, dynamic>> get _cardRef =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .collection('cards');

  String _searchQuery  = '';
  String _quickFilterLabel = '전체';
  bool   _banListLoading = true;

  // ── 낙관적 UI: 로컬에서 즉시 반영되는 상태 ────────────────
  // cardId → 로컬 보유 수량 오버라이드 (null이면 Firestore 값 사용)
  final Map<String, int> _localStockOverride = {};
  // 덱의 cardIds를 로컬에서 즉시 반영
  List<String>? _localDeckCardIds;

  // 진행 중인 작업 추적 (중복 방지)
  final Set<String> _pendingOps = {};

  @override
  void initState() {
    super.initState();
    _api.loadBanList().then((_) {
      if (mounted) setState(() => _banListLoading = false);
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ── 금제 상태 조회 ──────────────────────────────────────────
  BanStatus _getBanStatus(Map<String, dynamic> data) {
    final engName = (data['engName'] ?? '') as String;
    if (engName.isNotEmpty) {
      return _api.getBanStatusByEngName(engName);
    }
    return BanStatus.unlimited;
  }

  String _banStatusString(BanStatus s) {
    switch (s) {
      case BanStatus.forbidden:   return 'Forbidden';
      case BanStatus.limited:     return 'Limited';
      case BanStatus.semiLimited: return 'Semi-Limited';
      case BanStatus.unlimited:   return '';
    }
  }

  // ── 낙관적 카드 추가 ────────────────────────────────────────
  void _addCard(
    String cardId,
    Map<String, dynamic> cardData,
    Deck currentDeck,
    Map<String, QueryDocumentSnapshot> docById,
  ) async {
    if (_pendingOps.contains('add_$cardId')) return;
    _pendingOps.add('add_$cardId');

    final banStatus    = _getBanStatus(cardData);
    final localCardIds = _localDeckCardIds ?? List<String>.from(currentDeck.cardIds);
    final localStock   = _localStockOverride[cardId] ??
        ((cardData['count'] ?? 0) as int);

    if (banStatus == BanStatus.forbidden) {
      _pendingOps.remove('add_$cardId');
      _showBanSnackbar(
        icon: Icons.block_rounded,
        color: BanStatus.forbidden.color,
        message: '금지 카드는 덱에 넣을 수 없습니다.',
      );
      return;
    }
    if (localStock <= 0) {
      _pendingOps.remove('add_$cardId');
      _showBanSnackbar(
        icon: Icons.inventory_2_outlined,
        color: AppColors.textMuted,
        message: '보유 수량이 없습니다.',
      );
      return;
    }
    final inDeck = localCardIds.where((id) => id == cardId).length;
    final maxCopies = _maxCopies(banStatus);
    if (inDeck >= maxCopies) {
      _pendingOps.remove('add_$cardId');
      final limit = banStatus == BanStatus.limited ? '제한 카드는 1장까지만' : '준제한 카드는 2장까지만';
      _showBanSnackbar(
        icon: Icons.warning_amber_rounded,
        color: banStatus.color,
        message: '$limit 덱에 넣을 수 있습니다.',
      );
      return;
    }

    setState(() {
      _localDeckCardIds = [...localCardIds, cardId];
      _localStockOverride[cardId] = (localStock - 1).clamp(0, 99);
    });

    try {
      final result = await _deckService.addCardToDeck(
        currentDeck.id,
        cardId,
        banStatus: _banStatusString(banStatus),
        localCardIds: localCardIds,
        localStock: localStock,
      );

      if (mounted && result != AddCardResult.success) {
        setState(() {
          _localDeckCardIds = localCardIds;
          _localStockOverride[cardId] = localStock;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _localDeckCardIds = localCardIds;
          _localStockOverride[cardId] = localStock;
        });
      }
    } finally {
      _pendingOps.remove('add_$cardId');
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            _localDeckCardIds = null;
            _localStockOverride.remove(cardId);
          });
        }
      });
    }
  }

  // ── 낙관적 카드 제거 ────────────────────────────────────────
  void _removeCard(
    String cardId,
    Deck currentDeck,
    Map<String, QueryDocumentSnapshot> docById,
  ) async {
    if (_pendingOps.contains('remove_$cardId')) return;
    _pendingOps.add('remove_$cardId');

    final localCardIds = _localDeckCardIds ?? List<String>.from(currentDeck.cardIds);
    final cardDoc  = docById[cardId];
    final cardData = cardDoc?.data() as Map<String, dynamic>?;
    final localStock = _localStockOverride[cardId] ??
        ((cardData?['count'] ?? 0) as int);

    final idx = localCardIds.indexOf(cardId);
    if (idx == -1) {
      _pendingOps.remove('remove_$cardId');
      return;
    }

    final newIds = List<String>.from(localCardIds)..removeAt(idx);
    setState(() {
      _localDeckCardIds = newIds;
      _localStockOverride[cardId] = (localStock + 1).clamp(0, 99);
    });

    try {
      await _deckService.removeCardFromDeck(
        currentDeck.id,
        cardId,
        localCardIds: localCardIds,
        localStock: localStock,
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _localDeckCardIds = localCardIds;
          _localStockOverride[cardId] = localStock;
        });
      }
    } finally {
      _pendingOps.remove('remove_$cardId');
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            _localDeckCardIds = null;
            _localStockOverride.remove(cardId);
          });
        }
      });
    }
  }

  int _maxCopies(BanStatus banStatus) {
    switch (banStatus) {
      case BanStatus.forbidden:   return 0;
      case BanStatus.limited:     return 1;
      case BanStatus.semiLimited: return 2;
      case BanStatus.unlimited:   return 3;
    }
  }

  void _showBanSnackbar({
    required IconData icon,
    required Color color,
    required String message,
  }) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: color.withOpacity(0.4)),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
        content: Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 15, color: color),
            ),
            const SizedBox(width: 10),
            Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case '몬스터': return AppColors.monster;
      case '마법':   return AppColors.magic;
      case '함정':   return AppColors.trap;
      default:      return AppColors.textMuted;
    }
  }

  Map<String, int> _buildDeckCountMap(List<String> cardIds) {
    final map = <String, int>{};
    for (final id in cardIds) map[id] = (map[id] ?? 0) + 1;
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: StreamBuilder(
        stream: _deckService.getDecks(),
        builder: (context, deckSnap) {
          final firestoreDeck = deckSnap.hasData
              ? deckSnap.data!.firstWhere(
                  (d) => d.id == widget.deck.id,
                  orElse: () => widget.deck,
                )
              : widget.deck;

          final effectiveCardIds =
              _localDeckCardIds ?? firestoreDeck.cardIds;

          final currentDeck = _localDeckCardIds != null
              ? Deck(
                  id: firestoreDeck.id,
                  name: firestoreDeck.name,
                  cardIds: _localDeckCardIds!,
                  color: firestoreDeck.color,
                )
              : firestoreDeck;

          return StreamBuilder<QuerySnapshot>(
            stream: _cardRef.snapshots(),
            builder: (context, cardSnap) {
              if (!cardSnap.hasData) {
                return const Center(
                    child: CircularProgressIndicator(color: AppColors.accent));
              }

              final allDocs = cardSnap.data!.docs;
              final deckCountMap = _buildDeckCountMap(effectiveCardIds);

              final Map<String, QueryDocumentSnapshot> docById = {
                for (final d in allDocs) d.id: d,
              };

              int _effectiveStock(String cardId, Map<String, dynamic> data) {
                return _localStockOverride[cardId] ??
                    ((data['count'] ?? 0) as int);
              }

              final qf = _quickFilters.firstWhere(
                (f) => f.label == _quickFilterLabel,
                orElse: () => _quickFilters.first,
              );

              final listDocs = allDocs.where((doc) {
                final d       = doc.data() as Map<String, dynamic>;
                final name    = ((d['name'] ?? '') as String).toLowerCase();
                final type    = (d['type'] ?? '') as String;
                final subType = (d['subType'] ?? '') as String;
                if (!name.contains(_searchQuery.toLowerCase())) return false;
                if (_quickFilterLabel != '전체') {
                  if (qf.type != null && type != qf.type) return false;
                  if (qf.subType != null && subType != qf.subType) return false;
                }
                return true;
              }).toList();

              final mainCardIds  = <String>{};
              final extraCardIds = <String>{};
              for (final id in effectiveCardIds) {
                final doc = docById[id];
                if (doc == null) continue;
                final d = doc.data() as Map<String, dynamic>;
                if (isExtraCard((d['subType'] ?? '') as String)) {
                  extraCardIds.add(id);
                } else {
                  mainCardIds.add(id);
                }
              }

              int typeOrder(String t) => t == '몬스터' ? 0 : t == '마법' ? 1 : 2;

              final sortedMain = mainCardIds.toList()
                ..sort((a, b) {
                  final da = docById[a]?.data() as Map<String, dynamic>? ?? {};
                  final db = docById[b]?.data() as Map<String, dynamic>? ?? {};
                  return typeOrder(da['type'] ?? '')
                      .compareTo(typeOrder(db['type'] ?? ''));
                });
              final sortedExtra = extraCardIds.toList();

              final mainTotal  = sortedMain.fold<int>(0, (s, id) => s + (deckCountMap[id] ?? 0));
              final extraTotal = sortedExtra.fold<int>(0, (s, id) => s + (deckCountMap[id] ?? 0));

              return Column(
                children: [
                  // ── 헤더 ──
                  Container(
                    padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border(bottom: BorderSide(color: AppColors.border)),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded,
                              color: AppColors.textPrimary),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(currentDeck.name,
                                  style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5)),
                              Row(children: [
                                _DeckStatBadge(
                                    label: '메인',
                                    count: mainTotal,
                                    color: mainTotal < 40
                                        ? const Color(0xFFD97706)
                                        : mainTotal > 60
                                            ? const Color(0xFFDC2626)
                                            : AppColors.accent),
                                if (mainTotal < 40) ...[
                                  const SizedBox(width: 4),
                                  Tooltip(
                                    message: '메인 덱은 40장 이상이어야 합니다',
                                    child: Icon(Icons.warning_amber_rounded,
                                        size: 16, color: const Color(0xFFD97706)),
                                  ),
                                ],
                                if (mainTotal > 60) ...[
                                  const SizedBox(width: 4),
                                  Tooltip(
                                    message: '메인 덱은 60장 이하여야 합니다',
                                    child: Icon(Icons.error_outline_rounded,
                                        size: 16, color: const Color(0xFFDC2626)),
                                  ),
                                ],
                                const SizedBox(width: 8),
                                _DeckStatBadge(
                                    label: '엑스트라',
                                    count: extraTotal,
                                    color: extraTotal > 15
                                        ? const Color(0xFFDC2626)
                                        : const Color(0xFF7C3AED)),
                                if (extraTotal > 15) ...[
                                  const SizedBox(width: 4),
                                  Tooltip(
                                    message: '엑스트라 덱은 15장 이하여야 합니다',
                                    child: Icon(Icons.error_outline_rounded,
                                        size: 16, color: const Color(0xFFDC2626)),
                                  ),
                                ],
                              ]),
                            ],
                          ),
                        ),
                        if (_banListLoading) ...[
                          const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.accent),
                          ),
                          const SizedBox(width: 6),
                          const Text('금제 로딩중',
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 11)),
                          const SizedBox(width: 12),
                        ],
                        if (!_banListLoading) _BanLegend(),
                      ],
                    ),
                  ),

                  // ── 본문 ──
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── 좌: 카드 리스트 ──
                          Expanded(
                            flex: 2,
                            child: _Panel(
                              title: '카드 리스트',
                              subtitle: '${listDocs.length}종',
                              headerTrailing: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(
                                    height: 34,
                                    child: TextField(
                                      style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 12),
                                      decoration: InputDecoration(
                                        hintText: '검색',
                                        hintStyle: const TextStyle(
                                            color: AppColors.textMuted),
                                        isDense: true,
                                        prefixIcon: const Icon(
                                            Icons.search,
                                            size: 14),
                                        filled: true,
                                        fillColor: AppColors.surfaceAlt,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                vertical: 8),
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            borderSide: const BorderSide(
                                                color: AppColors.border)),
                                        enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            borderSide: const BorderSide(
                                                color: AppColors.border)),
                                        focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            borderSide: const BorderSide(
                                                color: AppColors.accent)),
                                      ),
                                      onChanged: (v) =>
                                          setState(() => _searchQuery = v),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: _quickFilters
                                          .map((qf) {
                                            final isSelected = _quickFilterLabel == qf.label;
                                            final isXyz = qf.label == '엑시즈';
                                            return Padding(
                                              padding: const EdgeInsets.only(right: 4),
                                              child: GestureDetector(
                                                onTap: () => setState(() => _quickFilterLabel = qf.label),
                                                child: AnimatedContainer(
                                                  duration: const Duration(milliseconds: 150),
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: isSelected ? qf.bgColor : AppColors.surface,
                                                    borderRadius: BorderRadius.circular(16),
                                                    border: Border.all(
                                                      color: isSelected
                                                          ? (isXyz ? qf.color : qf.bgColor)
                                                          : AppColors.border,
                                                      width: isSelected ? 1.5 : 1,
                                                    ),
                                                    boxShadow: isSelected
                                                        ? [
                                                            BoxShadow(
                                                              color: qf.bgColor.withOpacity(isXyz ? 0.5 : 0.4),
                                                              blurRadius: 6,
                                                              offset: const Offset(0, 1),
                                                            )
                                                          ]
                                                        : null,
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      if (!isSelected && qf.label != '전체') ...[
                                                        Container(
                                                          width: 5,
                                                          height: 5,
                                                          decoration: BoxDecoration(
                                                            color: isXyz ? const Color(0xFF475569) : qf.color,
                                                            shape: BoxShape.circle,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 4),
                                                      ],
                                                      Text(
                                                        qf.label,
                                                        style: TextStyle(
                                                          color: isSelected
                                                              ? (isXyz ? Colors.white : qf.color)
                                                              : AppColors.textSecondary,
                                                          fontSize: 10,
                                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          })
                                          .toList(),
                                    ),
                                  ),
                                ],
                              ),
                              child: ListView.builder(
                                padding: const EdgeInsets.all(6),
                                itemCount: listDocs.length,
                                itemBuilder: (context, i) {
                                  final doc  = listDocs[i];
                                  final d    = doc.data() as Map<String, dynamic>;
                                  final name = (d['name']     ?? '') as String;
                                  final type = (d['type']     ?? '') as String;
                                  final subType  = (d['subType']  ?? '') as String;
                                  final imageUrl = (d['imageUrl'] ?? '') as String;

                                  final stockCount  = _effectiveStock(doc.id, d);
                                  final inDeckCount = deckCountMap[doc.id] ?? 0;
                                  final outOfStock  = stockCount <= 0;
                                  final banStatus = _getBanStatus(d);
                                  final bool canAdd = !outOfStock &&
                                      _canAddMore(banStatus, inDeckCount);

                                  return Draggable<String>(
                                    data: doc.id,
                                    feedback: Material(
                                      color: Colors.transparent,
                                      child: Opacity(
                                        opacity: 0.9,
                                        child: _DragCardPreview(
                                          imageUrl: imageUrl,
                                          name: name,
                                          type: type,
                                        ),
                                      ),
                                    ),
                                    childWhenDragging: Opacity(
                                      opacity: 0.3,
                                      child: _ListCardTile(
                                        name: name, type: type,
                                        subType: subType,
                                        imageUrl: imageUrl,
                                        stockCount: stockCount,
                                        inDeckCount: inDeckCount,
                                        outOfStock: outOfStock,
                                        banStatus: banStatus,
                                        canAdd: false,
                                        onAdd: null,
                                        onRemove: null,
                                      ),
                                    ),
                                    child: _ListCardTile(
                                      name: name, type: type,
                                      subType: subType,
                                      imageUrl: imageUrl,
                                      stockCount: stockCount,
                                      inDeckCount: inDeckCount,
                                      outOfStock: outOfStock,
                                      banStatus: banStatus,
                                      canAdd: canAdd,
                                      onAdd: canAdd
                                          ? () => _addCard(doc.id, d, currentDeck, docById)
                                          : null,
                                      onRemove: inDeckCount > 0
                                          ? () => _removeCard(doc.id, currentDeck, docById)
                                          : null,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          // ── 우: 덱 카드 ──
                          Expanded(
                            flex: 8,
                            child: DragTarget<String>(
                              onWillAcceptWithDetails: (details) {
                                final doc = docById[details.data];
                                if (doc == null) return false;
                                final d = doc.data() as Map<String, dynamic>;
                                final stock = _effectiveStock(details.data, d);
                                if (stock <= 0) return false;
                                final banStatus = _getBanStatus(d);
                                final inDeck = deckCountMap[details.data] ?? 0;
                                return _canAddMore(banStatus, inDeck);
                              },
                              onAcceptWithDetails: (details) {
                                final doc = docById[details.data];
                                if (doc == null) return;
                                final d = doc.data() as Map<String, dynamic>;
                                _addCard(details.data, d, currentDeck, docById);
                              },
                              builder: (context, candidateData, rejectedData) {
                                final isDragOver = candidateData.isNotEmpty;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  decoration: BoxDecoration(
                                    color: isDragOver
                                        ? AppColors.accentLight
                                        : AppColors.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDragOver
                                          ? AppColors.accent
                                          : AppColors.border,
                                      width: isDragOver ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 12),
                                        decoration: const BoxDecoration(
                                          border: Border(
                                              bottom: BorderSide(
                                                  color: AppColors.border)),
                                        ),
                                        child: Row(
                                          children: [
                                            const Text('덱 카드',
                                                style: TextStyle(
                                                    color: AppColors
                                                        .textPrimary,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    fontSize: 14)),
                                            const SizedBox(width: 8),
                                            Text(
                                                '총 ${effectiveCardIds.length}장',
                                                style: const TextStyle(
                                                    color: AppColors
                                                        .textSecondary,
                                                    fontSize: 12)),
                                            if (isDragOver) ...[
                                              const Spacer(),
                                              const Icon(
                                                  Icons.add_circle_rounded,
                                                  color: AppColors.accent,
                                                  size: 16),
                                              const SizedBox(width: 4),
                                              const Text('여기에 놓으세요',
                                                  style: TextStyle(
                                                      color: AppColors.accent,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600)),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: SingleChildScrollView(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              if (sortedMain.isNotEmpty) ...[
                                                _DeckSectionLabel(
                                                    label: '메인 덱',
                                                    count: mainTotal,
                                                    color: AppColors.accent),
                                                const SizedBox(height: 10),
                                                _DeckCardGrid(
                                                  cardIds: sortedMain,
                                                  deckCountMap: deckCountMap,
                                                  docById: docById,
                                                  getBanStatus: _getBanStatus,
                                                  onRemove: (id) => _removeCard(id, currentDeck, docById),
                                                  onAdd: (id) {
                                                    final doc = docById[id];
                                                    if (doc == null) return;
                                                    _addCard(id, doc.data() as Map<String, dynamic>, currentDeck, docById);
                                                  },
                                                ),
                                                const SizedBox(height: 20),
                                              ],
                                              if (sortedExtra.isNotEmpty) ...[
                                                _DeckSectionLabel(
                                                    label: '엑스트라 덱',
                                                    count: extraTotal,
                                                    color: const Color(
                                                        0xFF7C3AED)),
                                                const SizedBox(height: 10),
                                                _DeckCardGrid(
                                                  cardIds: sortedExtra,
                                                  deckCountMap: deckCountMap,
                                                  docById: docById,
                                                  getBanStatus: _getBanStatus,
                                                  onRemove: (id) => _removeCard(id, currentDeck, docById),
                                                  onAdd: (id) {
                                                    final doc = docById[id];
                                                    if (doc == null) return;
                                                    _addCard(id, doc.data() as Map<String, dynamic>, currentDeck, docById);
                                                  },
                                                ),
                                              ],
                                              if (sortedMain.isEmpty &&
                                                  sortedExtra.isEmpty)
                                                const Center(
                                                  child: Padding(
                                                    padding: EdgeInsets.symmetric(
                                                        vertical: 60),
                                                    child: Text(
                                                      '카드를 드래그하거나\n왼쪽 목록에서 + 버튼으로 추가하세요',
                                                      style: TextStyle(
                                                          color: AppColors
                                                              .textMuted,
                                                          fontSize: 14),
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  bool _canAddMore(BanStatus banStatus, int inDeckCount) {
    switch (banStatus) {
      case BanStatus.forbidden:   return false;
      case BanStatus.limited:     return inDeckCount < 1;
      case BanStatus.semiLimited: return inDeckCount < 2;
      case BanStatus.unlimited:   return inDeckCount < 3;
    }
  }
}

// ── 이하 위젯들 ───────────────────────────────────────────────

class _BanLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _LegendDot(color: BanStatus.forbidden.color,   label: '금지 (0장)'),
        const SizedBox(width: 10),
        _LegendDot(color: BanStatus.limited.color,     label: '제한 (1장)'),
        const SizedBox(width: 10),
        _LegendDot(color: BanStatus.semiLimited.color, label: '준제한 (2장)'),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color  color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(label,
            style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class BanBadge extends StatelessWidget {
  final BanStatus status;
  final bool compact;
  const BanBadge({super.key, required this.status, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (!status.shouldShow) return const SizedBox.shrink();
    if (compact) {
      return Container(
        width: 8, height: 8,
        decoration: BoxDecoration(
          color: status.color,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: status.color.withOpacity(0.5), blurRadius: 3)],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: status.bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: status.color.withOpacity(0.4)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
            color: status.color, fontSize: 9, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _DragCardPreview extends StatelessWidget {
  final String imageUrl;
  final String name;
  final String type;
  const _DragCardPreview(
      {required this.imageUrl, required this.name, required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72, height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.accent, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: imageUrl.isNotEmpty
            ? Image.network(imageUrl, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(type))
            : _placeholder(type),
      ),
    );
  }

  Widget _placeholder(String type) => Container(
        color: typeBgColor(type),
        child: Center(child: Icon(Icons.style_outlined, color: typeColor(type), size: 24)),
      );
}

class _DeckSectionLabel extends StatelessWidget {
  final String label;
  final int    count;
  final Color  color;
  const _DeckSectionLabel({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 14,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(width: 6),
        Text('$count장', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
      ],
    );
  }
}

class _DeckCardGrid extends StatelessWidget {
  final List<String>                             cardIds;
  final Map<String, int>                         deckCountMap;
  final Map<String, QueryDocumentSnapshot>       docById;
  final BanStatus Function(Map<String, dynamic>) getBanStatus;
  final void Function(String) onRemove;
  final void Function(String) onAdd;

  const _DeckCardGrid({
    required this.cardIds,
    required this.deckCountMap,
    required this.docById,
    required this.getBanStatus,
    required this.onRemove,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: cardIds.expand((id) {
        final count = deckCountMap[id] ?? 0;
        final doc   = docById[id];
        if (doc == null || count == 0) return <Widget>[];
        final d          = doc.data() as Map<String, dynamic>;
        final name       = (d['name']     ?? '') as String;
        final imageUrl   = (d['imageUrl'] ?? '') as String;
        final subType    = (d['subType']  ?? '') as String;
        final type       = (d['type']     ?? '') as String;
        final stockCount = (d['count']    ?? 0)  as int;
        final banStatus  = getBanStatus(d);

        return List.generate(
            count,
            (index) => _DeckCardTile(
                  name: name, imageUrl: imageUrl,
                  subType: subType, type: type,
                  copyIndex: index, totalCopies: count,
                  stockCount: stockCount,
                  banStatus: banStatus,
                  isLast: index == count - 1,
                  onRemove: () => onRemove(id),
                  onAdd: stockCount > 0 ? () => onAdd(id) : null,
                ));
      }).toList(),
    );
  }
}

class _DeckCardTile extends StatelessWidget {
  final String     name;
  final String     imageUrl;
  final String     subType;
  final String     type;
  final int        copyIndex;
  final int        totalCopies;
  final int        stockCount;
  final BanStatus  banStatus;
  final bool       isLast;
  final VoidCallback  onRemove;
  final VoidCallback? onAdd;

  const _DeckCardTile({
    required this.name, required this.imageUrl,
    required this.subType, required this.type,
    required this.copyIndex, required this.totalCopies,
    required this.stockCount, required this.banStatus,
    required this.isLast, required this.onRemove, this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final isExtra     = isExtraCard(subType);
    final borderColor = isExtra ? subTypeColor(subType) : typeColor(type);

    return GestureDetector(
      onTap: onRemove,
      child: Container(
        width: 80, height: 112,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderColor.withOpacity(0.7), width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: imageUrl.isNotEmpty
                  ? Image.network(imageUrl, width: 80, height: 112, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(type))
                  : _placeholder(type),
            ),
            if (totalCopies > 1)
              Positioned(
                bottom: 3, left: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('${copyIndex + 1}/$totalCopies',
                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700)),
                ),
              ),
            if (banStatus.shouldShow)
              Positioned(
                bottom: 3, right: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: banStatus.color,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 2)],
                  ),
                  child: Text(banStatus.label,
                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800)),
                ),
              ),
            if (isLast)
              Positioned(
                top: 3, right: 3,
                child: Container(
                  width: 18, height: 18,
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.85), shape: BoxShape.circle),
                  child: const Icon(Icons.remove, size: 12, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(String type) => Container(
        color: typeBgColor(type),
        child: Center(child: Icon(Icons.style_outlined, size: 24, color: typeColor(type))),
      );
}

class _ListCardTile extends StatelessWidget {
  final String     name;
  final String     type;
  final String     subType;
  final String     imageUrl;
  final int        stockCount;
  final int        inDeckCount;
  final bool       outOfStock;
  final BanStatus  banStatus;
  final bool       canAdd;
  final VoidCallback? onAdd;
  final VoidCallback? onRemove;

  const _ListCardTile({
    required this.name, required this.type,
    required this.subType, required this.imageUrl,
    required this.stockCount, required this.inDeckCount,
    required this.outOfStock, required this.banStatus,
    required this.canAdd,
    this.onAdd, this.onRemove,
  });

  String? get _limitLabel {
    if (banStatus == BanStatus.forbidden) return null;
    if (banStatus == BanStatus.limited && inDeckCount >= 1) return '1장 한도';
    if (banStatus == BanStatus.semiLimited && inDeckCount >= 2) return '2장 한도';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isExtra = isExtraCard(subType);
    final color   = isExtra ? subTypeColor(subType) : typeColor(type);
    final blocked = banStatus == BanStatus.forbidden;

    return Opacity(
      opacity: blocked ? 0.6 : 1.0,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        decoration: BoxDecoration(
          color: blocked ? const Color(0xFFFEF2F2) : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: blocked
                ? BanStatus.forbidden.color.withOpacity(0.3)
                : inDeckCount > 0
                    ? AppColors.accent.withOpacity(0.4)
                    : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 3, height: 52,
              decoration: BoxDecoration(
                color: blocked ? BanStatus.forbidden.color : color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8), bottomLeft: Radius.circular(8),
                ),
              ),
            ),
            const SizedBox(width: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: imageUrl.isNotEmpty
                  ? Image.network(imageUrl, width: 28, height: 40, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _thumb(type))
                  : _thumb(type),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(name,
                      style: TextStyle(
                          color: outOfStock || blocked ? AppColors.textMuted : AppColors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text('보유 $stockCount',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 9)),
                      if (inDeckCount > 0) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.accentLight, borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text('덱 $inDeckCount',
                              style: const TextStyle(color: AppColors.accent, fontSize: 9, fontWeight: FontWeight.w700)),
                        ),
                      ],
                      if (banStatus.shouldShow) ...[
                        const SizedBox(width: 4),
                        BanBadge(status: banStatus),
                      ],
                      if (_limitLabel != null) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: banStatus.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: banStatus.color.withOpacity(0.3)),
                          ),
                          child: Text(_limitLabel!,
                              style: TextStyle(color: banStatus.color, fontSize: 8, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _MiniBtn(
                  icon: blocked ? Icons.block_rounded : Icons.add_rounded,
                  color: blocked ? BanStatus.forbidden.color : AppColors.accent,
                  bgColor: blocked ? BanStatus.forbidden.color.withOpacity(0.1) : AppColors.accentLight,
                  enabled: canAdd && onAdd != null,
                  onTap: onAdd,
                ),
                const SizedBox(height: 3),
                _MiniBtn(
                  icon: Icons.remove_rounded,
                  color: Colors.redAccent,
                  bgColor: const Color(0xFFFEE2E2),
                  enabled: inDeckCount > 0 && onRemove != null,
                  onTap: onRemove,
                ),
              ],
            ),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }

  Widget _thumb(String type) => Container(
        width: 28, height: 40, color: typeBgColor(type),
        child: Icon(Icons.style_outlined, size: 14, color: typeColor(type)),
      );
}

class _MiniBtn extends StatelessWidget {
  final IconData   icon;
  final Color      color;
  final Color      bgColor;
  final bool       enabled;
  final VoidCallback? onTap;

  const _MiniBtn({
    required this.icon, required this.color,
    required this.bgColor, required this.enabled, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.35,
        child: Container(
          width: 22, height: 22,
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(5)),
          child: Icon(icon, size: 13, color: color),
        ),
      ),
    );
  }
}

class _DeckStatBadge extends StatelessWidget {
  final String label;
  final int    count;
  final Color  color;
  const _DeckStatBadge({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text('$label $count장',
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _Panel extends StatelessWidget {
  final String  title;
  final String  subtitle;
  final Widget  child;
  final Widget? headerTrailing;

  const _Panel({required this.title, required this.subtitle, required this.child, this.headerTrailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(width: 6),
                  Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                ]),
                if (headerTrailing != null) ...[
                  const SizedBox(height: 8),
                  headerTrailing!,
                ],
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
