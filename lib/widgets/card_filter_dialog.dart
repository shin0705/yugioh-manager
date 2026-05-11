// lib/widgets/card_filter_dialog.dart
import 'package:flutter/material.dart';
import '../main.dart' show AppColors;
import '../constants/card_constants.dart';

class CardFilter {
  final Set<String> types;
  final Set<String> subTypes;
  final Set<String> attributes;
  final Set<String> races;
  final Set<int> levels;
  final String location;
  final String sort;
  // 팬듈럼 스케일 범위 (null = 필터 없음)
  final int? pendulumScaleMin;
  final int? pendulumScaleMax;
  // 링크 마커
  final Set<String> linkMarkers;

  const CardFilter({
    this.types = const {},
    this.subTypes = const {},
    this.attributes = const {},
    this.races = const {},
    this.levels = const {},
    this.location = '전체',
    this.sort = '이름순',
    this.pendulumScaleMin,
    this.pendulumScaleMax,
    this.linkMarkers = const {},
  });

  bool get isEmpty =>
      types.isEmpty &&
      subTypes.isEmpty &&
      attributes.isEmpty &&
      races.isEmpty &&
      levels.isEmpty &&
      location == '전체' &&
      sort == '이름순' &&
      pendulumScaleMin == null &&
      pendulumScaleMax == null &&
      linkMarkers.isEmpty;

  int get activeCount {
    int n = 0;
    if (types.isNotEmpty) n++;
    if (subTypes.isNotEmpty) n++;
    if (attributes.isNotEmpty) n++;
    if (races.isNotEmpty) n++;
    if (levels.isNotEmpty) n++;
    if (location != '전체') n++;
    if (sort != '이름순') n++;
    if (pendulumScaleMin != null || pendulumScaleMax != null) n++;
    if (linkMarkers.isNotEmpty) n++;
    return n;
  }

  CardFilter copyWith({
    Set<String>? types,
    Set<String>? subTypes,
    Set<String>? attributes,
    Set<String>? races,
    Set<int>? levels,
    String? location,
    String? sort,
    int? pendulumScaleMin,
    int? pendulumScaleMax,
    Set<String>? linkMarkers,
  }) =>
      CardFilter(
        types: types ?? this.types,
        subTypes: subTypes ?? this.subTypes,
        attributes: attributes ?? this.attributes,
        races: races ?? this.races,
        levels: levels ?? this.levels,
        location: location ?? this.location,
        sort: sort ?? this.sort,
        pendulumScaleMin: pendulumScaleMin ?? this.pendulumScaleMin,
        pendulumScaleMax: pendulumScaleMax ?? this.pendulumScaleMax,
        linkMarkers: linkMarkers ?? this.linkMarkers,
      );
}

Future<CardFilter?> showCardFilterDialog(
  BuildContext context,
  CardFilter current,
  List<String> availableLocations,
) async {
  return showDialog<CardFilter>(
    context: context,
    builder: (_) => _CardFilterDialog(
      current: current,
      availableLocations: availableLocations,
    ),
  );
}

class _CardFilterDialog extends StatefulWidget {
  final CardFilter current;
  final List<String> availableLocations;

  const _CardFilterDialog({
    required this.current,
    required this.availableLocations,
  });

  @override
  State<_CardFilterDialog> createState() => _CardFilterDialogState();
}

