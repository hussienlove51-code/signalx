import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subscriber.dart';
import '../models/payment.dart';
import '../models/tower.dart';
import '../models/package.dart';
import 'supabase_service.dart';

// ─────────────────────────────────────────
//  BackupService — نسخ احتياطية تلقائية
//  يحفظ يومياً ويحتفظ بآخر 7 نسخ
// ─────────────────────────────────────────
class BackupService {
  static const _lastBackupKey = 'last_backup_date';
  static const _maxBackups    = 7; // احتفظ بآخر 7 نسخ

  // ══════════════════════════════════════
  //  فحص إذا نحتاج backup اليوم
  // ══════════════════════════════════════
  static Future<bool> needsBackup() async {
    final prefs    = await SharedPreferences.getInstance();
    final lastDate = prefs.getString(_lastBackupKey);
    if (lastDate == null) return true;

    final last  = DateTime.parse(lastDate);
    final today = DateTime.now();
    return today.difference(last).inDays >= 1;
  }

  // ══════════════════════════════════════
  //  إنشاء نسخة احتياطية كاملة
  // ══════════════════════════════════════
  static Future<BackupResult> createBackup({bool manual = false}) async {
    try {
      // جلب كل البيانات
      final subscribers = await SupabaseService.getSubscribers();
      final payments    = await SupabaseService.getPayments(limit: 100000);
      final towers      = await SupabaseService.getTowers();
      final packages    = await SupabaseService.getPackages();

      // بناء ملف الـ Backup
      final backup = {
        'version':    '1.0',
        'app':        'SignalX',
        'created_at': DateTime.now().toIso8601String(),
        'data': {
          'subscribers': subscribers.map((s) => s.toJson()).toList(),
          'payments':    payments.map((p) => p.toJson()).toList(),
          'towers':      towers.map((t) => t.toJson()).toList(),
          'packages':    packages.map((p) => p.toJson()).toList(),
        },
        'stats': {
          'subscribers_count': subscribers.length,
          'payments_count':    payments.length,
          'towers_count':      towers.length,
          'packages_count':    packages.length,
        },
      };

      // حفظ الملف
      final file = await _saveBackupFile(backup);

      // تحديث تاريخ آخر backup
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _lastBackupKey, DateTime.now().toIso8601String());

      // حذف النسخ القديمة (احتفظ بآخر 7 فقط)
      await _cleanOldBackups();

      return BackupResult(
        success:   true,
        message:   'تم إنشاء النسخة الاحتياطية بنجاح',
        file:      file,
        size:      await file.length(),
        itemCount: subscribers.length + payments.length,
      );
    } catch (e) {
      return BackupResult(
        success: false,
        message: 'فشل إنشاء النسخة: $e',
      );
    }
  }

  // ══════════════════════════════════════
  //  استعادة من نسخة احتياطية
  // ══════════════════════════════════════
  static Future<RestoreResult> restoreFromFile(File file) async {
    try {
      final content = await file.readAsString();
      final data    = jsonDecode(content) as Map<String, dynamic>;

      // تحقق من صحة الملف
      if (data['app'] != 'SignalX') {
        return RestoreResult(
            success: false, message: 'الملف غير صالح لـ SignalX');
      }

      final backupData = data['data'] as Map<String, dynamic>;
      int restored = 0;

      // استعادة الأبراج والباقات أولاً لأن المشتركين والدفعات قد يعتمدون عليها.
      final towersData = (backupData['towers'] as List? ?? const []);
      for (final raw in towersData) {
        await SupabaseService.upsertTower(Tower.fromJson(raw));
        restored++;
      }

      final packagesData = (backupData['packages'] as List? ?? const []);
      for (final raw in packagesData) {
        await SupabaseService.upsertPackage(Package.fromJson(raw));
        restored++;
      }

      // استعادة المشتركين
      final subs = (backupData['subscribers'] as List? ?? const [])
          .map((s) => Subscriber.fromJson(s)).toList();
      for (final s in subs) {
        await SupabaseService.addSubscriber(s);
        restored++;
      }

      // استعادة الدفعات
      final pays = (backupData['payments'] as List? ?? const [])
          .map((p) => Payment.fromJson(p)).toList();
      for (final p in pays) {
        await SupabaseService.addPayment(p);
        restored++;
      }

      return RestoreResult(
        success:       true,
        message:       'تم استعادة $restored عنصر بنجاح',
        restoredCount: restored,
      );
    } catch (e) {
      return RestoreResult(
          success: false, message: 'خطأ في الاستعادة: $e');
    }
  }

  // ══════════════════════════════════════
  //  جلب قائمة النسخ الاحتياطية
  // ══════════════════════════════════════
  static Future<List<BackupFile>> getBackupsList() async {
    final dir   = await _backupDir();
    final files = dir.listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.signalx'))
        .toList();

    files.sort((a, b) => b.lastModifiedSync()
        .compareTo(a.lastModifiedSync()));

    return Future.wait(files.map((f) async {
      final size    = await f.length();
      final name    = f.path.split('/').last;
      final date    = f.lastModifiedSync();
      return BackupFile(file: f, name: name, size: size, date: date);
    }));
  }

  // ══════════════════════════════════════
  //  مشاركة نسخة احتياطية
  // ══════════════════════════════════════
  static Future<void> shareBackup(File file) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'SignalX Backup',
      text:    'نسخة احتياطية من تطبيق SignalX',
    );
  }

  // ══════════════════════════════════════
  //  Backup تلقائي (يُستدعى عند فتح التطبيق)
  // ══════════════════════════════════════
  static Future<void> autoBackupIfNeeded() async {
    if (await needsBackup()) {
      await createBackup();
    }
  }

  // ── Helpers ──────────────────────────
  static Future<Directory> _backupDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir  = Directory('${docs.path}/backups');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<File> _saveBackupFile(Map<String, dynamic> data) async {
    final dir      = await _backupDir();
    final dateStr  = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
    final file     = File('${dir.path}/signalx_$dateStr.signalx');
    await file.writeAsString(jsonEncode(data));
    return file;
  }

  static Future<void> _cleanOldBackups() async {
    final backups = await getBackupsList();
    if (backups.length > _maxBackups) {
      final toDelete = backups.sublist(_maxBackups);
      for (final b in toDelete) {
        await b.file.delete();
      }
    }
  }

  static Future<String> getLastBackupText() async {
    final prefs    = await SharedPreferences.getInstance();
    final lastDate = prefs.getString(_lastBackupKey);
    if (lastDate == null) return 'لم يتم أي backup بعد';

    final last = DateTime.parse(lastDate);
    final diff = DateTime.now().difference(last);

    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24)   return 'منذ ${diff.inHours} ساعة';
    return 'منذ ${diff.inDays} يوم — ${DateFormat('dd/MM/yyyy').format(last)}';
  }
}

// ─── نتائج وبيانات ──────────────────────
class BackupResult {
  final bool   success;
  final String message;
  final File?  file;
  final int    size;
  final int    itemCount;

  const BackupResult({
    required this.success,
    required this.message,
    this.file,
    this.size      = 0,
    this.itemCount = 0,
  });

  String get sizeText {
    if (size < 1024)       return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class RestoreResult {
  final bool   success;
  final String message;
  final int    restoredCount;
  const RestoreResult({
    required this.success,
    required this.message,
    this.restoredCount = 0,
  });
}

class BackupFile {
  final File     file;
  final String   name;
  final int      size;
  final DateTime date;
  const BackupFile({
    required this.file,
    required this.name,
    required this.size,
    required this.date,
  });

  String get sizeText {
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(0)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get dateText =>
      DateFormat('dd/MM/yyyy — HH:mm').format(date);
}
