import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../models/subscriber.dart';
import '../models/payment.dart';

class WhatsAppService {

  // تذكير انتهاء اشتراك
  static Future<bool> sendExpiryReminder(Subscriber sub) async {
    final days    = sub.expiresAt.difference(DateTime.now()).inDays;
    final dateStr = DateFormat('dd/MM/yyyy').format(sub.expiresAt);
    final name    = sub.name.split(' ').first;

    final msg = days <= 0 ? '''
🔴 *انتهى اشتراكك في SignalX*

السلام عليكم $name،
نأسف لإبلاغك بأن اشتراكك قد انتهى بتاريخ *$dateStr*.
للتجديد يرجى التواصل معنا أو الدفع عبر التطبيق.
شكراً 🙏 *فريق SignalX*
''' : '''
🔔 *تذكير — اشتراكك ينتهي قريباً*

السلام عليكم $name،
اشتراكك ينتهي خلال *$days أيام* بتاريخ *$dateStr*.
يرجى التجديد مسبقاً لضمان استمرارية الخدمة 💳
شكراً 🙏 *فريق SignalX*
''';
    return _send(sub.phone, msg);
  }

  // تأكيد دفعة
  static Future<bool> sendPaymentConfirmation(
      Subscriber sub, Payment payment) async {
    final fmt    = NumberFormat('#,###');
    final newExp = DateFormat('dd/MM/yyyy').format(sub.expiresAt);
    final msg = '''
✅ *تم استلام دفعتك بنجاح*

السلام عليكم ${sub.name.split(' ').first}،
• المبلغ: *${fmt.format(payment.amount)} د.ع*
• الطريقة: ${payment.methodArabic}
• انتهاء الاشتراك الجديد: *$newExp*

شكراً لثقتك بنا 🙏 *فريق SignalX*
''';
    return _send(sub.phone, msg);
  }

  // ترحيب بمشترك جديد
  static Future<bool> sendWelcomeMessage(
      Subscriber sub, String username, String password, String speed) async {
    final dateStr = DateFormat('dd/MM/yyyy').format(sub.expiresAt);
    final msg = '''
🎉 *مرحباً بك في SignalX!*

السلام عليكم ${sub.name.split(' ').first}،
تم تفعيل اشتراكك بنجاح!

📡 *بيانات الاتصال:*
• اسم المستخدم: *$username*
• كلمة المرور: *$password*
• السرعة: *$speed*
• الانتهاء: *$dateStr*

نتمنى لك تجربة ممتازة! 🚀
*فريق SignalX*
''';
    return _send(sub.phone, msg);
  }

  // إشعار انقطاع خدمة
  static Future<bool> sendServiceAlert(
      Subscriber sub, String reason) async {
    final msg = '''
⚠️ *إشعار انقطاع مؤقت*

السلام عليكم ${sub.name.split(' ').first}،
يوجد انقطاع مؤقت بسبب: *$reason*
نعمل على الإصلاح في أقرب وقت. نعتذر عن الإزعاج 🙏
*فريق SignalX*
''';
    return _send(sub.phone, msg);
  }

  // رسالة جماعية
  static Future<int> sendBulkMessage(
      List<Subscriber> subscribers, String message) async {
    int sent = 0;
    for (final sub in subscribers) {
      if (await _send(sub.phone, message)) sent++;
      await Future.delayed(const Duration(milliseconds: 500));
    }
    return sent;
  }

  // تقرير يومي للمدير
  static Future<bool> sendDailyReport({
    required String managerPhone,
    required int total, required int online,
    required int expiring, required int revenue,
  }) async {
    final fmt   = NumberFormat('#,###');
    final today = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final msg = '''
📊 *التقرير اليومي — SignalX*
📅 $today

👥 الإجمالي: *$total* | متصل: *$online* | ينتهي: *$expiring*
💰 إيرادات اليوم: *${fmt.format(revenue)} د.ع*

*SignalX Dashboard*
''';
    return _send(managerPhone, msg);
  }

  // Helper: فتح واتساب
  static Future<bool> _send(String phone, String message) async {
    var num = phone
        .replaceAll(RegExp(r'[\s\-\+]'), '');
    if (num.startsWith('07'))      num = '964${num.substring(1)}';
    else if (!num.startsWith('964')) num = '964$num';

    final url = Uri.parse(
        'https://wa.me/$num?text=${Uri.encodeComponent(message)}');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (_) {}
    return false;
  }
}
