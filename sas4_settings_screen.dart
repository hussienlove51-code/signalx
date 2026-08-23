import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/sas4_service.dart';
import '../services/supabase_service.dart';

class SAS4SettingsScreen extends StatefulWidget {
  const SAS4SettingsScreen({super.key});
  @override
  State<SAS4SettingsScreen> createState() => _SAS4SettingsScreenState();
}

class _SAS4SettingsScreenState extends State<SAS4SettingsScreen> {
  final _urlCtrl  = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _isTesting   = false;
  bool _isSyncing   = false;
  String? _connectionStatus; // 'success' | 'error' | null
  SyncResult? _lastSync;

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
  }

  Future<void> _loadSavedSettings() async {
    await SAS4Service.loadSettings();
    // TODO: اعرض القيم المحفوظة (بعد إضافة getters)
  }

  // ─── اختبار الاتصال ─────────────────────────────
  Future<void> _testConnection() async {
    if (_urlCtrl.text.isEmpty || _userCtrl.text.isEmpty) {
      _showSnack('أدخل الرابط واسم المستخدم أولاً', isError: true);
      return;
    }
    setState(() { _isTesting = true; _connectionStatus = null; });

    final ok = await SAS4Service.testConnection(
      url:      _urlCtrl.text.trim(),
      username: _userCtrl.text.trim(),
      password: _passCtrl.text,
    );

    setState(() {
      _isTesting = false;
      _connectionStatus = ok ? 'success' : 'error';
    });

    if (ok) {
      await SAS4Service.saveSettings(
        url:      _urlCtrl.text.trim(),
        username: _userCtrl.text.trim(),
        password: _passCtrl.text,
      );
      _showSnack('✓ الاتصال ناجح! تم حفظ الإعدادات');
    } else {
      _showSnack('✗ فشل الاتصال — تحقق من الرابط وبيانات الدخول', isError: true);
    }
  }

  // ─── المزامنة ────────────────────────────────────
  Future<void> _syncNow() async {
    if (!SAS4Service.isConfigured) {
      _showSnack('اضبط إعدادات SAS4 أولاً', isError: true);
      return;
    }
    setState(() { _isSyncing = true; _lastSync = null; });

    final result = await SAS4Service.syncWithSupabase();

    setState(() {
      _isSyncing = false;
      _lastSync  = result;
    });

    _showSnack(
      result.success
          ? '✓ تمت المزامنة — ${result.synced} مشترك'
          : '✗ فشلت المزامنة: ${result.error}',
      isError: !result.success,
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: const TextStyle(fontFamily: 'Cairo', color: Colors.white)),
        backgroundColor: isError ? AppColors.red : AppColors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات SAS4')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── بطاقة المعلومات ──
            _infoCard(),
            const SizedBox(height: 20),

            // ── حقول الإعداد ──
            _sectionLabel('بيانات الخادم'),
            const SizedBox(height: 10),
            _buildField(
              controller: _urlCtrl,
              label: 'رابط SAS4',
              hint: 'http://192.168.1.1 أو http://yourdomain.com',
              icon: Icons.link_rounded,
            ),
            const SizedBox(height: 10),
            _buildField(
              controller: _userCtrl,
              label: 'اسم المستخدم (المدير)',
              hint: 'manager_username',
              icon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: 10),
            _buildField(
              controller: _passCtrl,
              label: 'كلمة المرور',
              hint: '••••••••',
              icon: Icons.lock_outline_rounded,
              isPassword: true,
            ),
            const SizedBox(height: 16),

            // ── زر اختبار الاتصال ──
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isTesting ? null : _testConnection,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.neon,
                  side: const BorderSide(color: AppColors.neon),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: _isTesting
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.neon))
                    : const Icon(Icons.wifi_tethering_rounded),
                label: Text(
                  _isTesting ? 'جاري الاختبار...' : 'اختبار الاتصال',
                  style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600),
                ),
              ),
            ),

            // ── مؤشر نتيجة الاتصال ──
            if (_connectionStatus != null) ...[
              const SizedBox(height: 10),
              _connectionBadge(),
            ],

            const SizedBox(height: 28),
            const Divider(color: AppColors.border),
            const SizedBox(height: 20),

            // ── قسم المزامنة ──
            _sectionLabel('مزامنة المشتركين'),
            const SizedBox(height: 6),
            Text(
              'يجلب كل المشتركين من SAS4 ويحفظهم في قاعدة بيانات التطبيق تلقائياً.',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textMuted, fontFamily: 'Cairo'),
            ),
            const SizedBox(height: 14),

            // ── بطاقة آخر مزامنة ──
            if (_lastSync != null) _syncResultCard(_lastSync!),
            const SizedBox(height: 12),

            // ── زر المزامنة ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSyncing ? null : _syncNow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.neon,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: _isSyncing
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.sync_rounded),
                label: Text(
                  _isSyncing ? 'جاري المزامنة...' : 'مزامنة الآن',
                  style: const TextStyle(
                      fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── مزامنة تلقائية ──
            _autoSyncCard(),
          ],
        ),
      ),
    );
  }

  Widget _infoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.neonGlow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neon.withOpacity(0.3), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.neon.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.hub_rounded, color: AppColors.neon, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ربط SAS4 Radius',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                        color: AppColors.neon, fontFamily: 'Cairo')),
                SizedBox(height: 3),
                Text('ربط التطبيق بخادم SAS4 لجلب المشتركين ومزامنتهم تلقائياً.',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary,
                        fontFamily: 'Cairo')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text,
        style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted,
            letterSpacing: 0.5, fontFamily: 'Cairo'));
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword && _obscurePass,
      style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo', fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.textMuted, size: 18),
        suffixIcon: isPassword
            ? IconButton(
                onPressed: () => setState(() => _obscurePass = !_obscurePass),
                icon: Icon(
                  _obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppColors.textMuted, size: 18,
                ),
              )
            : null,
      ),
    );
  }

  Widget _connectionBadge() {
    final isSuccess = _connectionStatus == 'success';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isSuccess ? AppColors.greenGlow : AppColors.redGlow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isSuccess ? AppColors.green : AppColors.red).withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle_outline : Icons.error_outline,
            color: isSuccess ? AppColors.green : AppColors.red,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            isSuccess ? 'الاتصال ناجح — جاهز للمزامنة' : 'فشل الاتصال بـ SAS4',
            style: TextStyle(
                fontSize: 12, fontFamily: 'Cairo', fontWeight: FontWeight.w600,
                color: isSuccess ? AppColors.green : AppColors.red),
          ),
        ],
      ),
    );
  }

  Widget _syncResultCard(SyncResult result) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          _syncStat('${result.total}',  'إجمالي',   AppColors.textSecondary),
          _syncStat('${result.synced}', 'تم',        AppColors.green),
          _syncStat('${result.failed}', 'فشل',       AppColors.red),
        ],
      ),
    );
  }

  Widget _syncStat(String val, String lbl, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(val, style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w700,
              color: color, fontFamily: 'Cairo')),
          Text(lbl, style: const TextStyle(
              fontSize: 11, color: AppColors.textMuted, fontFamily: 'Cairo')),
        ],
      ),
    );
  }

  Widget _autoSyncCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.autorenew_rounded, color: AppColors.textMuted, size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('مزامنة تلقائية',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary, fontFamily: 'Cairo')),
                Text('كل 6 ساعات تلقائياً',
                    style: TextStyle(fontSize: 11,
                        color: AppColors.textMuted, fontFamily: 'Cairo')),
              ],
            ),
          ),
          Switch(
            value: true,
            onChanged: (_) {},
            activeColor: AppColors.neon,
          ),
        ],
      ),
    );
  }
}
