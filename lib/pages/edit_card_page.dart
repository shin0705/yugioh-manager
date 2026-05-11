import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/firestore_service.dart';
import '../services/yugioh_api_service.dart';
import '../dialog/image_search_dialog.dart';
import '../main.dart' show AppColors;

class EditCardPage extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;

  const EditCardPage({super.key, required this.docId, required this.data});

  @override
  State<EditCardPage> createState() => _EditCardPageState();
}

class _EditCardPageState extends State<EditCardPage> {
  final FirestoreService _service = FirestoreService();
  final _api = YugiohApiService();

  late String attribute;
  late int    level;
  late String type;
  late String subType;
  late int    count;
  late String _engName;
  late String _cardDesc;
  String? _cardImageUrl;

  final nameController     = TextEditingController();
  final raceController     = TextEditingController();
  final locationController = TextEditingController();
  final memoController     = TextEditingController();

  List<String> subTypeOptions = [];

  @override
  void initState() {
    super.initState();
    final data = widget.data;

    attribute     = data['attribute'] ?? '';
    level         = data['level']     ?? 0;
    type          = data['type']      ?? '몬스터';
    subType       = data['subType']   ?? '';
    count         = data['count']     ?? 1;
    _engName      = data['engName']   ?? ''; // ✅ 영문명 로드
    _cardDesc     = data['desc']      ?? ''; // ✅ 효과 텍스트 로드
    _cardImageUrl = (data['imageUrl'] ?? '').toString().isEmpty
        ? null
        : data['imageUrl'] as String;

    nameController.text     = data['name']     ?? '';
    raceController.text     = data['race']     ?? '';
    locationController.text = data['location'] ?? '';
    memoController.text     = data['memo']     ?? '';

    updateSubTypeOptions();
    if (!subTypeOptions.contains(subType)) {
      subType = subTypeOptions.isNotEmpty ? subTypeOptions.first : '';
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    raceController.dispose();
    locationController.dispose();
    memoController.dispose();
    super.dispose();
  }

  void updateSubTypeOptions() {
    if (type == '몬스터') {
      subTypeOptions = ['일반', '효과', '융합', '싱크로', '엑시즈', '링크', '의식'];
    } else if (type == '마법') {
      subTypeOptions = ['일반', '지속', '속공', '장착', '필드', '의식'];
    } else if (type == '함정') {
      subTypeOptions = ['일반', '지속', '카운터'];
    } else {
      subTypeOptions = [];
    }
  }

  late final TextEditingController levelController =
      TextEditingController(text: level.toString());

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
            if (attribute.isNotEmpty) this.attribute = attribute;
            if (level > 0) levelController.text = level.toString();
            if (race.isNotEmpty) raceController.text = race;
            _engName = engName; // ✅ 영문명 업데이트
            _cardDesc = desc;   // ✅ 효과 텍스트 업데이트
            if (type.isNotEmpty) {
              this.type = type;
              updateSubTypeOptions();
              this.subType = subTypeOptions.contains(subType)
                  ? subType
                  : (subTypeOptions.isNotEmpty ? subTypeOptions.first : '');
            }
          });
        },
      ),
    );
  }

  Future<void> _updateCard() async {
    await _service.updateCard(widget.docId, {
      'name':      nameController.text.trim(),
      'engName':   _engName, // ✅ 영문명 저장
      'desc':      _cardDesc,
      'attribute': attribute,
      'level':     int.tryParse(levelController.text) ?? level,
      'type':      type,
      'race':      raceController.text.trim(),
      'subType':   subType,
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
        title: const Text('카드 수정',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: SingleChildScrollView(
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
                            child: CachedNetworkImage(
                              imageUrl: _cardImageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                width: 72,
                                height: 100,
                                color: AppColors.surfaceAlt,
                                child: const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) =>
                                  const _ImagePlaceholder(),
                            ),
                          )
                        : const _ImagePlaceholder(),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('카드 이름'),
                      _buildTextField(
                          controller: nameController, hint: '카드 이름'),
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
                      _buildLabel('타입'),
                      _buildDropdown(
                        value: type,
                        items: ['몬스터', '마법', '함정'],
                        onChanged: (value) {
                          setState(() {
                            type = value!;
                            updateSubTypeOptions();
                            subType = subTypeOptions.isNotEmpty
                                ? subTypeOptions.first
                                : '';
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('유형'),
                      _buildDropdown(
                        value: subTypeOptions.contains(subType)
                            ? subType
                            : null,
                        items: subTypeOptions,
                        onChanged: (value) =>
                            setState(() => subType = value ?? ''),
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
                        opacity: type == '몬스터' ? 1.0 : 0.4,
                        child: _buildDropdown(
                          value: ['없음', '빛', '어둠', '불', '물', '땅', '바람', '신']
                                  .contains(attribute)
                              ? attribute
                              : '없음',
                          items: ['없음', '빛', '어둠', '불', '물', '땅', '바람', '신'],
                          onChanged: type == '몬스터'
                              ? (v) => setState(() => attribute = v!)
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
                        opacity: type == '몬스터' ? 1.0 : 0.4,
                        child: _buildTextField(
                          controller: levelController,
                          hint: '0',
                          keyboardType: TextInputType.number,
                          enabled: type == '몬스터',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            _buildLabel('종족'),
            _buildTextField(controller: raceController, hint: '예: 드래곤족'),

            const SizedBox(height: 18),

            _buildLabel('수량'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                    onTap: () => setState(() => count--),
                  ),
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
                    onTap: () => setState(() => count++),
                  ),
                  const Spacer(),
                  const Text('장',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            ),

            const SizedBox(height: 18),

            _buildLabel('위치'),
            _buildTextField(
              controller: locationController,
              hint: '예: 메인 덱, 사이드, 보관함 등 자유 입력',
            ),

            const SizedBox(height: 18),

            _buildLabel('메모'),
            _buildTextField(
              controller: memoController,
              hint: '카드에 대한 메모를 입력하세요',
              maxLines: 3,
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
                    onPressed: _updateCard,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('수정 완료',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
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

  Widget _buildTextField({
    required TextEditingController controller,
    String? hint,
    TextInputType? keyboardType,
    bool enabled = true,
    int? maxLines = 1,
  }) =>
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        enabled: enabled,
        maxLines: maxLines,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
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
        ),
      );

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required ValueChanged<String?>? onChanged,
  }) =>
      DropdownButtonFormField<String>(
        value: items.contains(value)
            ? value
            : (items.isNotEmpty ? items.first : null),
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
                      style:
                          const TextStyle(color: AppColors.textPrimary)),
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
  final IconData icon;
  final bool enabled;
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