class _CardFilterDialogState extends State<_CardFilterDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  late Set<String> _types;
  late Set<String> _subTypes;
  late Set<String> _attributes;
  late Set<String> _races;
  late Set<int> _levels;
  late String _location;
  late String _sort;

  // 팬듈럼 스케일
  RangeValues _pendulumScale = const RangeValues(0, 13);
  bool _pendulumScaleActive = false;

  // 링크 마커
  late Set<String> _linkMarkers;

  // 링크 마커 8방향 정의
  static const _markerLabels = {
    '좌상': '↖',
    '상':  '↑',
    '우상': '↗',
    '좌':  '←',
    '우':  '→',
    '좌하': '↙',
    '하':  '↓',
    '우하': '↘',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _types = Set.from(widget.current.types);
    _subTypes = Set.from(widget.current.subTypes);
    _attributes = Set.from(widget.current.attributes);
    _races = Set.from(widget.current.races);
    _levels = Set.from(widget.current.levels);
    _location = widget.current.location;
    _sort = widget.current.sort;
    _linkMarkers = Set.from(widget.current.linkMarkers);

    if (widget.current.pendulumScaleMin != null ||
        widget.current.pendulumScaleMax != null) {
      _pendulumScaleActive = true;
      _pendulumScale = RangeValues(
        (widget.current.pendulumScaleMin ?? 0).toDouble(),
        (widget.current.pendulumScaleMax ?? 13).toDouble(),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleStr(Set<String> set, String value) {
    setState(() {
      set.contains(value) ? set.remove(value) : set.add(value);
    });
  }

  void _toggleInt(Set<int> set, int value) {
    setState(() {
      set.contains(value) ? set.remove(value) : set.add(value);
    });
  }

  void _reset() {
    setState(() {
      _types.clear();
      _subTypes.clear();
      _attributes.clear();
      _races.clear();
      _levels.clear();
      _location = '전체';
      _sort = '이름순';
      _pendulumScaleActive = false;
      _pendulumScale = const RangeValues(0, 13);
      _linkMarkers.clear();
    });
  }

  int get _activeCount {
    int n = 0;
    if (_types.isNotEmpty) n++;
    if (_subTypes.isNotEmpty) n++;
    if (_attributes.isNotEmpty) n++;
    if (_races.isNotEmpty) n++;
    if (_levels.isNotEmpty) n++;
    if (_location != '전체') n++;
    if (_sort != '이름순') n++;
    if (_pendulumScaleActive) n++;
    if (_linkMarkers.isNotEmpty) n++;
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: screenW * 0.04,
        vertical: screenH * 0.05,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 820, maxHeight: screenH * 0.9),
        child: Column(
          children: [
            // ── 헤더 ──
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
              child: Row(
                children: [
                  const Icon(Icons.tune_rounded, color: AppColors.accent, size: 20),
                  const SizedBox(width: 8),
                  const Text('상세 필터',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  if (_activeCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(10)),
                      child: Text('$_activeCount개 적용',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                  const Spacer(),
                  TextButton(
                    onPressed: _reset,
                    child: const Text('초기화',
                        style:
                            TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(6)),
                      child: const Icon(Icons.close_rounded,
                          color: AppColors.textMuted, size: 16),
                    ),
                  ),
                ],
              ),
            ),

            // ── 탭 (3개) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(8)),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle:
                      const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: '카드 정보'),
                    Tab(text: '특수 필터'),
                    Tab(text: '기타'),
                  ],
                ),
              ),
            ),

            // ── 탭 콘텐츠 ──
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // ══ 탭 1: 카드 정보 ══
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 카드 타입
                        _FilterSection(
                          title: '카드 타입',
                          child: Row(children: [
                            _TypeCard(
                              label: '몬스터 카드',
                              selected: _types.contains('몬스터'),
                              color: AppColors.monster,
                              bgColor: AppColors.monsterBg,
                              icon: Icons.catching_pokemon_rounded,
                              onTap: () => _toggleStr(_types, '몬스터'),
                            ),
                            const SizedBox(width: 10),
                            _TypeCard(
                              label: '마법 카드',
                              selected: _types.contains('마법'),
                              color: AppColors.magic,
                              bgColor: AppColors.magicBg,
                              icon: Icons.auto_fix_high_rounded,
                              onTap: () => _toggleStr(_types, '마법'),
                            ),
                            const SizedBox(width: 10),
                            _TypeCard(
                              label: '함정 카드',
                              selected: _types.contains('함정'),
                              color: AppColors.trap,
                              bgColor: AppColors.trapBg,
                              icon: Icons.warning_amber_rounded,
                              onTap: () => _toggleStr(_types, '함정'),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 20),

                        // 속성
                        _FilterSection(
                          title: '속성',
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: ['어둠', '빛', '땅', '물', '화염', '바람', '신']
                                .map((a) {
                              final stored = a == '화염' ? '불' : a;
                              return _AttrChip(
                                label: a,
                                selected: _attributes.contains(stored),
                                color: attributeColor(stored),
                                bgColor: attributeBgColor(stored),
                                onTap: () => _toggleStr(_attributes, stored),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 유형 (서브타입) - 팬듈럼 포함
                        _FilterSection(
                          title: '유형 (서브타입)',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SubTypeRow(
                                groupLabel: '몬스터',
                                color: AppColors.monster,
                                items: const ['일반', '효과', '의식', '튜너'],
                                selected: _subTypes,
                                onToggle: (v) => _toggleStr(_subTypes, v),
                              ),
                              const SizedBox(height: 8),
                              _SubTypeRow(
                                groupLabel: '팬듈럼',
                                color: const Color(0xFF0891B2),
                                items: const [
                                  '팬듈럼',
                                  '팬듈럼/효과',
                                  '팬듈럼/융합',
                                  '팬듈럼/싱크로',
                                  '팬듈럼/엑시즈',
                                ],
                                selected: _subTypes,
                                onToggle: (v) => _toggleStr(_subTypes, v),
                              ),
                              const SizedBox(height: 8),
                              _SubTypeRow(
                                groupLabel: '엑스트라',
                                color: const Color(0xFF7C3AED),
                                items: const ['융합', '싱크로', '엑시즈', '링크'],
                                selected: _subTypes,
                                onToggle: (v) => _toggleStr(_subTypes, v),
                              ),
                              const SizedBox(height: 8),
                              _SubTypeRow(
                                groupLabel: '마법',
                                color: AppColors.magic,
                                items: const ['일반', '지속', '속공', '장착', '필드'],
                                selected: _subTypes,
                                onToggle: (v) => _toggleStr(_subTypes, v),
                              ),
                              const SizedBox(height: 8),
                              _SubTypeRow(
                                groupLabel: '함정',
                                color: AppColors.trap,
                                items: const ['일반', '지속', '카운터'],
                                selected: _subTypes,
                                onToggle: (v) => _toggleStr(_subTypes, v),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 종족
                        _FilterSection(
                          title: '종족',
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              '마법사족', '드래곤족', '언데드족', '전사족', '야수전사족',
                              '야수족', '비행야수족', '천사족', '악마족', '곤충족',
                              '공룡족', '파충류족', '물족', '해룡족', '수족',
                              '화염족', '기계족', '암석족', '식물족', '번개족',
                              '사이킥족', '사이버스족', '환신야수족', '창조신족',
                              '환룡족', '환상마족',
                            ]
                                .map((r) => _SmallChip(
                                      label: r,
                                      selected: _races.contains(r),
                                      onTap: () => _toggleStr(_races, r),
                                    ))
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 레벨 (0 포함)
                        _FilterSection(
                          title: '레벨 / 랭크',
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: List.generate(14, (i) => i).map((lv) {
                              return _LevelChip(
                                level: lv,
                                selected: _levels.contains(lv),
                                onTap: () => _toggleInt(_levels, lv),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ══ 탭 2: 특수 필터 (팬듈럼 스케일 + 링크 마커) ══
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── 팬듈럼 스케일 ──
                        _FilterSection(
                          title: '팬듈럼 스케일',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Switch(
                                    value: _pendulumScaleActive,
                                    activeColor: AppColors.accent,
                                    onChanged: (v) =>
                                        setState(() => _pendulumScaleActive = v),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _pendulumScaleActive
                                        ? '스케일 ${_pendulumScale.start.round()} ~ ${_pendulumScale.end.round()}'
                                        : '사용 안 함',
                                    style: TextStyle(
                                      color: _pendulumScaleActive
                                          ? AppColors.accent
                                          : AppColors.textMuted,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              if (_pendulumScaleActive) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0891B2).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: const Color(0xFF0891B2).withOpacity(0.4)),
                                      ),
                                      child: Text(
                                        '${_pendulumScale.start.round()}',
                                        style: const TextStyle(
                                            color: Color(0xFF0891B2),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13),
                                      ),
                                    ),
                                    Expanded(
                                      child: RangeSlider(
                                        values: _pendulumScale,
                                        min: 0,
                                        max: 13,
                                        divisions: 13,
                                        activeColor: const Color(0xFF0891B2),
                                        inactiveColor:
                                            const Color(0xFF0891B2).withOpacity(0.2),
                                        onChanged: (v) =>
                                            setState(() => _pendulumScale = v),
                                      ),
                                    ),
                                    Container(
                                      width: 28,
                                      height: 28,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0891B2).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: const Color(0xFF0891B2).withOpacity(0.4)),
                                      ),
                                      child: Text(
                                        '${_pendulumScale.end.round()}',
                                        style: const TextStyle(
                                            color: Color(0xFF0891B2),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: List.generate(14, (i) => Text('$i',
                                        style: const TextStyle(
                                            color: AppColors.textMuted, fontSize: 9))),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── 링크 마커 ──
                        _FilterSection(
                          title: '링크 마커',
                          child: Column(
                            children: [
                              const Text(
                                '링크 몬스터의 마커 방향을 선택하세요',
                                style: TextStyle(
                                    color: AppColors.textMuted, fontSize: 11),
                              ),
                              const SizedBox(height: 14),
                              // 3x3 그리드 (가운데 = 카드)
                              _LinkMarkerGrid(
                                selected: _linkMarkers,
                                onToggle: (marker) =>
                                    _toggleStr(_linkMarkers, marker),
                              ),
                              if (_linkMarkers.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: _linkMarkers
                                      .map((m) => Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF1D4ED8)
                                                  .withOpacity(0.12),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                  color: const Color(0xFF1D4ED8)
                                                      .withOpacity(0.4)),
                                            ),
                                            child: Text(
                                              '${_markerLabels[m] ?? ''} $m',
                                              style: const TextStyle(
                                                  color: Color(0xFF1D4ED8),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600),
                                            ),
                                          ))
                                      .toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ══ 탭 3: 기타 ══
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FilterSection(
                          title: '위치',
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: ['전체', ...widget.availableLocations]
                                .toSet()
                                .toList()
                                .map((l) => _SmallChip(
                                      label: l,
                                      selected: _location == l,
                                      onTap: () => setState(() => _location = l),
                                    ))
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _FilterSection(
                          title: '정렬',
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: ['이름순', '레벨순', '수량순'].map((s) {
                              return _SmallChip(
                                label: s,
                                selected: _sort == s,
                                onTap: () => setState(() => _sort = s),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── 하단 버튼 ──
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              decoration:
                  const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(
                          context,
                          CardFilter(
                            types: Set.from(_types),
                            subTypes: Set.from(_subTypes),
                            attributes: Set.from(_attributes),
                            races: Set.from(_races),
                            levels: Set.from(_levels),
                            location: _location,
                            sort: _sort,
                            pendulumScaleMin: _pendulumScaleActive
                                ? _pendulumScale.start.round()
                                : null,
                            pendulumScaleMax: _pendulumScaleActive
                                ? _pendulumScale.end.round()
                                : null,
                            linkMarkers: Set.from(_linkMarkers),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('필터 적용',
                          style: TextStyle(fontWeight: FontWeight.w700)),
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
}

// ── 링크 마커 3x3 그리드 ──
class _LinkMarkerGrid extends StatelessWidget {
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  static const _grid = [
    ['좌상', '상',  '우상'],
    ['좌',  null,  '우'],
    ['좌하', '하',  '우하'],
  ];

  static const _arrows = {
    '좌상': '↖', '상': '↑', '우상': '↗',
    '좌': '←',              '우': '→',
    '좌하': '↙', '하': '↓', '우하': '↘',
  };

  const _LinkMarkerGrid({required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _grid.map((row) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: row.map((marker) {
                if (marker == null) {
                  // 가운데 = 카드 아이콘
                  return Container(
                    width: 64,
                    height: 64,
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D4ED8).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFF1D4ED8).withOpacity(0.3)),
                    ),
                    child: const Center(
                      child: Icon(Icons.style_rounded,
                          color: Color(0xFF1D4ED8), size: 28),
                    ),
                  );
                }

                final isSelected = selected.contains(marker);
                return GestureDetector(
                  onTap: () => onToggle(marker),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 64,
                    height: 64,
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF1D4ED8)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF1D4ED8)
                            : AppColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                  color: const Color(0xFF1D4ED8).withOpacity(0.3),
                                  blurRadius: 6)
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _arrows[marker] ?? '',
                          style: TextStyle(
                            fontSize: 22,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          marker,
                          style: TextStyle(
                            fontSize: 9,
                            color: isSelected
                                ? Colors.white.withOpacity(0.85)
                                : AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── 공통 위젯들 ──

class _FilterSection extends StatelessWidget {
  final String title;
  final Widget child;
  const _FilterSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                  color: AppColors.accent, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: child,
        ),
      ],
    );
  }
}

class _TypeCard extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final Color bgColor;
  final IconData icon;
  final VoidCallback onTap;

  const _TypeCard({
    required this.label,
    required this.selected,
    required this.color,
    required this.bgColor,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? color : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: selected ? color : AppColors.border,
                width: selected ? 2 : 1),
            boxShadow: selected
                ? [BoxShadow(
                    color: color.withOpacity(0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2))]
                : null,
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: selected ? Colors.white : color),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                      color: selected ? Colors.white : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttrChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _AttrChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? color : AppColors.border),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _SubTypeRow extends StatelessWidget {
  final String groupLabel;
  final Color color;
  final List<String> items;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  const _SubTypeRow({
    required this.groupLabel,
    required this.color,
    required this.items,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(groupLabel,
              style:
                  TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: items.map((item) {
              final sel = selected.contains(item);
              return GestureDetector(
                onTap: () => onToggle(item),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? color : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? color : AppColors.border),
                  ),
                  child: Text(item,
                      style: TextStyle(
                          color: sel ? Colors.white : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.w500)),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _SmallChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SmallChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: selected ? AppColors.accent : AppColors.border),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  final int level;
  final bool selected;
  final VoidCallback onTap;

  const _LevelChip({required this.level, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 40,
        height: 36,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFD97706) : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected ? const Color(0xFFD97706) : AppColors.border),
        ),
        child: Center(
          child: Text('$level',
              style: TextStyle(
                  color: selected ? Colors.white : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}