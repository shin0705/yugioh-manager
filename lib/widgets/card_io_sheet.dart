// lib/widgets/card_io_sheet.dart
// 카드 내보내기 / 가져오기 / 일괄 추가 바텀시트

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/card_io_service.dart';
import '../main.dart' show AppColors;

// ── 진입점 ──────────────────────────────────────────────────
Future<void> showCardIOSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _CardIOSheet(),
  );
}

// ── 메인 시트 ────────────────────────────────────────────────
class _CardIOSheet extends StatefulWidget {
  const _CardIOSheet();

  @override
  State<_CardIOSheet> createState() => _CardIOSheetState();
}

class _CardIOSheetState extends State<_CardIOSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _io = CardIOService();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: SizedBox(
        height: mq.size.height * 0.75,
        child: Column(
          children: [
            // 핸들
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // 제목
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.import_export_rounded,
                      color: AppColors.accent, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    '카드 데이터 관리',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 28,
                      height: 28,
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

            const SizedBox(height: 12),

            // 탭
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: TabBar(
                  controller: _tab,
                  indicator: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: '📤  내보내기'),
                    Tab(text: '📥  가져오기'),
                    Tab(text: '✏️  일괄 추가'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 4),

            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _ExportTab(io: _io),
                  _ImportTab(io: _io),
                  _BulkAddTab(io: _io),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 탭 1: 내보내기 ───────────────────────────────────────────
class _ExportTab extends StatefulWidget {
  final CardIOService io;
  const _ExportTab({required this.io});

  @override
  State<_ExportTab> createState() => _ExportTabState();
}

class _ExportTabState extends State<_ExportTab> {
  bool _loading = false;
  String? _result;

  Future<void> _export() async {
    setState(() { _loading = true; _result = null; });
    try {
      final csv = await widget.io.exportToCsv();
      widget.io.downloadCsv(csv);
      setState(() => _result = '✅ 내보내기 완료! 파일이 다운로드됩니다.');
    } catch (e) {
      setState(() => _result = '❌ 오류: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoCard(
            icon: Icons.table_chart_rounded,
            title: 'CSV 파일로 내보내기',
            desc: '보유 카드 전체를 CSV 파일로 저장합니다.\n'
                '엑셀, 구글 시트 등에서 열 수 있습니다.\n'
                '포함 항목: 이름, 영문명, 타입, 유형, 속성, 레벨, 종족, 수량, 위치, 이미지URL',
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _export,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.download_rounded, size: 18),
              label: Text(_loading ? '처리 중...' : 'CSV 다운로드'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 12),
            _ResultBanner(message: _result!),
          ],
        ],
      ),
    );
  }
}

// ── 탭 2: 가져오기 ───────────────────────────────────────────
class _ImportTab extends StatefulWidget {
  final CardIOService io;
  const _ImportTab({required this.io});

  @override
  State<_ImportTab> createState() => _ImportTabState();
}

class _ImportTabState extends State<_ImportTab> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _result;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final csv = _ctrl.text.trim();
    if (csv.isEmpty) {
      setState(() => _result = '❌ CSV 데이터를 붙여넣어 주세요.');
      return;
    }
    setState(() { _loading = true; _result = null; });
    try {
      final r = await widget.io.importFromCsv(csv);
      String msg = '✅ 완료! 추가 ${r.added}개, 업데이트 ${r.updated}개';
      if (r.failed.isNotEmpty) {
        msg += '\n⚠️ 실패한 행: ${r.failed.join(', ')}';
      }
      setState(() { _result = msg; _ctrl.clear(); });
    } catch (e) {
      setState(() => _result = '❌ 오류: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoCard(
            icon: Icons.upload_file_rounded,
            title: 'CSV 붙여넣기로 가져오기',
            desc: 'CSV 내용을 아래에 붙여넣으세요.\n'
                '첫 행은 헤더(name, type, count 등)여야 합니다.\n'
                '이름이 같은 카드는 정보가 업데이트됩니다.',
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _ctrl,
              maxLines: 8,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 12,
                  fontFamily: 'monospace'),
              decoration: const InputDecoration(
                hintText: 'name,type,subType,attribute,level,race,count,location\n'
                    '블루아이즈 화이트 드래곤,몬스터,일반,빛,8,드래곤족,3,메인덱\n'
                    '...',
                hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 11),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    if (data?.text != null) {
                      _ctrl.text = data!.text!;
                    }
                  },
                  icon: const Icon(Icons.paste_rounded, size: 16),
                  label: const Text('클립보드 붙여넣기'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _import,
                  icon: _loading
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.upload_rounded, size: 18),
                  label: Text(_loading ? '처리 중...' : '가져오기 실행'),
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
          ),
          if (_result != null) ...[
            const SizedBox(height: 12),
            _ResultBanner(message: _result!),
          ],
        ],
      ),
    );
  }
}

// ── 탭 3: 일괄 추가 ─────────────────────────────────────────
class _BulkAddTab extends StatefulWidget {
  final CardIOService io;
  const _BulkAddTab({required this.io});

  @override
  State<_BulkAddTab> createState() => _BulkAddTabState();
}

class _BulkAddTabState extends State<_BulkAddTab> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _result;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _bulkAdd() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      setState(() => _result = '❌ 카드 이름을 입력하세요.');
      return;
    }
    setState(() { _loading = true; _result = null; });
    try {
      final r = await widget.io.bulkAddByName(text);
      String msg = '✅ 완료! 신규 ${r.added}개, 수량 증가 ${r.increased}개';
      if (r.failed.isNotEmpty) {
        msg += '\n⚠️ 실패: ${r.failed.join(', ')}';
      }
      setState(() { _result = msg; _ctrl.clear(); });
    } catch (e) {
      setState(() => _result = '❌ 오류: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoCard(
            icon: Icons.playlist_add_rounded,
            title: '카드 이름으로 일괄 추가',
            desc: '한 줄에 카드 이름 하나씩 입력하세요.\n'
                '이미 있는 카드는 수량이 1 증가합니다.\n'
                '새 카드는 기본값(몬스터/효과/수량 1)으로 추가됩니다.',
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _ctrl,
              maxLines: 10,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 13),
              decoration: const InputDecoration(
                hintText: '블루아이즈 화이트 드래곤\n다크 매지션\n하루 우라라\n...',
                hintStyle: TextStyle(color: AppColors.textMuted),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _bulkAdd,
              icon: _loading
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.add_rounded, size: 18),
              label: Text(_loading ? '처리 중...' : '일괄 추가 실행'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.monster,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 12),
            _ResultBanner(message: _result!),
          ],
        ],
      ),
    );
  }
}

// ── 공통 위젯 ────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.accent.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(desc,
                    style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 11,
                        height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  final String message;
  const _ResultBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final isError = message.startsWith('❌');
    final color = isError ? Colors.redAccent : AppColors.magic;
    final bgColor = isError
        ? const Color(0xFFFEE2E2)
        : const Color(0xFFECFDF5);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        message,
        style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.w600,
            height: 1.5),
      ),
    );
  }
}
