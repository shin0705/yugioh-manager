// lib/services/card_io_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 웹 전용 다운로드
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show AnchorElement, Url, Blob;

class CardIOService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> get _cards =>
      _db.collection('users').doc(_uid).collection('cards');

  // 공유 덱은 공용 컬렉션 유지 (다른 유저가 코드로 불러올 수 있어야 함)
  static final _shared =
      FirebaseFirestore.instance.collection('shared_decks');

  // ────────────────────────────────────────────────────────
  // CSV 내보내기
  // ────────────────────────────────────────────────────────
  static const _csvHeaders = [
    'name', 'engName', 'type', 'subType', 'attribute',
    'level', 'race', 'count', 'location', 'imageUrl', 'memo',
  ];

  Future<String> exportToCsv() async {
    final snap = await _cards.get();
    final rows = <String>[_csvHeaders.join(',')];

    for (final doc in snap.docs) {
      final d = doc.data();
      rows.add(_csvHeaders.map((h) => _esc(d[h]?.toString() ?? '')).join(','));
    }
    return rows.join('\n');
  }

  void downloadCsv(String csv, {String filename = 'cards_export.csv'}) {
    if (!kIsWeb) return;
    final bytes = utf8.encode('\uFEFF$csv');
    final blob  = html.Blob([bytes], 'text/csv;charset=utf-8');
    final url   = html.Url.createObjectUrlFromBlob(blob);
    final a     = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  // ────────────────────────────────────────────────────────
  // CSV 가져오기
  // ────────────────────────────────────────────────────────
  Future<({int added, int updated, List<int> failed})> importFromCsv(
      String csv) async {
    final lines = csv
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();

    if (lines.isEmpty) return (added: 0, updated: 0, failed: <int>[]);

    final headers = _parseCsvRow(lines.first);
    int added = 0, updated = 0;
    final failed = <int>[];

    final existing = await _cards.get();
    final nameToId = <String, String>{};
    for (final doc in existing.docs) {
      final n = (doc.data()['name'] ?? '') as String;
      if (n.isNotEmpty) nameToId[n] = doc.id;
    }

    for (var i = 1; i < lines.length; i++) {
      try {
        final cells = _parseCsvRow(lines[i]);
        final Map<String, dynamic> data = {};
        for (var j = 0; j < headers.length && j < cells.length; j++) {
          final key = headers[j].trim();
          final val = cells[j];
          if (key == 'level' || key == 'count') {
            data[key] = int.tryParse(val) ?? 0;
          } else {
            data[key] = val;
          }
        }

        final name = (data['name'] ?? '') as String;
        if (name.isEmpty) {
          failed.add(i + 1);
          continue;
        }

        if (nameToId.containsKey(name)) {
          await _cards.doc(nameToId[name]).update(data);
          updated++;
        } else {
          final ref = await _cards.add(data);
          nameToId[name] = ref.id;
          added++;
        }
      } catch (_) {
        failed.add(i + 1);
      }
    }

    return (added: added, updated: updated, failed: failed);
  }

  // ────────────────────────────────────────────────────────
  // 카드 일괄 추가
  // ────────────────────────────────────────────────────────
  Future<({int added, int increased, List<String> failed})> bulkAddByName(
      String text) async {
    final names = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    int added = 0, increased = 0;
    final failed = <String>[];

    final existing = await _cards.get();
    final nameToDoc = <String, QueryDocumentSnapshot>{};
    for (final doc in existing.docs) {
      final n =
          (doc.data() as Map<String, dynamic>)['name'] as String? ?? '';
      if (n.isNotEmpty) nameToDoc[n] = doc;
    }

    for (final name in names) {
      try {
        if (nameToDoc.containsKey(name)) {
          final doc = nameToDoc[name]!;
          final cur =
              ((doc.data() as Map<String, dynamic>)['count'] ?? 0) as int;
          await _cards
              .doc(doc.id)
              .update({'count': (cur + 1).clamp(0, 99)});
          increased++;
        } else {
          final ref = await _cards.add({
            'name':      name,
            'engName':   '',
            'type':      '몬스터',
            'subType':   '효과',
            'attribute': '없음',
            'level':     0,
            'race':      '',
            'count':     1,
            'location':  '',
            'imageUrl':  '',
            'memo':      '',
          });
          nameToDoc[name] =
              await ref.get() as QueryDocumentSnapshot;
          added++;
        }
      } catch (_) {
        failed.add(name);
      }
    }

    return (added: added, increased: increased, failed: failed);
  }

  // ────────────────────────────────────────────────────────
  // 덱 공유 (공용 컬렉션)
  // ────────────────────────────────────────────────────────
  Future<String> shareDeck({
    required String deckName,
    required List<String> cardIds,
    required List<Map<String, dynamic>> cardDataList,
  }) async {
    final code = _generateCode();
    await _shared.doc(code).set({
      'deckName':  deckName,
      'cardIds':   cardIds,
      'cardData':  cardDataList,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return code;
  }

  Future<Map<String, dynamic>?> loadSharedDeck(String code) async {
    final doc =
        await _shared.doc(code.trim().toUpperCase()).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  // ────────────────────────────────────────────────────────
  // Private helpers
  // ────────────────────────────────────────────────────────
  String _esc(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  List<String> _parseCsvRow(String row) {
    final cells  = <String>[];
    var inQuotes = false;
    var buf      = StringBuffer();

    for (var i = 0; i < row.length; i++) {
      final ch = row[i];
      if (ch == '"') {
        if (inQuotes &&
            i + 1 < row.length &&
            row[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == ',' && !inQuotes) {
        cells.add(buf.toString());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    cells.add(buf.toString());
    return cells;
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand  = DateTime.now().millisecondsSinceEpoch;
    return List.generate(
            6, (i) => chars[(rand >> (i * 5)) % chars.length])
        .join();
  }
}

