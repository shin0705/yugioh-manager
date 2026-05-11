import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../services/yugioh_api_service.dart';
import '../dialog/image_search_dialog.dart';
import '../main.dart' show AppColors;
import '../constants/card_constants.dart';

class AddCardPage extends StatefulWidget {
  const AddCardPage({super.key});

  @override
  State<AddCardPage> createState() => _AddCardPageState();
}

class _AddCardPageState extends State<AddCardPage> {
  final _formKey = GlobalKey<FormState>();
  final _api     = YugiohApiService();
  final service  = FirestoreService();

  final nameController     = TextEditingController();
  final levelController    = TextEditingController();
  final raceController     = TextEditingController();
  final locationController = TextEditingController();
  final memoController     = TextEditingController();

  String selectedAttribute = '없음';
  String selectedType      = '몬스터';
  String selectedSubType   = '일반';
  int    count             = 1;
  String? _cardImageUrl;
  String  _engName         = ''; // ✅ 영문명 저장용
  String  _cardDesc        = ''; // ✅ 카드 효과 텍스트 저장용

  final List<String> attributes = ['없음', '빛', '어둠', '불', '물', '땅', '바람', '신'];
  final List<String> types      = ['몬스터', '마법', '함정'];

  final Map<String, List<String>> subTypeMap = {
    '몬스터': ['일반', '효과', '융합', '싱크로', '엑시즈', '링크', '의식'],
    '마법':   ['일반', '지속', '속공', '장착', '필드', '의식'],
    '함정':   ['일반', '지속', '카운터'],
  };

  List<String> get currentSubTypes => subTypeMap[selectedType] ?? [];
  bool get _isMonster => selectedType == '몬스터';
  bool get _isExtra   => isExtraCard(selectedSubType);

  @override
  void dispose() {
    nameController.dispose();
    levelController.dispose();
    raceController.dispose();
    locationController.dispose();
    memoController.dispose();
    super.dispose();
  }

  void _onTypeChanged(String? value) {
    if (value == null) return;
    setState(() {
      selectedType    = value;
      selectedSubType = currentSubTypes.first;
      if (value != '몬스터') {
        selectedAttribute = '없음';
        levelController.clear();
        raceController.clear();
      }
    });
  }

