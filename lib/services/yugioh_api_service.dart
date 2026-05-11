import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

enum BanStatus {
  forbidden,
  limited,
  semiLimited,
  unlimited,
}

extension BanStatusExtension on BanStatus {
  static BanStatus fromString(String s) {
    switch (s.toLowerCase()) {
      case 'forbidden':    return BanStatus.forbidden;
      case 'limited':      return BanStatus.limited;
      case 'semi-limited': return BanStatus.semiLimited;
      default:             return BanStatus.unlimited;
    }
  }

  String get label {
    switch (this) {
      case BanStatus.forbidden:   return '금지';
      case BanStatus.limited:     return '제한';
      case BanStatus.semiLimited: return '준제한';
      case BanStatus.unlimited:   return '무제한';
    }
  }

  Color get color {
    switch (this) {
      case BanStatus.forbidden:   return const Color(0xFFDC2626);
      case BanStatus.limited:     return const Color(0xFFD97706);
      case BanStatus.semiLimited: return const Color(0xFF2563EB);
      case BanStatus.unlimited:   return const Color(0xFF16A34A);
    }
  }

  Color get bgColor {
    switch (this) {
      case BanStatus.forbidden:   return const Color(0xFFFEE2E2);
      case BanStatus.limited:     return const Color(0xFFFEF3C7);
      case BanStatus.semiLimited: return const Color(0xFFDBEAFE);
      case BanStatus.unlimited:   return const Color(0xFFDCFCE7);
    }
  }

  bool get shouldShow => this != BanStatus.unlimited;
}

// ── 이미지 URL → CORS 우회 프록시 후보 목록 생성 ──────────────
// /imgproxy/ 경로는 Netlify Functions 없이는 동작하지 않으므로 제거
// weserv.nl, corsproxy.io, allorigins 순으로 fallback
String proxyImageUrl(String url) {
  if (url.isEmpty) return url;
  if (kIsWeb) {
    try {
      final uri = Uri.parse(url);
      if (uri.host.contains('ygoprodeck.com')) {
        return 'https://images.weserv.nl/?url=${uri.host}${uri.path}';
      }
    } catch (_) {}
  }
  return url;
}

/// 프록시 URL 후보 목록 (fallback 순서)
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

class YugiohApiService {
  final Map<String, String> _koreanNameCache = {};
  final Map<String, String> _koreanDescCache = {};

  final Map<String, BanStatus> _banById   = {};
  final Map<String, BanStatus> _banByName = {};
  bool _banListLoaded = false;

  static String proxiedImage(String url) => proxyImageUrl(url);

  static String proxiedImageFromCard(Map<String, dynamic> card) {
    final urls = imageCandidatesFromCard(card);
    return urls.isNotEmpty ? urls.first : '';
  }

  static List<String> imageCandidatesFromCard(Map<String, dynamic> card) {
    final small  = ((card['card_images']?[0]?['image_url_small'] ?? '') as String).trim();
    final origin = ((card['card_images']?[0]?['image_url']       ?? '') as String).trim();

    final results = <String>[];
    final seen = <String>{};

    void add(String u) {
      if (u.isNotEmpty && seen.add(u)) results.add(u);
    }

    for (final url in [small, origin]) {
      if (url.isEmpty) continue;
      try {
        final uri = Uri.parse(url);
        final encoded = Uri.encodeComponent(url);
        add('https://images.weserv.nl/?url=${uri.host}${uri.path}');
        add('https://corsproxy.io/?$encoded');
        add('https://api.allorigins.win/raw?url=$encoded');
        add(url);
      } catch (_) {
        add(url);
      }
    }

    return results;
  }

  List<Uri> _buildWebSafeCandidates(Uri original) {
    if (!kIsWeb) return [original];
    final encoded = Uri.encodeComponent(original.toString());
    return [
      Uri.parse('https://corsproxy.io/?$encoded'),
      Uri.parse('https://api.allorigins.win/raw?url=$encoded'),
      original,
    ];
  }

