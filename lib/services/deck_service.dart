// lib/services/deck_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/deck_model.dart';

enum AddCardResult {
  success,
  outOfStock,
  limitExceeded,
  alreadyForbidden,
}

class DeckService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> get _decks =>
      _db.collection('users').doc(_uid).collection('decks');

  CollectionReference<Map<String, dynamic>> get _cards =>
      _db.collection('users').doc(_uid).collection('cards');

  Stream<List<Deck>> getDecks() {
    return _decks.snapshots().map((snap) =>
        snap.docs.map((d) => Deck.fromMap(d.id, d.data())).toList());
  }

  Future<void> addDeck(String name,
      {int color = Deck.defaultColor, String coverImageUrl = ''}) async {
    await _decks.add({
      'name': name,
      'cardIds': [],
      'color': color,
      'coverImageUrl': coverImageUrl,
    });
  }

  Future<void> deleteDeck(String id) async {
    await _decks.doc(id).delete();
  }

  Future<void> updateDeck(String id,
      {String? name, int? color, String? coverImageUrl}) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (color != null) data['color'] = color;
    if (coverImageUrl != null) data['coverImageUrl'] = coverImageUrl;
    if (data.isNotEmpty) await _decks.doc(id).update(data);
  }

  Future<void> copyDeck(Deck source, String newName) async {
    await _decks.add({
      'name': newName,
      'cardIds': List<String>.from(source.cardIds),
      'color': source.color,
      'coverImageUrl': source.coverImageUrl,
    });
  }

  // ── 덱 삭제 + 카드 수량 복구 ─────────────────────────────
  Future<void> deleteDeckWithRestore(String deckId) async {
    await _db.runTransaction((tx) async {
      final deckRef  = _decks.doc(deckId);
      final deckSnap = await tx.get(deckRef);
      if (!deckSnap.exists) return;

      final cardIds = List<String>.from(
          (deckSnap.data() as Map<String, dynamic>)['cardIds'] ?? []);

      final restoreMap = <String, int>{};
      for (final id in cardIds) {
        restoreMap[id] = (restoreMap[id] ?? 0) + 1;
      }

      final snaps = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final id in restoreMap.keys) {
        snaps[id] = await tx.get(_cards.doc(id));
      }
      for (final e in restoreMap.entries) {
        final s = snaps[e.key];
        if (s == null || !s.exists) continue;
        final cur =
            ((s.data() as Map<String, dynamic>)['count'] ?? 0) as int;
        tx.update(_cards.doc(e.key),
            {'count': (cur + e.value).clamp(0, 99)});
      }
      tx.delete(deckRef);
    });
  }

  // ── 덱에 카드 추가 ───────────────────────────────────────
  Future<AddCardResult> addCardToDeck(
    String deckId,
    String cardId, {
    String banStatus = '',
    List<String>? localCardIds,
    int? localStock,
  }) async {
    if (banStatus.toLowerCase() == 'forbidden') {
      return AddCardResult.alreadyForbidden;
    }

    if (localCardIds != null && localStock != null) {
      if (localStock <= 0) return AddCardResult.outOfStock;

      final inDeck = localCardIds.where((id) => id == cardId).length;
      final maxAllowed = _maxCopies(banStatus);
      if (inDeck >= maxAllowed) return AddCardResult.limitExceeded;

      final newIds = [...localCardIds, cardId];
      await Future.wait([
        _decks.doc(deckId).update({'cardIds': newIds}),
        _cards.doc(cardId).update({'count': (localStock - 1).clamp(0, 99)}),
      ]);
      return AddCardResult.success;
    }

    // 폴백: 트랜잭션
    var result = AddCardResult.success;
    await _db.runTransaction((tx) async {
      final deckRef  = _decks.doc(deckId);
      final cardRef  = _cards.doc(cardId);
      final deckSnap = await tx.get(deckRef);
      final cardSnap = await tx.get(cardRef);

      if (!deckSnap.exists || !cardSnap.exists) {
        result = AddCardResult.outOfStock;
        return;
      }

      final stock =
          ((cardSnap.data() as Map<String, dynamic>)['count'] ?? 0) as int;
      if (stock <= 0) {
        result = AddCardResult.outOfStock;
        return;
      }

      final ids = List<String>.from(
          (deckSnap.data() as Map<String, dynamic>)['cardIds'] ?? []);
      final inDeck = ids.where((id) => id == cardId).length;

      final maxAllowed = _maxCopies(banStatus);
      if (inDeck >= maxAllowed) {
        result = AddCardResult.limitExceeded;
        return;
      }

      ids.add(cardId);
      tx.update(deckRef, {'cardIds': ids});
      tx.update(cardRef, {'count': stock - 1});
    });
    return result;
  }

  int _maxCopies(String banStatus) {
    switch (banStatus.toLowerCase()) {
      case 'limited':
      case '제한':
        return 1;
      case 'semi-limited':
      case '준제한':
        return 2;
      default:
        return 3;
    }
  }

  // ── 덱에서 카드 제거 ─────────────────────────────────────
  Future<void> removeCardFromDeck(
    String deckId,
    String cardId, {
    List<String>? localCardIds,
    int? localStock,
  }) async {
    if (localCardIds != null && localStock != null) {
      final idx = localCardIds.indexOf(cardId);
      if (idx == -1) return;
      final newIds = List<String>.from(localCardIds)..removeAt(idx);
      await Future.wait([
        _decks.doc(deckId).update({'cardIds': newIds}),
        _cards.doc(cardId).update({
          'count': (localStock + 1).clamp(0, 99),
        }),
      ]);
      return;
    }

    // 폴백: 트랜잭션
    await _db.runTransaction((tx) async {
      final deckRef  = _decks.doc(deckId);
      final cardRef  = _cards.doc(cardId);
      final deckSnap = await tx.get(deckRef);
      final cardSnap = await tx.get(cardRef);
      if (!deckSnap.exists || !cardSnap.exists) return;

      final ids = List<String>.from(
          (deckSnap.data() as Map<String, dynamic>)['cardIds'] ?? []);
      final idx = ids.indexOf(cardId);
      if (idx == -1) return;
      ids.removeAt(idx);

      final stock =
          ((cardSnap.data() as Map<String, dynamic>)['count'] ?? 0) as int;
      tx.update(deckRef, {'cardIds': ids});
      tx.update(cardRef, {'count': (stock + 1).clamp(0, 99)});
    });
  }

  // ── 덱 유효성 검사 ─────────────────────────────────────
  Future<Map<String, dynamic>> validateDeck(String deckId) async {
    final deckSnap = await _decks.doc(deckId).get();
    if (!deckSnap.exists) {
      return {
        'isValid': false,
        'mainCount': 0,
        'extraCount': 0,
        'errors': ['덱을 찾을 수 없습니다'],
      };
    }

    final cardIds = List<String>.from(
        (deckSnap.data() as Map<String, dynamic>)['cardIds'] ?? []);

    // 카드 정보 가져오기
    final cardSnaps = await Future.wait(
      cardIds.map((id) => _cards.doc(id).get()),
    );

    int mainCount = 0;
    int extraCount = 0;
    final List<String> errors = [];

    for (final snap in cardSnaps) {
      if (!snap.exists) continue;
      
      final data = snap.data() as Map<String, dynamic>;
      final subType = data['subType'] as String? ?? '';
      final isExtra = _isExtraCard(subType);
      
      if (isExtra) {
        extraCount++;
      } else {
        mainCount++;
      }
    }

    // 유효성 검사
    if (mainCount < 40) {
      errors.add('메인 덱이 40장 미만입니다 (현재 $mainCount장)');
    }
    if (mainCount > 60) {
      errors.add('메인 덱이 60장을 초과했습니다 (현재 $mainCount장)');
    }
    if (extraCount > 15) {
      errors.add('엑스트라 덱이 15장을 초과했습니다 (현재 $extraCount장)');
    }

    return {
      'isValid': errors.isEmpty,
      'mainCount': mainCount,
      'extraCount': extraCount,
      'errors': errors,
    };
  }

  bool _isExtraCard(String subType) {
    return ['융합', '싱크로', '엑시즈', '링크'].contains(subType);
  }
}