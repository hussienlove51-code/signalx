import 'sas4_service.dart';
import 'supabase_service.dart';
import '../models/subscriber.dart';

/// ─────────────────────────────────────────
///  SyncService — يزامن البيانات بين SAS4 وSupabase
///  الفكرة: SAS4 هو المصدر الأصلي، Supabase للتخزين المحلي
/// ─────────────────────────────────────────
class SyncService {
  static DateTime? _lastSync;
  static bool _isSyncing = false;

  // نتيجة المزامنة
  static SyncResult? lastResult;

  // ══════════════════════════════════════
  //  المزامنة الرئيسية
  // ══════════════════════════════════════
  static Future<SyncResult> syncAll({bool force = false}) async {
    // منع المزامنة المتزامنة
    if (_isSyncing) {
      return SyncResult(
        success: false,
        message: 'المزامنة جارية بالفعل...',
        added: 0, updated: 0, unchanged: 0,
      );
    }

    // مزامنة تلقائية كل 5 دقائق
    if (!force && _lastSync != null) {
      final diff = DateTime.now().difference(_lastSync!).inMinutes;
      if (diff < 5) {
        return SyncResult(
          success: true,
          message: 'آخر مزامنة منذ $diff دقائق',
          added: 0, updated: 0, unchanged: 0,
        );
      }
    }

    _isSyncing = true;

    try {
      // 1. اجلب من SAS4
      final sas4Users = await SAS4Service.getUsers();
      if (sas4Users.isEmpty) {
        _isSyncing = false;
        return SyncResult(
          success: false,
          message: 'تعذر الاتصال بـ SAS4 أو لا يوجد مشتركين',
          added: 0, updated: 0, unchanged: 0,
        );
      }

      // 2. حوّل إلى موديل التطبيق
      final sas4Subscribers = SAS4Service.convertToSubscribers(sas4Users);

      // 3. اجلب من Supabase (الموجود حالياً)
      final localSubscribers = await SupabaseService.getSubscribers();
      final localMap = {for (var s in localSubscribers) s.id: s};

      int added = 0, updated = 0, unchanged = 0;

      // 4. قارن وحدّث
      for (final sas4Sub in sas4Subscribers) {
        final existing = localMap[sas4Sub.id];

        if (existing == null) {
          // مشترك جديد — أضفه
          await SupabaseService.addSubscriber(sas4Sub);
          added++;
        } else if (_hasChanges(existing, sas4Sub)) {
          // تغيّرت بياناته — حدّثه
          await SupabaseService.updateSubscriber(sas4Sub);
          updated++;
        } else {
          unchanged++;
        }
      }

      _lastSync = DateTime.now();
      _isSyncing = false;

      final result = SyncResult(
        success: true,
        message: 'تمت المزامنة بنجاح ✓',
        added: added,
        updated: updated,
        unchanged: unchanged,
        syncTime: _lastSync,
        totalFromSAS4: sas4Users.length,
      );

      lastResult = result;
      return result;

    } catch (e) {
      _isSyncing = false;
      return SyncResult(
        success: false,
        message: 'خطأ في المزامنة: $e',
        added: 0, updated: 0, unchanged: 0,
      );
    }
  }

  // ══════════════════════════════════════
  //  مزامنة المشتركين المتصلين فقط (أسرع)
  // ══════════════════════════════════════
  static Future<List<Subscriber>> syncOnlineOnly() async {
    final onlineUsers = await SAS4Service.getOnlineUsers();
    return SAS4Service.convertToSubscribers(onlineUsers);
  }

  // ══════════════════════════════════════
  //  تحقق إذا في تغييرات بين النسختين
  // ══════════════════════════════════════
  static bool _hasChanges(Subscriber local, Subscriber remote) {
    return local.status != remote.status ||
        local.expiresAt.day != remote.expiresAt.day ||
        local.expiresAt.month != remote.expiresAt.month ||
        local.expiresAt.year != remote.expiresAt.year ||
        local.packageId != remote.packageId;
  }

  // آخر وقت مزامنة بصيغة نص
  static String get lastSyncText {
    if (_lastSync == null) return 'لم تتم مزامنة بعد';
    final diff = DateTime.now().difference(_lastSync!);
    if (diff.inSeconds < 60)  return 'منذ ${diff.inSeconds} ثانية';
    if (diff.inMinutes < 60)  return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24)    return 'منذ ${diff.inHours} ساعة';
    return 'منذ ${diff.inDays} يوم';
  }

  static bool get isSyncing => _isSyncing;
}

// ─── نتيجة المزامنة ─────────────────────
class SyncResult {
  final bool success;
  final String message;
  final int added;
  final int updated;
  final int unchanged;
  final DateTime? syncTime;
  final int totalFromSAS4;

  SyncResult({
    required this.success,
    required this.message,
    required this.added,
    required this.updated,
    required this.unchanged,
    this.syncTime,
    this.totalFromSAS4 = 0,
  });

  String get summary =>
      'جديد: $added | محدّث: $updated | بدون تغيير: $unchanged';
}
