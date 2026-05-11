import 'dart:async';
import 'package:flutter/material.dart';
import '../services/yugioh_api_service.dart';
import '../main.dart' show AppColors;

class CardImageSearchDialog extends StatefulWidget {
  final YugiohApiService api;
  final void Function({
    required String cardName,
    required String engName,
    required String imageUrl,
    required String attribute,
    required int level,
    required String race,
    required String type,
    required String subType,
    required String desc,
  }) onApply;

  const CardImageSearchDialog({
    super.key,
    required this.api,
    required this.onApply,
  });

  @override
  State<CardImageSearchDialog> createState() => _CardImageSearchDialogState();
}

class _CardImageSearchDialogState extends State<CardImageSearchDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;
  bool _searched = false;
  Map<String, dynamic>? _selectedCard;
  String? _selectedImageUrl;

  // 실시간 검색용 디바운스 타이머
  Timer? _debounceTimer;
  static const _debounceDuration = Duration(milliseconds: 500);

  bool get _selectedHasNoImage =>
      _selectedCard != null &&
      (_selectedImageUrl == null || _selectedImageUrl!.isEmpty);

  static const _attrMapEn = {
    'LIGHT': '빛', 'DARK': '어둠', 'FIRE': '불',
    'WATER': '물', 'EARTH': '땅', 'WIND': '바람', 'DIVINE': '신',
  };
  static const _attrMapKo = {
    '화염': '불', '물': '물', '땅': '땅',
    '바람': '바람', '빛': '빛', '어둠': '어둠', '신': '신',
    'FIRE': '불', 'WATER': '물', 'EARTH': '땅',
    'WIND': '바람', 'LIGHT': '빛', 'DARK': '어둠', 'DIVINE': '신',
  };

  String _mapAttribute(Map<String, dynamic> card) {
    final raw = ((card['attribute'] ?? '') as String).toUpperCase();
    return _attrMapEn[raw] ?? _attrMapKo[card['ko_attr'] ?? ''] ?? '없음';
  }

  String _mapType(String t) {
    final l = t.toLowerCase();
    if (l.contains('spell')) return '마법';
    if (l.contains('trap'))  return '함정';
    return '몬스터';
  }

  /// ygoprodeck API의 type 필드 값 예시:
  /// "Normal Monster"          → 일반
  /// "Effect Monster"          → 효과
  /// "Fusion Monster"          → 융합
  /// "Synchro Monster"         → 싱크로
  /// "Synchro Tuner Monster"   → 싱크로
  /// "XYZ Monster"             → 엑시즈
  /// "Link Monster"            → 링크
  /// "Ritual Monster"          → 의식
  /// "Ritual Effect Monster"   → 의식
  /// "Pendulum Effect Monster" → 효과  (팬듈럼은 별도 서브타입 없음)
  /// "Spell Card"              → 마법 서브타입으로 분기
  /// "Trap Card"               → 함정 서브타입으로 분기
  String _mapSubType(String t) {
    final l = t.toLowerCase();

    // ── 엑스트라 덱 (우선순위 높게) ──
    if (l.contains('fusion'))  return '융합';
    if (l.contains('synchro')) return '싱크로';
    if (l.contains('xyz'))     return '엑시즈';
    if (l.contains('link'))    return '링크';

    // ── 의식 (몬스터/마법 공통, effect보다 먼저) ──
    if (l.contains('ritual')) return '의식';

    // ── 마법 서브타입 ──
    if (l.contains('continuous')) return '지속';
    if (l.contains('quick'))      return '속공';
    if (l.contains('equip'))      return '장착';
    if (l.contains('field'))      return '필드';
    if (l.contains('counter'))    return '카운터';

    // ── 일반 몬스터 (normal 키워드, effect보다 반드시 먼저 체크) ──
    if (l.contains('normal')) return '일반';

    // ── 효과 몬스터 ──
    if (l.contains('effect')) return '효과';

    // ── 나머지 몬스터 타입은 효과로 간주 ──
    // (Tuner Monster, Gemini Monster, Spirit Monster 등)
    if (l.contains('monster')) return '효과';

    return '일반';
  }

  static const _raceMap = {
    'Aqua': '수족', 'Beast': '야수족', 'Beast-Warrior': '야수전사족',
    'Creator God': '창조신족', 'Cyberse': '사이버스족', 'Dinosaur': '공룡족',
    'Divine-Beast': '환신야수족', 'Dragon': '드래곤족', 'Fairy': '천사족',
    'Fiend': '악마족', 'Fish': '어류족', 'Illusion': '환상마족',
    'Insect': '곤충족', 'Machine': '기계족', 'Plant': '식물족',
    'Psychic': '사이킥족', 'Pyro': '화염족', 'Reptile': '파충류족',
    'Rock': '암석족', 'Sea Serpent': '해룡족', 'Spellcaster': '마법사족',
    'Thunder': '번개족', 'Warrior': '전사족', 'Winged Beast': '비행야수족',
    'Wyrm': '환룡족', 'Zombie': '언데드족',
  };

  String _mapRace(String race) => _raceMap[race] ?? race;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _debounceTimer?.cancel();
        setState(() {
          _results = [];
          _selectedCard = null;
          _selectedImageUrl = null;
          _searched = false;
          _searchCtrl.clear();
        });
      }
    });

    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _tabController.dispose();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  bool get _isKoreanTab => _tabController.index == 0;

  void _onSearchChanged() {
    final q = _searchCtrl.text.trim();

    if (q.length < 2) {
      _debounceTimer?.cancel();
      if (_results.isNotEmpty || _searched) {
        setState(() {
          _results = [];
          _selectedCard = null;
          _selectedImageUrl = null;
          _searched = false;
        });
      }
      return;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, _search);
  }

  Future<void> _search() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;

    setState(() {
      _isLoading = true;
      _results = [];
      _selectedCard = null;
      _selectedImageUrl = null;
      _searched = true;
    });

    final results = _isKoreanTab
        ? await widget.api.searchCardsKorean(q)
        : await widget.api.searchCards(q);

    if (mounted) {
      setState(() {
        _results = results;
        _isLoading = false;
      });
    }
  }

  void _selectCard(Map<String, dynamic> card, String imgUrl) {
    setState(() {
      _selectedCard = card;
      _selectedImageUrl = imgUrl.isNotEmpty ? imgUrl : null;
    });
  }

  int _inferLevel(String levelStr) {
    final m = RegExp(r'\d+').firstMatch(levelStr);
    return m != null ? int.tryParse(m.group(0)!) ?? 0 : 0;
  }

  String _inferRaceFromOther(String other) {
    final m = RegExp(r'\[\s*([^/\]]+)').firstMatch(other);
    return m?.group(1)?.trim() ?? '';
  }

  String _resolveCardName(Map<String, dynamic> card) {
    final koName = (card['ko_name'] as String? ?? '').trim();
    if (koName.isNotEmpty) return koName;
    return (card['name'] ?? '') as String;
  }

  void _apply() {
    if (_selectedCard == null) return;
    final card = _selectedCard!;
    final engName = (card['name'] ?? '') as String;

    widget.onApply(
      cardName:  _resolveCardName(card),
      engName:   engName,
      imageUrl:  _selectedImageUrl ?? '',
      attribute: _mapAttribute(card),
      level: (card['level'] ?? card['rank'] ??
              _inferLevel(card['ko_level'] ?? '')) as int,
      race: _mapRace(
          (card['race'] ?? _inferRaceFromOther(card['ko_other'] ?? ''))
              as String),
      type:    _mapType(card['type'] ?? ''),
      subType: _mapSubType(card['type'] ?? ''),
      desc:    (card['desc'] ?? '') as String,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: screenW * 0.05,
        vertical:   screenH * 0.06,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 720, maxHeight: screenH * 0.88),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 제목 + 닫기
                Row(
                  children: [
                    const Icon(Icons.image_search_rounded,
                        color: AppColors.accent, size: 20),
                    const SizedBox(width: 8),
                    const Text('카드 이미지 검색',
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
                const SizedBox(height: 14),

                // 탭
                Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: AppColors.textSecondary,
                    labelStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    unselectedLabelStyle: const TextStyle(fontSize: 13),
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: '🇰🇷  한글 검색'),
                      Tab(text: '🌐  영문 검색'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 안내 배너
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _isKoreanTab
                      ? _InfoBanner(
                          key: const ValueKey('ko'),
                          text: '한글 카드명으로 검색하세요  ·  2글자 이상 입력하면 자동 검색됩니다',
                        )
                      : _InfoBanner(
                          key: const ValueKey('en'),
                          text: '영문 카드명으로 검색하세요  ·  2글자 이상 입력하면 자동 검색됩니다',
                        ),
                ),
                const SizedBox(height: 14),

                // 검색창
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: _isKoreanTab
                          ? '블루아이즈 화이트 드래곤, 다크 매지션, 하루 우라라...'
                          : 'Blue-Eyes White Dragon, Dark Magician...',
                      hintStyle:
                          const TextStyle(color: AppColors.textMuted),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: AppColors.textMuted, size: 18),
                      suffixIcon: _isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.accent,
                                ),
                              ),
                            )
                          : _searchCtrl.text.isNotEmpty
                              ? GestureDetector(
                                  onTap: () => _searchCtrl.clear(),
                                  child: const Icon(Icons.close_rounded,
                                      color: AppColors.textMuted, size: 18),
                                )
                              : null,
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // 결과 영역
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.accent)),
                  )
                else if (_results.isNotEmpty) ...[
                  Row(
                    children: [
                      Text('${_results.length}개 결과',
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      const Text('· 카드를 선택하세요',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 10),

                  SizedBox(
                    height: 260,
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 0.68,
                      ),
                      itemCount: _results.length,
                      itemBuilder: (context, i) {
                        final card = _results[i];
                        final imageCandidates =
                            YugiohApiService.imageCandidatesFromCard(card);
                        final imgUrl = imageCandidates.isNotEmpty
                            ? imageCandidates.first
                            : '';
                        final isSelected = _selectedCard == card;

                        return GestureDetector(
                          onTap: () => _selectCard(card, imgUrl),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.accent
                                    : AppColors.border,
                                width: isSelected ? 2.5 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppColors.accent
                                            .withOpacity(0.3),
                                        blurRadius: 8,
                                      )
                                    ]
                                  : null,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(7),
                              child: imgUrl.isNotEmpty
                                  ? _NetworkCardImage(
                                      urls: imageCandidates,
                                      fit: BoxFit.cover,
                                    )
                                  : _NoImageCard(
                                      name: _resolveCardName(card),
                                      selected: isSelected,
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // 선택 카드 정보
                  if (_selectedCard != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.accentLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.accent.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _selectedHasNoImage
                                ? Icons.warning_amber_rounded
                                : Icons.check_circle_rounded,
                            color: _selectedHasNoImage
                                ? Colors.orange
                                : AppColors.accent,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _resolveCardName(_selectedCard!),
                                  style: const TextStyle(
                                      color: AppColors.accent,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (_selectedHasNoImage)
                                  const Text(
                                    '이미지를 찾을 수 없습니다. 카드 정보만 적용됩니다.',
                                    style: TextStyle(
                                        color: Colors.orange, fontSize: 10),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _mapType(_selectedCard!['type'] ?? ''),
                              style: const TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _selectedCard != null ? _apply : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.surfaceAlt,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('이미지 및 정보 적용',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 50),
                    child: Center(
                      child: Column(
                        children: [
                          Container(
                            width: 56, height: 56,
                            decoration: BoxDecoration(
                              color: AppColors.accentLight,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.search_rounded,
                                color: AppColors.accent, size: 28),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _searched
                                ? '검색 결과가 없습니다'
                                : '카드명을 2글자 이상 입력하세요',
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          if (_searched && _isKoreanTab)
                            const Text(
                              '정확한 한글 카드명으로 다시 시도하거나\n영문 탭을 이용해보세요',
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 12),
                              textAlign: TextAlign.center,
                            )
                          else
                            Text(
                              _isKoreanTab
                                  ? '예: 블루아이즈 화이트 드래곤, 하루 우라라'
                                  : '예: Blue-Eyes White Dragon, Dark Magician',
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String text;
  const _InfoBanner({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.tips_and_updates_rounded,
              size: 13, color: AppColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _LoadingBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceAlt,
      child: const Center(
        child: SizedBox(
          width: 18, height: 18,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.accent),
        ),
      ),
    );
  }
}

class _NoImageCard extends StatelessWidget {
  final String name;
  final bool selected;
  const _NoImageCard({required this.name, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: selected ? AppColors.accentLight : AppColors.surfaceAlt,
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.style_outlined,
              color: selected ? AppColors.accent : AppColors.textMuted,
              size: 20),
          const SizedBox(height: 4),
          Text(name,
              style: TextStyle(
                  color: selected ? AppColors.accent : AppColors.textMuted,
                  fontSize: 9),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _BrokenImage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceAlt,
      child: const Icon(Icons.broken_image_outlined,
          color: AppColors.textMuted, size: 20),
    );
  }
}

class _NetworkCardImage extends StatefulWidget {
  final List<String> urls;
  final BoxFit fit;
  const _NetworkCardImage({required this.urls, this.fit = BoxFit.cover});

  @override
  State<_NetworkCardImage> createState() => _NetworkCardImageState();
}

class _NetworkCardImageState extends State<_NetworkCardImage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.urls.isEmpty || _index >= widget.urls.length) {
      return _BrokenImage();
    }
    return Image.network(
      widget.urls[_index],
      fit: widget.fit,
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : _LoadingBox(),
      errorBuilder: (_, __, ___) {
        if (_index < widget.urls.length - 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _index += 1);
          });
          return _LoadingBox();
        }
        return _BrokenImage();
      },
    );
  }
}