  Future<void> _showImageSearchDialog() async {
    await showDialog(
      context: context,
      builder: (_) => CardImageSearchDialog(
        api: _api,
        onApply: ({
          required String cardName,
          required String engName,
          required String imageUrl,
          required String attribute,
          required int level,
          required String race,
          required String type,
          required String subType,
          required String desc,
        }) {
          setState(() {
            if (cardName.isNotEmpty) nameController.text = cardName;
            if (imageUrl.isNotEmpty) _cardImageUrl = imageUrl;
            _engName = engName; // ✅ 영문명 저장
            _cardDesc = desc;   // ✅ 효과 텍스트 저장

            if (type.isNotEmpty) {
              selectedType = type;
              final subTypes = subTypeMap[type] ?? [];
              selectedSubType =
                  subTypes.contains(subType) ? subType : subTypes.first;
            }

            if (type == '몬스터') {
              if (attribute.isNotEmpty && attribute != '없음') {
                selectedAttribute = attribute;
              }
              if (level > 0) levelController.text = level.toString();
              if (race.isNotEmpty) {
                final koRace = kRaceMap[race] ?? race;
                raceController.text = koRace;
              }
            } else {
              selectedAttribute = '없음';
              levelController.clear();
              raceController.clear();
              final mappedSubType = raceToSubType(race);
              if (mappedSubType != null) {
                final subTypes = subTypeMap[type] ?? [];
                if (subTypes.contains(mappedSubType)) {
                  selectedSubType = mappedSubType;
                }
              }
            }
          });
        },
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await service.addCard({
      'name':      nameController.text.trim(),
      'engName':   _engName, // ✅ 영문명 저장
      'desc':      _cardDesc,
      'attribute': _isMonster ? selectedAttribute : '',
      'level':     _isMonster ? (int.tryParse(levelController.text) ?? 0) : 0,
      'type':      selectedType,
      'subType':   selectedSubType,
      'race':      _isMonster ? raceController.text.trim() : '',
      'count':     count,
      'location':  locationController.text.trim(),
      'memo':      memoController.text.trim(),
      'imageUrl':  _cardImageUrl ?? '',
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        title: const Text('카드 추가',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: _showImageSearchDialog,
                    child: Container(
                      width: 72, height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _cardImageUrl != null
                              ? AppColors.accent
                              : AppColors.border,
                        ),
                      ),
                      child: _cardImageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(7),
                              child: Image.network(_cardImageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const _ImagePlaceholder()),
                            )
                          : const _ImagePlaceholder(),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('카드 이름 *'),
                        TextFormField(
                          controller: nameController,
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 14),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? '이름을 입력하세요'
                                  : null,
                          decoration: _inputDeco('카드 이름 입력'),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _showImageSearchDialog,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _cardImageUrl != null
                                  ? AppColors.accentLight
                                  : AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _cardImageUrl != null
                                    ? AppColors.accent.withOpacity(0.3)
                                    : AppColors.border,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _cardImageUrl != null
                                      ? Icons.check_circle_rounded
                                      : Icons.image_search_rounded,
                                  size: 15,
                                  color: _cardImageUrl != null
                                      ? AppColors.accent
                                      : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _cardImageUrl != null
                                      ? '이미지 변경'
                                      : '카드 이미지 검색',
                                  style: TextStyle(
                                    color: _cardImageUrl != null
                                        ? AppColors.accent
                                        : AppColors.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Row(
                          children: [
                            Icon(Icons.info_outline_rounded,
                                size: 11, color: AppColors.textMuted),
                            SizedBox(width: 4),
                            Text('한글 또는 영문 카드명으로 검색하세요',
                                style: TextStyle(
                                    color: AppColors.textMuted, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('타입 *'),
                        _buildDropdown(
                            value: selectedType,
                            items: types,
                            onChanged: _onTypeChanged),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          _buildLabel('유형'),
                          if (_isExtra) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDBEAFE),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('엑스트라',
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: Color(0xFF1D4ED8),
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ]),
                        _buildDropdown(
                          value: selectedSubType,
                          items: currentSubTypes,
                          onChanged: (v) =>
                              setState(() => selectedSubType = v!),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('속성'),
                        Opacity(
                          opacity: _isMonster ? 1.0 : 0.4,
                          child: _buildDropdown(
                            value: selectedAttribute,
                            items: attributes,
                            onChanged: _isMonster
                                ? (v) => setState(() => selectedAttribute = v!)
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('레벨'),
                        Opacity(
                          opacity: _isMonster ? 1.0 : 0.4,
                          child: TextFormField(
                            controller: levelController,
                            keyboardType: TextInputType.number,
                            enabled: _isMonster,
                            style: const TextStyle(
                                color: AppColors.textPrimary, fontSize: 14),
                            decoration: _inputDeco('0'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              if (_isMonster) ...[
                _buildLabel('종족'),
                TextFormField(
                  controller: raceController,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 14),
                  decoration: _inputDeco('예: 드래곤족, 전사족'),
                ),
                const SizedBox(height: 18),
              ],

              _buildLabel('수량'),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    _CountBtn(
                        icon: Icons.remove,
                        enabled: count > 1,
                        onTap: () => setState(() => count--)),
                    const SizedBox(width: 16),
                    Text('$count',
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(width: 16),
                    _CountBtn(
                        icon: Icons.add,
                        enabled: count < 99,
                        onTap: () => setState(() => count++)),
                    const Spacer(),
                    const Text('장',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              _buildLabel('위치'),
              TextFormField(
                controller: locationController,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 14),
                decoration: _inputDeco('예: 메인 덱, 사이드, 보관함 등 자유 입력'),
              ),

              const SizedBox(height: 18),

              _buildLabel('메모'),
              TextFormField(
                controller: memoController,
                maxLines: 3,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: _inputDeco('카드에 대한 메모를 입력하세요'),
              ),

              const SizedBox(height: 36),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('취소',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('저장',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Text(text,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      );

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: AppColors.accent, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?>? onChanged,
  }) =>
      DropdownButtonFormField<String>(
        value: items.contains(value) ? value : items.first,
        dropdownColor: AppColors.surface,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        icon: const Icon(Icons.keyboard_arrow_down_rounded,
            color: AppColors.textMuted),
        decoration: InputDecoration(
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppColors.accent, width: 1.5)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        items: items
            .map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(e,
                      style: const TextStyle(color: AppColors.textPrimary)),
                ))
            .toList(),
        onChanged: onChanged,
      );
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();
  @override
  Widget build(BuildContext context) => const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_outlined,
              color: AppColors.textMuted, size: 22),
          SizedBox(height: 4),
          Text('이미지\n검색',
              style: TextStyle(color: AppColors.textMuted, fontSize: 10),
              textAlign: TextAlign.center),
        ],
      );
}

class _CountBtn extends StatelessWidget {
  final IconData  icon;
  final bool      enabled;
  final VoidCallback onTap;
  const _CountBtn(
      {required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: enabled ? AppColors.accentLight : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: enabled
                    ? AppColors.accent.withOpacity(0.3)
                    : AppColors.border),
          ),
          child: Icon(icon,
              size: 17,
              color: enabled ? AppColors.accent : AppColors.textMuted),
        ),
      );
}

