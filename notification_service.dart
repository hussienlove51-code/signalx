import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subscriber.dart';
import 'supabase_service.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // ══════════════════════════════════════
  //  تهيئة الإشعارات
  // ══════════════════════════════════════
  static Future<void> initialize() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios     = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _initialized = true;
  }

  // ══════════════════════════════════════
  //  فحص الاشتراكات وإرسال تنبيهات
  // ══════════════════════════════════════
  static Future<void> checkExpirations() async {
    final expiring = await SupabaseService.getExpiringSoon();
    final prefs    = await SharedPreferences.getInstance();

    for (final sub in expiring) {
      final key      = 'notif_${sub.id}';
      final lastSent = prefs.getString(key);
      final daysLeft = sub.expiresAt.difference(DateTime.now()).inDays;

      // أرسل مرة واحدة فقط لكل مشترك
      if (lastSent != _today()) {
        await _sendNotification(sub, daysLeft);
        await prefs.setString(key, _today());
      }
    }

    // إشعار ملخص
    if (expiring.isNotEmpty) {
      await _sendSummaryNotification(expiring);
    }
  }

  // إشعار لمشترك واحد
  static Future<void> _sendNotification(Subscriber sub, int days) async {
    final title = days <= 0
        ? '⚠️ انتهى اشتراك ${sub.name}'
        : '🔔 ${sub.name} — ينتهي خلال $days أيام';

    final body = days <= 0
        ? 'يرجى التجديد فوراً لتجنب انقطاع الخدمة'
        : 'اشتراك ${sub.phone} — لا تنسى التجديد';

    await _plugin.show(
      sub.id.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'expiry_channel',
          'انتهاء الاشتراكات',
          channelDescription: 'تنبيهات انتهاء اشتراكات المشتركين',
          importance: Importance.high,
          priority:   Priority.high,
          color:      Color(0xFF00D4FF),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  // إشعار ملخص
  static Future<void> _sendSummaryNotification(List<Subscriber> expiring) async {
    if (expiring.length <= 1) return;

    await _plugin.show(
      99999,
      '📋 ${expiring.length} اشتراكات تنتهي قريباً',
      expiring.map((s) => s.name).take(3).join('، ') +
          (expiring.length > 3 ? ' وآخرون...' : ''),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'summary_channel',
          'ملخص يومي',
          channelDescription: 'ملخص يومي للاشتراكات المنتهية',
          importance: Importance.defaultImportance,
          priority:   Priority.defaultPriority,
        ),
      ),
    );
  }

  // إشعار فوري عند إضافة مشترك
  static Future<void> notifyNewSubscriber(String name) async {
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '✅ مشترك جديد',
      'تم تفعيل اشتراك $name بنجاح',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'new_sub_channel',
          'مشتركون جدد',
          importance: Importance.high,
          color:      Color(0xFF00E676),
        ),
      ),
    );
  }

  // إشعار نتيجة المزامنة
  static Future<void> notifySyncResult(int added, int updated) async {
    if (added == 0 && updated == 0) return;
    await _plugin.show(
      88888,
      '🔄 تمت المزامنة مع SAS4',
      'مضاف: $added | محدّث: $updated',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'sync_channel',
          'مزامنة SAS4',
          importance: Importance.low,
        ),
      ),
    );
  }

  static String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }
}

