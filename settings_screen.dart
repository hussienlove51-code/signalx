import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/sync_service.dart';
import '../services/sas4_service.dart';
import '../services/supabase_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // SAS4
  final _sas4UrlCtrl  = TextEditingController();
  final _sas4UserCtrl = TextEditingController();
  final _sas4PassCtrl = TextEditingController();
  bool _sas4Testing   = false;
  bool _sas4Connected = false;
  String? _sas4Msg;

  // Supabase
  final _sbUrlCtrl  = TextEditingController();
  final _sbKeyCtrl  = TextEditingController();

  // إعدادات عامة
  bool _autoSync       = true;
  bool _notifications  = true;
  bool _darkMode       = true;
  int  _syncInterval   = 5;
  int  _expiryWarnDays = 7;

  // مزامنة
  bool _isSyncing   = false;
  SyncResult? _syncResult;

  // معلومات التطبيق
  static const _version = '1.0.0';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _sas4UrlCtrl.text  = p.getString('sas4_url')  ?? '';
      _sas4UserCtrl.text = p.getString('sas4_user') ?? '';
      _sas4PassCtrl.text = p.getString('sas4_pass') ?? '';
      _sbUrlCtrl.text    = p.getString('sb_url')    ?? '';
      _sbKeyCtrl.text    = p.getString('sb_key')    ?? '';
      _autoSync          = p.getBool('auto_sync')   ?? true;
      _notifications     = p.getBool('notifs')      ?? true;
      _syncInterval      = p.getInt('sync_interval') ?? 5;
      _expiryWarnDays    = p.getInt('expiry_days')  ?? 7;
    });
  }

  Future<void> _savePrefs() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('sas4_url',  _sas4UrlCtrl.text.trim());
    await p.setString('sas4_user', _sas4UserCtrl.text.trim());
    await p.setString('sas4_pass', _sas4PassCtrl.text.trim());
    await p.setString('sb_url',    _sbUrlCtrl.text.trim());
    await p.setString('sb_key',    _sbKeyCtrl.text.trim());
    await p.setBool('auto_sync',    _autoSync);
    await p.setBool('notifs',       _notifications);
    await p.setInt('sync_interval', _syncInterval);
    await p.setInt('expiry_days',   _expiryWarnDays);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم الحفظ ✓', style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppColors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _testSAS4() async {
    setState(() { _sas4Testing = true; _sas4Msg = null; });
    final ok = await SAS4Service.login();
    setState(() {
      _sas4Testing   = false;
      _sas4Connected = ok;
      _sas4Msg = ok
          ? '✓ الاتصال ناجح — SAS4 متصل'
          : '✗ فشل الاتصال — تحقق من الرابط وبيانات الدخول';
    });
  }

  Future<void> _runSync() async {
    setState(() { _isSyncing = true; _syncResult = null; });
    final r = await SyncService.syncAll(force: true);
    setState(() { _isSyncing = false; _syncResult = r; });
  }

  Future<void> _clearCache() async {
    final p = await SharedPreferences.getInstance();
    await p.clear();
    setState(() {
      _sas4UrlCtrl.clear(); _sas4UserCtrl.clear(); _sas4PassCtrl.clear();
      _sbUrlCtrl.clear();   _sbKeyCtrl.clear();
    });
    if (mounted) _showSnack('تم مسح البيانات المحلية', AppColors.orange);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
        actions: [
          TextButton.icon(
            onPressed: _savePrefs,
            icon: const Icon(Icons.save_rounded, size: 18, color: AppColors.neon),
            label: const Text('حفظ',
                style: TextStyle(color: AppColors.neon, fontFamily: 'Cairo',
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── SAS4 ──────────────────────
            _section('🗼  إعدادات SAS4', [
              _field('رابط السيرفر', _sas4UrlCtrl, Icons.dns_rounded,
                  hint: 'http://192.168.1.1'),
              _gap,
              _field('اسم المدير', _sas4UserCtrl, Icons.person_rounded,
                  hint: 'manager'),
              _gap,
              _field('كلمة المرور', _sas4PassCtrl, Icons.lock_rounded,
                  hint: '••••••', obscure: true),
              _gap,
              _outlineBtn(
                label: _sas4Testing ? 'جاري الاختبار...' : 'اختبار الاتصال',
                icon: Icons.wifi_find_rounded,
                onTap: _sas4Testing ? null : _testSAS4,
                loading: _sas4Testing,
              ),
              if (_sas4Msg != null) ...[
                _gap,
                _alertBox(_sas4Msg!, _sas4Connected ? AppColors.green : AppColors.red),
              ],
            ]),

            _gap16,

            // ── Supabase ──────────────────
            _section('🟢  إعدادات Supabase', [
              _field('Project URL', _sbUrlCtrl, Icons.cloud_rounded,
                  hint: 'https://xxxx.supabase.co'),
              _gap,
              _field('Anon Key', _sbKeyCtrl, Icons.key_rounded,
                  hint: 'eyJ...', obscure: true),
            ]),

            _gap16,

            // ── المزامنة ──────────────────
            _section('🔄  المزامنة', [
              _switchRow('مزامنة تلقائية', _autoSync,
                  (v) => setState(() => _autoSync = v)),
              if (_autoSync) ...[
                _gap,
                _sliderRow(
                  label: 'كل $_syncInterval دقائق',
                  value: _syncInterval.toDouble(),
                  min: 1, max: 30,
                  onChanged: (v) => setState(() => _syncInterval = v.toInt()),
                ),
              ],
              _gap,
              _primaryBtn(
                label: _isSyncing ? 'جاري المزامنة...' : 'مزامنة الآن',
                icon: Icons.sync_rounded,
                onTap: _isSyncing ? null : _runSync,
                loading: _isSyncing,
              ),
              if (_syncResult != null) ...[
                _gap,
                _syncResultCard(_syncResult!),
              ],
              _gap,
              Row(children: [
                const Icon(Icons.access_time_rounded,
                    size: 13, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text('آخر مزامنة: ${SyncService.lastSyncText}',
                    style: const TextStyle(fontSize: 11,
                        color: AppColors.textMuted, fontFamily: 'Cairo')),
              ]),
            ]),

            _gap16,

            // ── الإشعارات ─────────────────
            _section('🔔  الإشعارات', [
              _switchRow('تفعيل الإشعارات', _notifications,
                  (v) => setState(() => _notifications = v)),
              if (_notifications) ...[
                _gap,
                _sliderRow(
                  label: 'تنبيه قبل $_expiryWarnDays أيام',
                  value: _expiryWarnDays.toDouble(),
                  min: 1, max: 14,
                  onChanged: (v) => setState(() => _expiryWarnDays = v.toInt()),
                ),
              ],
            ]),

            _gap16,

            // ── معلومات التطبيق ───────────
            _section('ℹ️  معلومات التطبيق', [
              _infoRow('الإصدار', _version),
              _divider,
              _infoRow('قاعدة البيانات', 'Supabase + SASv4'),
              _divider,
              _infoRow('التقنية', 'Flutter 3.x / Dart'),
              _divider,
              _infoRow('المطور', 'SignalX Team'),
            ]),

            _gap16,

            // ── خطر ───────────────────────
            _section('⚠️  منطقة الخطر', [
              _dangerBtn(
                label: 'مسح البيانات المحلية',
                icon: Icons.delete_sweep_rounded,
                onTap: () => _confirmDanger(
                  'مسح البيانات المحلية',
                  'سيتم مسح كل الإعدادات المحفوظة. هل أنت متأكد؟',
                  _clearCache,
                ),
              ),
            ]),

            const SizedBox(height: 32),

            // ── Footer ────────────────────
            const Text('SignalX v1.0.0 — إدارة أبراج الإنترنت',
                style: TextStyle(fontSize: 11,
                    color: AppColors.textMuted, fontFamily: 'Cairo')),
            const SizedBox(height: 4),
            const Text('Powered by Flutter + SASv4 + Supabase',
                style: TextStyle(fontSize: 10,
                    color: AppColors.textDim, fontFamily: 'Cairo')),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ─── Widgets مساعدة ───────────────────

  Widget _section(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Text(title,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary, fontFamily: 'Cairo')),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, IconData icon,
      {String hint = '', bool obscure = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(
            fontSize: 11, color: AppColors.textMuted, fontFamily: 'Cairo')),
        const SizedBox(height: 5),
        TextField(
          controller: ctrl,
          obscureText: obscure,
          style: const TextStyle(
              color: AppColors.textPrimary, fontFamily: 'Cairo', fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppColors.textMuted, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _switchRow(String label, bool val, ValueChanged<bool> onChange) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(
            fontSize: 13, color: AppColors.textPrimary, fontFamily: 'Cairo')),
        Switch(value: val, onChanged: onChange, activeColor: AppColors.neon),
      ],
    );
  }

  Widget _sliderRow({required String label, required double value,
      required double min, required double max,
      required ValueChanged<double> onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(
            fontSize: 12, color: AppColors.textMuted, fontFamily: 'Cairo')),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.neon,
            inactiveTrackColor: AppColors.border,
            thumbColor: AppColors.neon,
            overlayColor: AppColors.neonGlow,
          ),
          child: Slider(
            value: value, min: min, max: max,
            divisions: (max - min).toInt(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _primaryBtn({required String label, required IconData icon,
      VoidCallback? onTap, bool loading = false}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: loading
            ? const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Icon(icon, size: 18),
        label: Text(label,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
      ),
    );
  }

  Widget _outlineBtn({required String label, required IconData icon,
      VoidCallback? onTap, bool loading = false}) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: loading
            ? const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.neon))
            : Icon(icon, size: 18, color: AppColors.neon),
        label: Text(label,
            style: const TextStyle(
                fontFamily: 'Cairo', fontSize: 13, color: AppColors.neon)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.neon),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _dangerBtn({required String label, required IconData icon,
      required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: AppColors.red),
        label: Text(label,
            style: const TextStyle(
                fontFamily: 'Cairo', color: AppColors.red, fontSize: 13)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.red, width: 0.8),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _alertBox(String msg, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            color == AppColors.green
                ? Icons.check_circle_rounded
                : Icons.error_rounded,
            color: color, size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(msg,
                style: TextStyle(fontSize: 12, color: color,
                    fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }

  Widget _syncResultCard(SyncResult r) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: r.success ? AppColors.greenGlow : AppColors.redGlow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: r.success
              ? AppColors.green.withOpacity(0.3)
              : AppColors.red.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(r.message,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  fontFamily: 'Cairo',
                  color: r.success ? AppColors.green : AppColors.red)),
          if (r.success) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _syncStat('${r.added}',     'مضاف',          AppColors.neon),
                _syncStat('${r.updated}',   'محدّث',         AppColors.orange),
                _syncStat('${r.unchanged}', 'بدون تغيير',    AppColors.textMuted),
                _syncStat('${r.totalFromSAS4}', 'من SAS4',   AppColors.green),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _syncStat(String val, String lbl, Color color) {
    return Column(
      children: [
        Text(val, style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700,
            color: color, fontFamily: 'Cairo')),
        Text(lbl, style: const TextStyle(
            fontSize: 10, color: AppColors.textMuted, fontFamily: 'Cairo')),
      ],
    );
  }

  Widget _infoRow(String lbl, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(lbl, style: const TextStyle(
            fontSize: 12, color: AppColors.textMuted, fontFamily: 'Cairo')),
        Text(val, style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: AppColors.textSecondary, fontFamily: 'Cairo')),
      ],
    );
  }

  Future<void> _confirmDanger(
      String title, String msg, VoidCallback onConfirm) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: const TextStyle(
                color: AppColors.red, fontFamily: 'Cairo',
                fontWeight: FontWeight.w700)),
        content: Text(msg,
            style: const TextStyle(
                color: AppColors.textSecondary, fontFamily: 'Cairo')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء',
                style: TextStyle(color: AppColors.textMuted,
                    fontFamily: 'Cairo')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأكيد',
                style: TextStyle(color: AppColors.red, fontFamily: 'Cairo',
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true) onConfirm();
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: color,
    ));
  }

  static const _gap   = SizedBox(height: 12);
  static const _gap16 = SizedBox(height: 16);
  static const _divider = Padding(
    padding: EdgeInsets.symmetric(vertical: 8),
    child: Divider(height: 1, color: AppColors.border),
  );
}
