import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/subscriber.dart';
import '../models/tower.dart';
import '../models/payment.dart';
import '../models/package.dart';

class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;

  // ─── إعداد Supabase ─────────────────────────────
  static const _url = String.fromEnvironment('SUPABASE_URL');
  static const _anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured =>
      _url.startsWith('https://') && _anonKey.isNotEmpty;

  static Future<void> initialize() async {
    if (!isConfigured) return;
    await Supabase.initialize(url: _url, anonKey: _anonKey);
  }


  // ═══════════════════════════════════════════════
  //  المشتركون
  // ═══════════════════════════════════════════════

  // جلب كل المشتركين
  static Future<List<Subscriber>> getSubscribers() async {
    final res = await _client
        .from('subscribers')
        .select()
        .order('name');
    return (res as List).map((e) => Subscriber.fromJson(e)).toList();
  }

  // جلب المشتركين اللي ينتهون خلال 7 أيام
  static Future<List<Subscriber>> getExpiringSoon() async {
    final now = DateTime.now();
    final in7days = now.add(const Duration(days: 7));
    final res = await _client
        .from('subscribers')
        .select()
        .gte('expires_at', now.toIso8601String())
        .lte('expires_at', in7days.toIso8601String())
        .order('expires_at');
    return (res as List).map((e) => Subscriber.fromJson(e)).toList();
  }

  // إضافة مشترك جديد
  static Future<Subscriber> addSubscriber(Subscriber sub) async {
    final res = await _client
        .from('subscribers')
        .insert(sub.toJson())
        .select()
        .single();
    return Subscriber.fromJson(res);
  }

  // تعديل مشترك
  static Future<void> updateSubscriber(Subscriber sub) async {
    await _client
        .from('subscribers')
        .update(sub.toJson())
        .eq('id', sub.id);
  }

  // حذف مشترك
  static Future<void> deleteSubscriber(String id) async {
    await _client.from('subscribers').delete().eq('id', id);
  }

  // تجديد اشتراك
  static Future<void> renewSubscriber(String id, DateTime newExpiry) async {
    await _client
        .from('subscribers')
        .update({
          'expires_at': newExpiry.toIso8601String(),
          'status': 'active',
        })
        .eq('id', id);
  }

  // ═══════════════════════════════════════════════
  //  الأبراج
  // ═══════════════════════════════════════════════

  static Future<List<Tower>> getTowers() async {
    final res = await _client.from('towers').select().order('name');
    return (res as List).map((e) => Tower.fromJson(e)).toList();
  }

  static Future<Tower> getTowerById(String id) async {
    final res = await _client
        .from('towers')
        .select()
        .eq('id', id)
        .single();
    return Tower.fromJson(res);
  }

  static Future<void> updateTowerStatus(String id, String status) async {
    await _client
        .from('towers')
        .update({'status': status})
        .eq('id', id);
  }

  // ═══════════════════════════════════════════════
  //  الدفعات
  // ═══════════════════════════════════════════════

  static Future<List<Payment>> getPayments({int limit = 50}) async {
    final res = await _client
        .from('payments')
        .select('*, subscribers(name)')
        .order('paid_at', ascending: false)
        .limit(limit);
    return (res as List).map((e) {
      e['subscriber_name'] = e['subscribers']?['name'] ?? '';
      return Payment.fromJson(e);
    }).toList();
  }

  static Future<void> addPayment(Payment payment) async {
    await _client.from('payments').insert(payment.toJson());
  }

  // إجمالي الإيرادات هذا الشهر
  static Future<int> getMonthlyRevenue() async {
    final startOfMonth = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      1,
    );
    final res = await _client
        .from('payments')
        .select('amount')
        .gte('paid_at', startOfMonth.toIso8601String());
    int total = 0;
    for (final row in res as List) {
      total += (row['amount'] as int);
    }
    return total;
  }

  // ═══════════════════════════════════════════════
  //  الباقات
  // ═══════════════════════════════════════════════

  static Future<List<Package>> getPackages() async {
    final res = await _client
        .from('packages')
        .select()
        .order('speed_mbps');
    return (res as List).map((e) => Package.fromJson(e)).toList();
  }

  // استعادة/تحديث برج من النسخة الاحتياطية
  static Future<void> upsertTower(Tower tower) async {
    await _client.from('towers').upsert(tower.toJson());
  }

  // استعادة/تحديث باقة من النسخة الاحتياطية
  static Future<void> upsertPackage(Package package) async {
    await _client.from('packages').upsert(package.toJson());
  }

  // ═══════════════════════════════════════════════
  //  الإحصائيات للداشبورد
  // ═══════════════════════════════════════════════

  static Future<Map<String, dynamic>> getDashboardStats() async {
    final subscribers = await getSubscribers();
    final towers      = await getTowers();
    final revenue     = await getMonthlyRevenue();
    final expiring    = await getExpiringSoon();

    return {
      'total_subscribers': subscribers.length,
      'active_subscribers': subscribers.where((s) => s.status == 'active').length,
      'monthly_revenue': revenue,
      'expiring_soon': expiring.length,
      'online_towers': towers.where((t) => t.isOnline).length,
      'warning_towers': towers.where((t) => t.isWarning).length,
      'offline_towers': towers.where((t) => t.isOffline).length,
    };
  }
}
