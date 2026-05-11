// lib/widgets/deck_share_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/card_io_service.dart';
import '../services/deck_service.dart';
import '../models/deck_model.dart';
import '../main.dart' show AppColors;
import '../constants/card_constants.dart';

// ── 진입점 ────────────────────────────────────────────────────
Future<void> showDeckShareDialog(
  BuildContext context, {
  required Deck deck,
}) {
  return showDialog(
    context: context,
    builder: (_) => _DeckShareDialog(deck: deck),
  );
}

Future<void> showDeckLoadDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (_) => const _DeckLoadDialog(),
  );
}

// ── 공유 코드 생성 다이얼로그 ─────────────────────────────────
class _DeckShareDialog extends StatefulWidget {
  final Deck deck;
  const _DeckShareDialog({required this.deck});

  @override
  State<_DeckShareDialog> createState() => _DeckShareDialogState();
}

class _DeckShareDialogState extends State<_DeckShareDialog> {
  final _io = CardIOService();

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> get _cardsRef =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('cards');

  bool _loading = false;
  String? _shareCode;
  String? _error;

  Future<void> _generateCode() async {
    setState(() { _loading = true; _shareCode = null; _error = null; });

    try {
      final cardIds = widget.deck.cardIds;
      if (cardIds.isEmpty) {
        setState(() {
          _error = '덱에 카드가 없습니다.';
          _loading = false;
        });
        return;
      }

      final uniqueIds = cardIds.toSet().toList();
      final snap = await _cardsRef
          .where(FieldPath.documentId, whereIn: uniqueIds)
          .get();

      final cardDataList = snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['_docId'] = d.id;
        return data;
      }).toList();

      final code = await _io.shareDeck(
        deckName: widget.deck.name,
        cardIds: cardIds,
        cardDataList: cardDataList,
      );

