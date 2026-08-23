import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/backup_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  List<BackupFile> _backups    = [];
  bool _isLoading              = true;
  bool _isCreating             = false;
  String? _lastBackupText;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final backups = await BackupService.getBackupsList();
    final lastTxt = await BackupService.getLastBackupText();
    setState(() {
      _backups         = backups;
      _lastBackupText  = lastTxt;
      _isLoading       = false;
    });
  }

  Future<void> _createBackup() async {
    setState(() => _isCreating = true);
    final result = await BackupService.createBackup(manual: true);
    setState(() => _isCreating = false);

    _showSnack(result.message,
        result.success ? AppColors.green : AppColors.red);

    if (result.success) await _load();
  }

  Future<void> _shareBackup(BackupFile b) async {
    await BackupService.shareBackup(b.file);
  }

  Future<void> _restoreBackup(BackupFile b) async {
    final ok = await _confirm(
      'استعادة النسخة الاحتياطية',
      'سيتم استبدال البيانات الحالية بهذه النسخة.\nهل أنت متأكد؟',
    );
    if (!ok) return;

    _showSnack('جاري الاستعادة...', AppColors.surface);
    final result = await BackupService.restoreFromFile(b.file);
    _showSnack(result.message,
        result.success ? AppColors.green : AppColors.red);
  }

  Future<void> _deleteBackup(BackupFile b) async {
    final ok = await _confirm(
      'حذف النسخة الاحتياطية',
      'هل تريد حذف هذه النسخة؟ لا يمكن التراجع.',
    );
    if (!ok) return;
    await b.file.delete();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('النسخ الاحتياطية')),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.neon))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // ─── بطاقة الحالة ───
                  _statusCard(),
                  const SizedBox(height: 12),

                  // ─── زر إنشاء نسخة ───
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isCreating ? null : _createBackup,
                      icon: _isCreating
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.backup_rounded, size: 20),
                      label: Text(
                        _isCreating
                            ? 'جاري الإنشاء...'
                            : 'إنشاء نسخة احتياطية الآن',
                        style: const TextStyle(
                            fontFamily: 'Cairo', fontSize: 14,
                            fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ─── قائمة النسخ ───
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('النسخ المحفوظة',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              fontFamily: 'Cairo')),
                      Text('${_backups.length} / 7',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textMuted,
                              fontFamily: 'Cairo')),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (_backups.isEmpty)
                    _emptyState()
                  else
                    ..._backups.asMap().entries.map(
                        (e) => _backupCard(e.value, isLatest: e.key == 0)),
                ],
              ),
            ),
    );
  }

  Widget _statusCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: AppColors.neonGlow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.cloud_done_rounded,
                    color: AppColors.neon, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('آخر نسخة احتياطية',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textMuted,
                            fontFamily: 'Cairo')),
                    Text(_lastBackupText ?? '—',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            fontFamily: 'Cairo')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              _infoChip(Icons.autorenew_rounded,
                  'تلقائي يومياً', AppColors.neon),
              const SizedBox(width: 8),
              _infoChip(Icons.history_rounded,
                  'آخر 7 نسخ', AppColors.purple),
              const SizedBox(width: 8),
              _infoChip(Icons.share_rounded,
                  'قابل للمشاركة', AppColors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 10, color: color, fontFamily: 'Cairo',
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }

  Widget _backupCard(BackupFile b, {required bool isLatest}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLatest ? AppColors.neon : AppColors.border,
          width: isLatest ? 1 : 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: isLatest
                  ? AppColors.neonGlow
                  : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.folder_zip_rounded,
                color: isLatest ? AppColors.neon : AppColors.textMuted,
                size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(b.dateText,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            fontFamily: 'Cairo')),
                    if (isLatest) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.neonGlow,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('أحدث',
                            style: TextStyle(
                                fontSize: 9, color: AppColors.neon,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Cairo')),
                      ),
                    ],
                  ],
                ),
                Text(b.sizeText,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted,
                        fontFamily: 'Cairo')),
              ],
            ),
          ),
          // أزرار الإجراءات
          Row(
            children: [
              _iconBtn(Icons.share_rounded, AppColors.neon,
                  () => _shareBackup(b)),
              const SizedBox(width: 4),
              _iconBtn(Icons.restore_rounded, AppColors.green,
                  () => _restoreBackup(b)),
              const SizedBox(width: 4),
              _iconBtn(Icons.delete_outline_rounded, AppColors.red,
                  () => _deleteBackup(b)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: const Column(
        children: [
          Icon(Icons.cloud_off_rounded,
              size: 48, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text('لا توجد نسخ احتياطية بعد',
              style: TextStyle(
                  color: AppColors.textMuted, fontFamily: 'Cairo',
                  fontSize: 13)),
          SizedBox(height: 6),
          Text('اضغط الزر أعلاه لإنشاء أول نسخة',
              style: TextStyle(
                  color: AppColors.textDim, fontFamily: 'Cairo',
                  fontSize: 11)),
        ],
      ),
    );
  }

  Future<bool> _confirm(String title, String msg) async {
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: const TextStyle(
                color: AppColors.textPrimary, fontFamily: 'Cairo',
                fontWeight: FontWeight.w700, fontSize: 15)),
        content: Text(msg,
            style: const TextStyle(
                color: AppColors.textSecondary, fontFamily: 'Cairo',
                fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء',
                style: TextStyle(
                    color: AppColors.textMuted, fontFamily: 'Cairo')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأكيد',
                style: TextStyle(
                    color: AppColors.neon, fontFamily: 'Cairo',
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: color,
      duration: const Duration(seconds: 3),
    ));
  }
}
