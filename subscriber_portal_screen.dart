import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/subscriber.dart';
import '../services/supabase_service.dart';
import '../services/whatsapp_service.dart';

// ─────────────────────────────────────────
//  شاشة دخول المشترك
//  المشترك يدخل برقم هاتفه ويشوف بياناته
// ─────────────────────────────────────────
class SubscriberPortalScreen extends StatefulWidget {
  const SubscriberPortalScreen({super.key});
  @override
  State<SubscriberPortalScreen> createState() =>
      _SubscriberPortalScreenState();
}

class _SubscriberPortalScreenState extends State<SubscriberPortalScreen> {
  final _phoneCtrl = TextEditingController();
  bool        _loading  = false;
  String?     _error;
  Subscriber? _sub;

  Future<void> _lookup() async {
    if (_phoneCtrl.text.trim().isEmpty) return;
    setState(() { _loading = true; _error = null; });

    try {
      final subs = await SupabaseService.getSubscribers();
      final found = subs.where((s) =>
          s.phone.replaceAll(RegExp(r'\D'), '') ==
          _phoneCtrl.text.replaceAll(RegExp(r'\D'), '')).toList();

      if (found.isEmpty) {
        setState(() {
          _error   = 'لم يتم العثور على اشتراك لهذا الرقم';
          _loading = false;
        });
      } else {
        setState(() { _sub = found.first; _loading = false; });
      }
    } catch (_) {
      setState(() {
        _error   = 'حدث خطأ، حاول مرة أخرى';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _sub == null ? _buildLookup() : _buildPortal(),
      ),
    );
  }

  // ─── شاشة البحث برقم الهاتف ───────────
  Widget _buildLookup() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          // أيقونة
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppColors.neon, AppColors.neonDark]),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [BoxShadow(
                  color: AppColors.neon.withOpacity(0.3),
                  blurRadius: 20)],
            ),
            child: const Icon(Icons.wifi_rounded,
                size: 40, color: Colors.white),
          ),
          const SizedBox(height: 20),
          const Text('بوابة المشترك',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary, fontFamily: 'Cairo')),
          const SizedBox(height: 8),
          const Text('أدخل رقم هاتفك لعرض تفاصيل اشتراكك',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted,
                  fontFamily: 'Cairo'),
              textAlign: TextAlign.center),
          const SizedBox(height: 40),

          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            onSubmitted: (_) => _lookup(),
            style: const TextStyle(
                color: AppColors.textPrimary, fontFamily: 'Cairo',
                fontSize: 16, letterSpacing: 1),
            decoration: const InputDecoration(
              hintText: '07XXXXXXXXX',
              prefixIcon: Icon(Icons.phone_rounded,
                  color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 12),

          if (_error != null)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.redGlow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.error_rounded,
                    color: AppColors.red, size: 16),
                const SizedBox(width: 8),
                Text(_error!,
                    style: const TextStyle(color: AppColors.red,
                        fontSize: 12, fontFamily: 'Cairo')),
              ]),
            ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _lookup,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _loading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('عرض اشتراكي',
                      style: TextStyle(fontFamily: 'Cairo',
                          fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── بوابة المشترك ────────────────────
  Widget _buildPortal() {
    final sub      = _sub!;
    final daysLeft = sub.expiresAt.difference(DateTime.now()).inDays;
    final isExpired = daysLeft < 0;
    final isExpiringSoon = daysLeft >= 0 && daysLeft <= 7;

    final statusColor = isExpired
        ? AppColors.red
        : isExpiringSoon
            ? AppColors.orange
            : AppColors.green;
    final statusText = isExpired
        ? 'انتهى الاشتراك'
        : isExpiringSoon
            ? 'ينتهي قريباً'
            : 'نشط';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 8),

          // ─── رأس البوابة ───
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.neonGlow,
                child: Text(
                  sub.name.characters.first,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700,
                      color: AppColors.neon, fontFamily: 'Cairo'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sub.name,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            fontFamily: 'Cairo')),
                    Text(sub.phone,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted,
                            fontFamily: 'Cairo')),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _sub = null),
                child: const Text('خروج',
                    style: TextStyle(color: AppColors.textMuted,
                        fontFamily: 'Cairo', fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ─── بطاقة الحالة الرئيسية ───
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  statusColor.withOpacity(0.15),
                  AppColors.surface,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: statusColor.withOpacity(0.4), width: 1),
            ),
            child: Column(
              children: [
                Icon(
                  isExpired
                      ? Icons.error_rounded
                      : isExpiringSoon
                          ? Icons.timer_rounded
                          : Icons.check_circle_rounded,
                  color: statusColor, size: 40,
                ),
                const SizedBox(height: 8),
                Text(statusText,
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700,
                        color: statusColor, fontFamily: 'Cairo')),
                const SizedBox(height: 4),
                Text(
                  isExpired
                      ? 'انتهى اشتراكك منذ ${-daysLeft} يوم'
                      : isExpiringSoon
                          ? 'ينتهي اشتراكك خلال $daysLeft أيام'
                          : 'اشتراكك فعّال — $daysLeft يوم متبقي',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary,
                      fontFamily: 'Cairo'),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ─── شريط الوقت المتبقي ───
          if (!isExpired) ...[
            Container(
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('الوقت المتبقي',
                          style: TextStyle(fontSize: 12,
                              color: AppColors.textMuted,
                              fontFamily: 'Cairo')),
                      Text('$daysLeft / 30 يوم',
                          style: TextStyle(fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: statusColor, fontFamily: 'Cairo')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (daysLeft / 30).clamp(0.0, 1.0),
                      backgroundColor: AppColors.surfaceLight,
                      valueColor: AlwaysStoppedAnimation(statusColor),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ─── تفاصيل الاشتراك ───
          _detailCard([
            _DetailRow('الباقة',       sub.packageId,
                Icons.speed_rounded),
            _DetailRow('المنطقة',      sub.area,
                Icons.location_on_rounded),
            _DetailRow('تاريخ الانتهاء',
                _formatDate(sub.expiresAt),
                Icons.calendar_today_rounded),
            _DetailRow('حالة الاشتراك', statusText,
                Icons.circle, color: statusColor),
          ]),
          const SizedBox(height: 12),

          // ─── أزرار الإجراءات ───
          if (isExpired || isExpiringSoon)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _requestRenewal(sub),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('طلب تجديد الاشتراك',
                    style: TextStyle(fontFamily: 'Cairo',
                        fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: isExpired
                      ? AppColors.red : AppColors.orange,
                ),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _contactSupport(sub),
              icon: const Icon(Icons.support_agent_rounded,
                  size: 18, color: AppColors.neon),
              label: const Text('تواصل مع الدعم',
                  style: TextStyle(color: AppColors.neon,
                      fontFamily: 'Cairo')),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: AppColors.neon),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailCard(List<_DetailRow> rows) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: rows.asMap().entries.map((e) {
          final row  = e.value;
          final last = e.key == rows.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: last ? null : const Border(
                  bottom: BorderSide(
                      color: AppColors.border, width: 0.5)),
            ),
            child: Row(
              children: [
                Icon(row.icon,
                    size: 16,
                    color: row.color ?? AppColors.textMuted),
                const SizedBox(width: 10),
                Text(row.label,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted,
                        fontFamily: 'Cairo')),
                const Spacer(),
                Text(row.value,
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: row.color ?? AppColors.textPrimary,
                        fontFamily: 'Cairo')),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _requestRenewal(Subscriber sub) async {
    await WhatsAppService.sendCustomMessage(
      '9647800000000', // رقم المدير — يُغيَّر من الإعدادات
      'مرحباً، أريد تجديد اشتراكي\n'
      'الاسم: ${sub.name}\n'
      'الهاتف: ${sub.phone}\n'
      'الباقة: ${sub.packageId}',
    );
  }

  Future<void> _contactSupport(Subscriber sub) async {
    await WhatsAppService.sendCustomMessage(
      '9647800000000',
      'السلام عليكم، أحتاج مساعدة\n'
      'الاسم: ${sub.name}\nالهاتف: ${sub.phone}',
    );
  }

  String _formatDate(DateTime d) {
    const months = ['', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو',
        'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    return '${d.day} ${months[d.month]} ${d.year}';
  }
}

class _DetailRow {
  final String    label, value;
  final IconData  icon;
  final Color?    color;
  const _DetailRow(this.label, this.value, this.icon, {this.color});
}
