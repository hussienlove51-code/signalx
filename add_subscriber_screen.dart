import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../models/subscriber.dart';
import '../models/package.dart';
import '../models/tower.dart';
import '../services/supabase_service.dart';
import '../services/sas4_service.dart';

class AddSubscriberScreen extends StatefulWidget {
  const AddSubscriberScreen({super.key});
  @override
  State<AddSubscriberScreen> createState() => _AddSubscriberScreenState();
}

class _AddSubscriberScreenState extends State<AddSubscriberScreen> {
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _areaCtrl  = TextEditingController();
  final _sas4Ctrl  = TextEditingController(); // اسم مستخدم SAS4

  List<Package> _packages = [];
  List<Tower>   _towers   = [];
  Package? _selectedPackage;
  Tower?   _selectedTower;
  String   _payMethod = 'cash'; // cash | app | zain_cash
  bool     _isSaving  = false;
  bool     _addToSas4 = true;  // هل تضيفه على SAS4 أيضاً؟

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    final packages = await SupabaseService.getPackages();
    final towers   = await SupabaseService.getTowers();
    setState(() {
      _packages = packages;
      _towers   = towers;
      if (packages.isNotEmpty) _selectedPackage = packages[0];
      if (towers.isNotEmpty)   _selectedTower   = towers[0];
    });
  }

  Future<void> _save() async {
    if (_nameCtrl.text.isEmpty || _selectedPackage == null || _selectedTower == null) {
      _showSnack('أكمل البيانات المطلوبة', isError: true);
      return;
    }
    setState(() => _isSaving = true);

    try {
      // 1. أضف في Supabase
      final newSub = Subscriber(
        id:         const Uuid().v4(),
        name:       _nameCtrl.text.trim(),
        phone:      _phoneCtrl.text.trim(),
        area:       _areaCtrl.text.trim(),
        towerId:    _selectedTower!.id,
        packageId:  _selectedPackage!.id,
        expiresAt:  DateTime.now().add(Duration(days: _selectedPackage!.durationDays)),
        status:     'active',
      );
      await SupabaseService.addSubscriber(newSub);

      // 2. إذا المستخدم أراد يضيفه على SAS4 أيضاً
      if (_addToSas4 && SAS4Service.isConfigured && _sas4Ctrl.text.isNotEmpty) {
        await SAS4Service.createUser(
          username:  _sas4Ctrl.text.trim(),
          password:  _phoneCtrl.text.isNotEmpty ? _phoneCtrl.text.trim() : '123456',
          profileId: _selectedPackage!.id,
          fullName:  _nameCtrl.text.trim(),
          phone:     _phoneCtrl.text.trim(),
          address:   _areaCtrl.text.trim(),
        );
      }

      if (mounted) {
        _showSnack('✓ تم إضافة المشترك بنجاح');
        await Future.delayed(const Duration(milliseconds: 800));
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showSnack('حدث خطأ: $e', isError: true);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: isError ? AppColors.red : AppColors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة مشترك جديد')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('البيانات الشخصية'),
            const SizedBox(height: 10),
            _field(_nameCtrl,  'الاسم الكامل *', Icons.person_outline_rounded),
            const SizedBox(height: 10),
            _field(_phoneCtrl, 'رقم الهاتف', Icons.phone_outlined),
            const SizedBox(height: 10),
            _field(_areaCtrl,  'المنطقة / العنوان', Icons.location_on_outlined),
            const SizedBox(height: 20),

            _sectionLabel('الباقة'),
            const SizedBox(height: 10),
            _packagesGrid(),
            const SizedBox(height: 20),

            _sectionLabel('البرج'),
            const SizedBox(height: 10),
            _towersList(),
            const SizedBox(height: 20),

            _sectionLabel('طريقة الدفع'),
            const SizedBox(height: 10),
            _paymentRow(),
            const SizedBox(height: 20),

            // ─── قسم SAS4 ───────────────────────
            _sas4Section(),
            const SizedBox(height: 20),

            // ─── ملخص ────────────────────────────
            if (_selectedPackage != null && _selectedTower != null)
              _summaryCard(),
            const SizedBox(height: 16),

            // ─── زر الحفظ ─────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.check_rounded),
                label: Text(_isSaving ? 'جاري الحفظ...' : 'تفعيل الاشتراك',
                    style: const TextStyle(
                        fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text('سيتم تفعيل الاشتراك فوراً بعد الحفظ',
                  style: TextStyle(fontSize: 11,
                      color: AppColors.textDim, fontFamily: 'Cairo')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String t) => Text(t,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
          color: AppColors.textMuted, letterSpacing: 0.5, fontFamily: 'Cairo'));

  Widget _field(TextEditingController ctrl, String label, IconData icon) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo', fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.textMuted, size: 18),
      ),
    );
  }

  Widget _packagesGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.6,
      children: _packages.map((pkg) {
        final selected = _selectedPackage?.id == pkg.id;
        return GestureDetector(
          onTap: () => setState(() => _selectedPackage = pkg),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected ? AppColors.neonGlow : AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppColors.neon : AppColors.border,
                width: selected ? 1.5 : 0.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${pkg.speedMbps} Mbps',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700,
                        color: selected ? AppColors.neon : AppColors.textPrimary,
                        fontFamily: 'Cairo')),
                Text(pkg.displayPrice,
                    style: TextStyle(
                        fontSize: 12,
                        color: selected ? AppColors.neon : AppColors.textMuted,
                        fontFamily: 'Cairo')),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _towersList() {
    return Column(
      children: _towers.map((tower) {
        final selected = _selectedTower?.id == tower.id;
        final color = tower.isOnline ? AppColors.neon
            : tower.isWarning ? AppColors.orange : AppColors.red;
        return GestureDetector(
          onTap: tower.isOffline ? null : () => setState(() => _selectedTower = tower),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? AppColors.neonGlow : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.neon : AppColors.border,
                width: selected ? 1.5 : 0.5,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.cell_tower_rounded, color: color, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tower.name,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary, fontFamily: 'Cairo')),
                      Text('${tower.subscriberCount} مشترك — إشارة ${tower.signalStrength}%',
                          style: const TextStyle(fontSize: 11,
                              color: AppColors.textMuted, fontFamily: 'Cairo')),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle_rounded, color: AppColors.neon, size: 18),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _paymentRow() {
    final methods = [
      ('cash', 'نقداً', Icons.payments_rounded),
      ('app', 'عبر التطبيق', Icons.phone_android_rounded),
      ('zain_cash', 'زين كاش', Icons.account_balance_wallet_rounded),
    ];
    return Row(
      children: methods.map((m) {
        final selected = _payMethod == m.$1;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _payMethod = m.$1),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: selected ? AppColors.neonGlow : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: selected ? AppColors.neon : AppColors.border,
                    width: selected ? 1.5 : 0.5),
              ),
              child: Column(
                children: [
                  Icon(m.$3,
                      color: selected ? AppColors.neon : AppColors.textMuted, size: 20),
                  const SizedBox(height: 4),
                  Text(m.$2,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 10, fontFamily: 'Cairo', fontWeight: FontWeight.w600,
                          color: selected ? AppColors.neon : AppColors.textMuted)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _sas4Section() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hub_rounded, color: AppColors.neon, size: 18),
              const SizedBox(width: 8),
              const Text('إضافة على SAS4 أيضاً',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary, fontFamily: 'Cairo')),
              const Spacer(),
              Switch(
                value: _addToSas4,
                onChanged: (v) => setState(() => _addToSas4 = v),
                activeColor: AppColors.neon,
              ),
            ],
          ),
          if (_addToSas4) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _sas4Ctrl,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontFamily: 'Cairo', fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'اسم المستخدم في SAS4',
                hintText: 'user123 (PPPoE username)',
                prefixIcon: Icon(Icons.person_pin_rounded,
                    color: AppColors.textMuted, size: 18),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              !SAS4Service.isConfigured
                  ? '⚠ SAS4 غير مضبوط — اذهب للإعدادات أولاً'
                  : '✓ سيُضاف على SAS4 تلقائياً بعد الحفظ',
              style: TextStyle(
                  fontSize: 11, fontFamily: 'Cairo',
                  color: !SAS4Service.isConfigured
                      ? AppColors.orange
                      : AppColors.green),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryCard() {
    final expiry = DateTime.now().add(Duration(days: _selectedPackage!.durationDays));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          _sumRow('المشترك', _nameCtrl.text.isNotEmpty ? _nameCtrl.text : '—'),
          _sumRow('الباقة',  _selectedPackage!.displaySpeed),
          _sumRow('البرج',   _selectedTower!.name),
          _sumRow('الانتهاء',
              '${expiry.day}/${expiry.month}/${expiry.year}'),
          const Divider(color: AppColors.border),
          _sumRow('المبلغ',  _selectedPackage!.displayPrice,
              valueColor: AppColors.neon, bold: true),
        ],
      ),
    );
  }

  Widget _sumRow(String label, String value,
      {Color? valueColor, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(
              fontSize: 12, color: AppColors.textMuted, fontFamily: 'Cairo')),
          Text(value, style: TextStyle(
              fontSize: bold ? 14 : 12,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
              fontFamily: 'Cairo')),
        ],
      ),
    );
  }
}