  Future<http.Response?> _getWithFallback(
    Uri original, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    http.Response? lastResponse;
    for (final uri in _buildWebSafeCandidates(original)) {
      try {
        final response = await http.get(uri, headers: headers).timeout(timeout);
        lastResponse = response;
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response;
        }
      } catch (_) {}
    }
    return lastResponse;
  }

  // ── 금제 리스트 로드 (OCG 기준) ──────────────────────────
  Future<void> loadBanList() async {
    if (_banListLoaded) return;
    try {
      final uri = Uri.parse(
          'https://db.ygoprodeck.com/api/v7/cardinfo.php'
          '?banlist=OCG&num=2000&offset=0');
      final res = await _getWithFallback(uri,
          timeout: const Duration(seconds: 12));
      if (res?.statusCode == 200) {
        final data = json.decode(utf8.decode(res!.bodyBytes));
        final cards =
            (data['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        for (final card in cards) {
          final id      = card['id']?.toString() ?? '';
          final engName = ((card['name'] ?? '') as String).toLowerCase().trim();
          final banInfo = card['banlist_info'] as Map<String, dynamic>?;
          if (banInfo == null) continue;
          final statusStr = (banInfo['ban_ocg'] ?? '') as String;
          if (statusStr.isEmpty) continue;
          final status = BanStatusExtension.fromString(statusStr);
          if (id.isNotEmpty)      _banById[id]        = status;
          if (engName.isNotEmpty) _banByName[engName] = status;
        }
        _banListLoaded = true;
        debugPrint('[BanList] 로드 완료: '
            '${_banById.length}개(id) / ${_banByName.length}개(영문명)');
      }
    } catch (e) {
      debugPrint('[BanList] 로드 실패: $e');
    }
  }

  BanStatus getBanStatus(String cardId) =>
      _banById[cardId] ?? BanStatus.unlimited;

  BanStatus getBanStatusByEngName(String engName) {
    final key = engName.toLowerCase().trim();
    return _banByName[key] ?? BanStatus.unlimited;
  }

  // ── 영문 퍼지 검색 ──────────────────────────────────────
  Future<List<Map<String, dynamic>>> searchCards(String query) async {
    if (query.trim().isEmpty) return [];
    final uri = Uri.parse(
        'https://db.ygoprodeck.com/api/v7/cardinfo.php'
        '?fname=${Uri.encodeComponent(query.trim())}&num=20&offset=0');
    try {
      final res =
          await _getWithFallback(uri, timeout: const Duration(seconds: 8));
      if (res?.statusCode == 200) {
        final body = utf8.decode(res!.bodyBytes);
        final data = json.decode(body);
        final cards = (data['data'] as List).cast<Map<String, dynamic>>();

        await Future.wait(cards.map((card) async {
          final id = card['id']?.toString() ?? '';
          if (id.isEmpty) return;
          final koName = await _fetchKoreanNameById(id);
          if (koName.isNotEmpty) card['ko_name'] = koName;
        }));
        return cards;
      }
    } catch (_) {}
    return [];
  }

  Future<String> _fetchKoreanNameById(String id) async {
    final cached = _koreanNameCache[id];
    if (cached != null) return cached;

    try {
      final uri = Uri.parse(
          'https://db.ygoprodeck.com/api/v7/cardinfo.php'
          '?id=$id&language=ko');
      final res =
          await _getWithFallback(uri, timeout: const Duration(seconds: 6));
      if (res?.statusCode == 200) {
        final data = json.decode(utf8.decode(res!.bodyBytes));
        final list =
            (data['data'] as List?)?.cast<Map<String, dynamic>>();
        if (list != null && list.isNotEmpty) {
          final koName = (list.first['name'] ?? '') as String;
          if (koName.contains(RegExp(r'[가-힣]'))) {
            _koreanNameCache[id] = koName;
            return koName;
          }
        }
      }
    } catch (_) {}
    _koreanNameCache[id] = '';
    return '';
  }

  // ── 한글 검색 ────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> searchCardsKorean(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final koInfo = await _fetchKoreanCardInfo(q);

    if (koInfo != null) {
      final cardName = (koInfo['cardName'] ?? q) as String;
      final cids = await _searchOfficialDbByCid(cardName);

      if (cids.isNotEmpty) {
        final resolvedCards = await Future.wait(
          cids.take(12).map((cid) async {
            final card = await _fetchByKonamiId(cid);
            if (card == null) return null;
            card['ko_name'] = cardName;
            await _ensureKoreanName(card, fallbackKoName: cardName);
            card['ko_attr']  = koInfo['cardAttr']  ?? '';
            card['ko_level'] = koInfo['cardLevel'] ?? '';
            card['ko_other'] = koInfo['cardOther'] ?? '';
            return card;
          }),
        );
        final results =
            resolvedCards.whereType<Map<String, dynamic>>().toList();
        if (results.isNotEmpty) return results;
      }

      return [
        {
          'name':      (koInfo['cardName'] ?? q) as String,
          'ko_name':   (koInfo['cardName'] ?? q) as String,
          'ko_attr':   koInfo['cardAttr']  ?? '',
          'ko_level':  koInfo['cardLevel'] ?? '',
          'ko_other':  koInfo['cardOther'] ?? '',
          'type':      _inferTypeFromOther(koInfo['cardOther'] ?? ''),
          'attribute': _inferAttrFromKo(koInfo['cardAttr'] ?? ''),
          'level':     _inferLevel(koInfo['cardLevel'] ?? ''),
          'race':      _inferRaceFromOther(koInfo['cardOther'] ?? ''),
          'card_images': [],
        }
      ];
    }

    final cids = await _searchOfficialDbByCid(q);
    if (cids.isNotEmpty) {
      final resolvedCards = await Future.wait(
        cids.take(12).map((cid) async {
          final card = await _fetchByKonamiId(cid);
          if (card == null) return null;
          await _ensureKoreanName(card, fallbackKoName: q);
          return card;
        }),
      );
      final results =
          resolvedCards.whereType<Map<String, dynamic>>().toList();
      if (results.isNotEmpty) return results;
    }

    return [];
  }

  Future<Map<String, dynamic>?> _fetchKoreanCardInfo(String name) async {
    try {
      final uri = Uri.parse(
          'https://api.yugiohcard.kr/card/${Uri.encodeComponent(name)}');
      final res =
          await _getWithFallback(uri, timeout: const Duration(seconds: 6));
      if (res?.statusCode == 200) {
        final body = utf8.decode(res!.bodyBytes);
        final data = json.decode(body);
        if (data is Map<String, dynamic> && data.containsKey('cardName')) {
          return data;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<List<String>> _searchOfficialDbByCid(String keyword) async {
    try {
      final uri = Uri.parse(
        'https://www.db.yugioh-card.com/yugiohdb/card_search.action'
        '?ope=1&sess=1&keyword=${Uri.encodeComponent(keyword)}'
        '&stype=1&ctype=&attribute=0&race=0'
        '&level_min=0&level_max=0&atk_min=0&atk_max=0'
        '&def_min=0&def_max=0&request_locale=ko',
      );
      final res = await _getWithFallback(uri, headers: {
        'User-Agent': 'Mozilla/5.0',
        'Accept-Language': 'ko-KR,ko;q=0.9',
      }, timeout: const Duration(seconds: 10));

      if (res?.statusCode == 200) {
        final body = utf8.decode(res!.bodyBytes);
        final regex = RegExp(r'cid=(\d+)');
        final matches = regex.allMatches(body);
        return matches.map((m) => m.group(1)!).toSet().toList();
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>?> _fetchByKonamiId(String konamiId) async {
    try {
      final uri = Uri.parse(
          'https://db.ygoprodeck.com/api/v7/cardinfo.php'
          '?konami_id=$konamiId');
      final res =
          await _getWithFallback(uri, timeout: const Duration(seconds: 6));
      if (res?.statusCode == 200) {
        final body = utf8.decode(res!.bodyBytes);
        final data = json.decode(body);
        final list =
            (data['data'] as List?)?.cast<Map<String, dynamic>>();
        return list?.isNotEmpty == true ? list!.first : null;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _ensureKoreanName(
    Map<String, dynamic> card, {
    String fallbackKoName = '',
  }) async {
    final existing = (card['ko_name'] as String? ?? '').trim();
    if (existing.isNotEmpty) return;

    final id = card['id']?.toString() ?? '';
    if (id.isNotEmpty) {
      final koName = await _fetchKoreanNameById(id);
      if (koName.isNotEmpty) {
        card['ko_name'] = koName;
        return;
      }
    }

    if (fallbackKoName.trim().isNotEmpty &&
        fallbackKoName.contains(RegExp(r'[가-힣]'))) {
      card['ko_name'] = fallbackKoName.trim();
    }
  }

  static String _inferTypeFromOther(String other) {
    final l = other.toLowerCase();
    if (l.contains('마법')) return 'Spell Card';
    if (l.contains('함정')) return 'Trap Card';
    return 'Effect Monster';
  }

  static String _inferAttrFromKo(String attr) {
    const map = {
      '화염': 'FIRE', '물': 'WATER', '땅': 'EARTH',
      '바람': 'WIND', '빛': 'LIGHT', '어둠': 'DARK', '신': 'DIVINE',
    };
    return map[attr] ?? '';
  }

  static int _inferLevel(String levelStr) {
    final m = RegExp(r'\d+').firstMatch(levelStr);
    return m != null ? int.tryParse(m.group(0)!) ?? 0 : 0;
  }

  static String _inferRaceFromOther(String other) {
    final m = RegExp(r'\[\s*([^/\]]+)').firstMatch(other);
    return m?.group(1)?.trim() ?? '';
  }

  // ── 한글 카드 효과 텍스트 ────────────────────────────────
  Future<String> fetchKoreanCardText(String cardName, {String? engName}) async {
    if (engName != null && engName.isNotEmpty) {
      final cacheKey = 'eng:$engName';
      if (_koreanDescCache.containsKey(cacheKey)) {
        return _koreanDescCache[cacheKey]!;
      }
      final result = await _fetchKoDescByEngName(engName);
      if (result.isNotEmpty) {
        _koreanDescCache[cacheKey] = result;
        return result;
      }
    }

    if (cardName.isNotEmpty && cardName.contains(RegExp(r'[가-힣]'))) {
      final cacheKey = 'ko:$cardName';
      if (_koreanDescCache.containsKey(cacheKey)) {
        return _koreanDescCache[cacheKey]!;
      }
      final cids = await _searchOfficialDbByCid(cardName);
      for (final cid in cids.take(3)) {
        final card = await _fetchByKonamiId(cid);
        if (card == null) continue;
        final id = card['id']?.toString() ?? '';
        if (id.isNotEmpty) {
          final result = await _fetchKoDescById(id);
          if (result.isNotEmpty) {
            _koreanDescCache[cacheKey] = result;
            return result;
          }
        }
      }
    }

    return '';
  }

  Future<String> _fetchKoDescByEngName(String engName) async {
    try {
      final uri = Uri.parse(
          'https://db.ygoprodeck.com/api/v7/cardinfo.php'
          '?name=${Uri.encodeComponent(engName)}');
      final res = await _getWithFallback(uri,
          timeout: const Duration(seconds: 8));
      if (res?.statusCode == 200) {
        final data = json.decode(utf8.decode(res!.bodyBytes));
        final list = (data['data'] as List?)?.cast<Map<String, dynamic>>();
        if (list != null && list.isNotEmpty) {
          final id = list.first['id']?.toString() ?? '';
          if (id.isNotEmpty) {
            return await _fetchKoDescById(id);
          }
        }
      }
    } catch (_) {}
    return '';
  }

  Future<String> _fetchKoDescById(String id) async {
    try {
      final uri = Uri.parse(
          'https://db.ygoprodeck.com/api/v7/cardinfo.php'
          '?id=$id&language=ko');
      final res = await _getWithFallback(uri,
          timeout: const Duration(seconds: 8));
      if (res?.statusCode == 200) {
        final data = json.decode(utf8.decode(res!.bodyBytes));
        final list = (data['data'] as List?)?.cast<Map<String, dynamic>>();
        if (list != null && list.isNotEmpty) {
          final desc = (list.first['desc'] ?? '') as String;
          if (desc.isNotEmpty && desc.contains(RegExp(r'[가-힣]'))) {
            return desc;
          }
        }
      }
    } catch (_) {}
    return '';
  }
}