      setState(() { _shareCode = code; _loading = false; });
    } catch (e) {
      setState(() { _error = '오류: $e'; _loading = false; });
    }
  }

  void _copyCode() {
    if (_shareCode == null) return;
    Clipboard.setData(ClipboardData(text: _shareCode!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('코드가 복사되었습니다!'),
        duration: Duration(seconds: 2),
        backgroundColor: AppColors.accent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.share_rounded,
                      color: AppColors.accent, size: 20),
                  const SizedBox(width: 8),
                  const Text('덱 공유',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: AppColors.textMuted, size: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.magicBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.view_list_rounded,
                          color: AppColors.magic, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.deck.name,
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                          Text('카드 ${widget.deck.cardIds.length}장',
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                '공유 코드를 생성하면 다른 사람이 코드를 입력해\n이 덱을 자신의 앱에 불러올 수 있습니다.',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.5),
              ),
              const SizedBox(height: 16),

              if (_shareCode == null && !_loading) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _generateCode,
                    icon: const Icon(Icons.qr_code_rounded, size: 18),
                    label: const Text('공유 코드 생성'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ] else if (_loading) ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: CircularProgressIndicator(color: AppColors.accent),
                  ),
                ),
              ] else if (_shareCode != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.accentLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.accent.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Text('공유 코드',
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(
                        _shareCode!,
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 6,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _copyCode,
                          icon: const Icon(Icons.copy_rounded, size: 15),
                          label: const Text('코드 복사'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.accent,
                            side: BorderSide(
                                color: AppColors.accent.withOpacity(0.4)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '이 코드는 24시간 동안 유효합니다',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: _generateCode,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('새 코드 재생성'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_error!,
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 12)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── 코드로 덱 불러오기 ────────────────────────────────────────
class _DeckLoadDialog extends StatefulWidget {
  const _DeckLoadDialog();

  @override
  State<_DeckLoadDialog> createState() => _DeckLoadDialogState();
}

class _DeckLoadDialogState extends State<_DeckLoadDialog> {
  final _io         = CardIOService();
  final _deckService = DeckService();
  final _ctrl       = TextEditingController();

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> get _cardsRef =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('cards');

  CollectionReference<Map<String, dynamic>> get _decksRef =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('decks');

  bool _loading = false;
  String? _result;
  Map<String, dynamic>? _preview;
  List<_PreviewCard> _previewCards = [];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final code = _ctrl.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _result = '❌ 6자리 코드를 입력하세요.');
      return;
    }
    setState(() { _loading = true; _result = null; _preview = null; _previewCards = []; });
    try {
      final data = await _io.loadSharedDeck(code);
      if (data == null) {
        setState(() { _result = '❌ 코드를 찾을 수 없습니다.'; _loading = false; });
        return;
      }

      final myCardsSnap = await _cardsRef.get();
      final myCardsByName = <String, QueryDocumentSnapshot>{};
      for (final doc in myCardsSnap.docs) {
        final n = ((doc.data() as Map<String, dynamic>)['name'] ?? '') as String;
        if (n.isNotEmpty) myCardsByName[n] = doc;
      }

      final sharedCardData = List<Map<String, dynamic>>.from(
          (data['cardData'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? []);
      final cardIds = List<String>.from(data['cardIds'] ?? []);

      final dataByDocId = <String, Map<String, dynamic>>{};
      for (final cd in sharedCardData) {
        final docId = (cd['_docId'] ?? '') as String;
        if (docId.isNotEmpty) dataByDocId[docId] = cd;
      }

      final seen = <String>{};
      final previews = <_PreviewCard>[];
      for (final id in cardIds) {
        if (seen.contains(id)) continue;
        seen.add(id);
        final sharedData = dataByDocId[id];
        if (sharedData == null) continue;
        final cardName = (sharedData['name'] ?? '') as String;
        final owned = myCardsByName.containsKey(cardName);
        final ownedDoc = myCardsByName[cardName];
        previews.add(_PreviewCard(
          sharedData: sharedData,
          ownedDocId: ownedDoc?.id,
          owned: owned,
          countInDeck: cardIds.where((c) => c == id).length,
        ));
      }

      setState(() {
        _preview = data;
        _previewCards = previews;
        _loading = false;
      });
    } catch (e) {
      setState(() { _result = '❌ 오류: $e'; _loading = false; });
    }
  }

  Future<void> _importDeck() async {
    if (_preview == null) return;
    setState(() => _loading = true);
    try {
      final deckName = (_preview!['deckName'] ?? '공유된 덱') as String;
      final cardIds = List<String>.from(_preview!['cardIds'] ?? []);

      final sharedCardData = List<Map<String, dynamic>>.from(
          (_preview!['cardData'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? []);

      final myCardsSnap = await _cardsRef.get();
      final myCardsByName = <String, String>{};
      for (final doc in myCardsSnap.docs) {
        final n = ((doc.data() as Map<String, dynamic>)['name'] ?? '') as String;
        if (n.isNotEmpty) myCardsByName[n] = doc.id;
      }

      final idMapping = <String, String>{};

      for (final cd in sharedCardData) {
        final sharedDocId = (cd['_docId'] ?? '') as String;
        if (sharedDocId.isEmpty) continue;
        final cardName = (cd['name'] ?? '') as String;

        if (myCardsByName.containsKey(cardName)) {
          idMapping[sharedDocId] = myCardsByName[cardName]!;
        } else {
          final newData = Map<String, dynamic>.from(cd)
            ..remove('_docId')
            ..['count'] = 0
            ..['_sharedCard'] = true;
          final newRef = await _cardsRef.add(newData);
          idMapping[sharedDocId] = newRef.id;
          myCardsByName[cardName] = newRef.id;
        }
      }

      final realCardIds = cardIds.map((id) => idMapping[id] ?? id).toList();

      await _decksRef.add({
        'name': '$deckName (공유)',
        'cardIds': realCardIds,
      });

      final ownedCount   = _previewCards.where((c) => c.owned).length;
      final unownedCount = _previewCards.where((c) => !c.owned).length;

      setState(() {
        _result = '✅ "$deckName" 덱을 불러왔습니다!\n'
            '보유 카드: ${ownedCount}종  |  미보유 카드: ${unownedCount}종\n'
            '미보유 카드는 회색으로 표시됩니다.';
        _preview = null;
        _previewCards = [];
        _ctrl.clear();
        _loading = false;
      });
    } catch (e) {
      setState(() { _result = '❌ 오류: $e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ownedCount   = _previewCards.where((c) => c.owned).length;
    final unownedCount = _previewCards.where((c) => !c.owned).length;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                children: [
                  const Icon(Icons.download_for_offline_rounded,
                      color: AppColors.magic, size: 20),
                  const SizedBox(width: 8),
                  const Text('공유 덱 불러오기',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: AppColors.textMuted, size: 16),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '공유받은 6자리 코드를 입력하세요.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: TextField(
                              controller: _ctrl,
                              autofocus: true,
                              textCapitalization: TextCapitalization.characters,
                              maxLength: 6,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 4,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'XXXXXX',
                                hintStyle: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 20,
                                    letterSpacing: 4),
                                counterText: '',
                                border: InputBorder.none,
                                contentPadding:
                                    EdgeInsets.symmetric(horizontal: 14),
                              ),
                              onSubmitted: (_) => _load(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: _loading ? null : _load,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            minimumSize: const Size(60, 48),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text('검색',
                                  style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),

                    if (_preview != null) ...[
                      const SizedBox(height: 16),

                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.magicBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.magic.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.view_list_rounded,
                                    color: AppColors.magic, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    (_preview!['deckName'] ?? '덱') as String,
                                    style: const TextStyle(
                                        color: AppColors.magic,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  '총 ${(_preview!['cardIds'] as List?)?.length ?? 0}장',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary, fontSize: 12),
                                ),
                                const SizedBox(width: 12),
                                if (ownedCount > 0)
                                  _StatBadge(
                                    label: '보유 $ownedCount종',
                                    color: AppColors.magic,
                                    bgColor: AppColors.magicBg,
                                  ),
                                const SizedBox(width: 6),
                                if (unownedCount > 0)
                                  _StatBadge(
                                    label: '미보유 $unownedCount종',
                                    color: Colors.grey,
                                    bgColor: AppColors.surfaceAlt,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      if (_previewCards.isNotEmpty) ...[
                        const Text(
                          '카드 목록 미리보기',
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 220),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            shrinkWrap: true,
                            itemCount: _previewCards.length,
                            itemBuilder: (context, i) {
                              final pc       = _previewCards[i];
                              final data     = pc.sharedData;
                              final name     = (data['name']     ?? '') as String;
                              final type     = (data['type']     ?? '') as String;
                              final subType  = (data['subType']  ?? '') as String;
                              final imageUrl = (data['imageUrl'] ?? '') as String;
                              final isExtra  = isExtraCard(subType);
                              final barColor = isExtra
                                  ? subTypeColor(subType)
                                  : typeColor(type);

                              return Opacity(
                                opacity: pc.owned ? 1.0 : 0.45,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: pc.owned
                                        ? AppColors.surface
                                        : AppColors.surfaceAlt,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: pc.owned
                                          ? AppColors.border
                                          : Colors.grey.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 3, height: 36,
                                        decoration: BoxDecoration(
                                          color: pc.owned ? barColor : Colors.grey,
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(3),
                                        child: ColorFiltered(
                                          colorFilter: pc.owned
                                              ? const ColorFilter.mode(
                                                  Colors.transparent,
                                                  BlendMode.color)
                                              : const ColorFilter.matrix([
                                                  0.2126, 0.7152, 0.0722, 0, 0,
                                                  0.2126, 0.7152, 0.0722, 0, 0,
                                                  0.2126, 0.7152, 0.0722, 0, 0,
                                                  0,      0,      0,      1, 0,
                                                ]),
                                          child: imageUrl.isNotEmpty
                                              ? Image.network(
                                                  imageUrl,
                                                  width: 24, height: 34,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      _thumbBox(type),
                                                )
                                              : _thumbBox(type),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: TextStyle(
                                                color: pc.owned
                                                    ? AppColors.textPrimary
                                                    : AppColors.textMuted,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (pc.countInDeck > 1)
                                              Text(
                                                '×${pc.countInDeck}',
                                                style: TextStyle(
                                                  color: pc.owned
                                                      ? AppColors.textSecondary
                                                      : AppColors.textMuted,
                                                  fontSize: 10,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: pc.owned
                                              ? AppColors.magicBg
                                              : Colors.grey.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(5),
                                          border: Border.all(
                                            color: pc.owned
                                                ? AppColors.magic.withOpacity(0.4)
                                                : Colors.grey.withOpacity(0.3),
                                          ),
                                        ),
                                        child: Text(
                                          pc.owned ? '보유' : '미보유',
                                          style: TextStyle(
                                            color: pc.owned
                                                ? AppColors.magic
                                                : Colors.grey,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 6),

                        if (unownedCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.orange.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded,
                                    size: 13, color: Colors.orange),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '미보유 카드 $unownedCount종은 덱에 회색으로 표시되며 수량 0으로 추가됩니다.',
                                    style: const TextStyle(
                                        color: Colors.orange,
                                        fontSize: 10,
                                        height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 12),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _loading ? null : _importDeck,
                            icon: _loading
                                ? const SizedBox(
                                    width: 16, height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.add_rounded, size: 16),
                            label: Text(_loading ? '불러오는 중...' : '이 덱 가져오기'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.magic,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ],

                    if (_result != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _result!.startsWith('✅')
                              ? const Color(0xFFECFDF5)
                              : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (_result!.startsWith('✅')
                                    ? AppColors.magic
                                    : Colors.redAccent)
                                .withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          _result!,
                          style: TextStyle(
                            color: _result!.startsWith('✅')
                                ? AppColors.magic
                                : Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbBox(String type) => Container(
        width: 24, height: 34,
        color: typeBgColor(type),
        child: Icon(Icons.style_outlined, size: 12, color: typeColor(type)),
      );
}

// ── 데이터 클래스 ─────────────────────────────────────────────
class _PreviewCard {
  final Map<String, dynamic> sharedData;
  final String? ownedDocId;
  final bool owned;
  final int countInDeck;

  const _PreviewCard({
    required this.sharedData,
    required this.ownedDocId,
    required this.owned,
    required this.countInDeck,
  });
}

class _StatBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bgColor;
  const _StatBadge({required this.label, required this.color, required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}