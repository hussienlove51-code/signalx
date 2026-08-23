import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/subscriber.dart';
import '../models/payment.dart';
import '../models/tower.dart';
import 'supabase_service.dart';

// ─────────────────────────────────────────
//  OfflineService — SQLite محلي + مزامنة ذكية
//  يشتغل بدون إنترنت، ويزامن لما يرجع النت
// ─────────────────────────────────────────
class OfflineService {
  static Database? _db;
  static bool _isOnline = true;

  // ══════════════════════════════════════
  //  تهيئة قاعدة البيانات المحلية
  // ══════════════════════════════════════
  static Future<void> initialize() async {
    // مراقبة حالة الاتصال
    Connectivity().onConnectivityChanged.listen((result) {
      final wasOffline = !_isOnline;
      _isOnline = !result.contains(ConnectivityResult.none);
      if (result.isEmpty) _isOnline = false;

      // لو رجع النت بعد انقطاع — زامن تلقائياً
      if (wasOffline && _isOnline) {
        syncPendingActions();
      }
    });

    // فحص الاتصال الحالي
    final conn = await Connectivity().checkConnectivity();
    _isOnline = !conn.contains(ConnectivityResult.none);
    if (conn.isEmpty) _isOnline = false;

    // فتح SQLite
    _db = await openDatabase(
      join(await getDatabasesPath(), 'signalx_offline.db'),
      version: 1,
      onCreate: _createTables,
    );
  }

  static Future<void> _createTables(Database db, int version) async {
    // جدول المشتركين المحلي
    await db.execute('''
      CREATE TABLE subscribers (
        id          TEXT PRIMARY KEY,
        name        TEXT NOT NULL,
        phone       TEXT,
        area        TEXT,
        tower_id    TEXT,
        package_id  TEXT,
        expires_at  TEXT NOT NULL,
        status      TEXT DEFAULT 'active',
        synced      INTEGER DEFAULT 1,
        updated_at  TEXT
      )
    ''');

    // جدول الأبراج المحلي
    await db.execute('''
      CREATE TABLE towers (
        id                TEXT PRIMARY KEY,
        name              TEXT NOT NULL,
        location          TEXT,
        signal_strength   INTEGER DEFAULT 100,
        status            TEXT DEFAULT 'online',
        temperature       REAL DEFAULT 40,
        subscriber_count  INTEGER DEFAULT 0,
        current_bandwidth REAL DEFAULT 0,
        synced            INTEGER DEFAULT 1
      )
    ''');

    // جدول الدفعات المحلي
    await db.execute('''
      CREATE TABLE payments (
        id              TEXT PRIMARY KEY,
        subscriber_id   TEXT,
        subscriber_name TEXT,
        amount          INTEGER,
        method          TEXT,
        paid_at         TEXT,
        synced          INTEGER DEFAULT 0
      )
    ''');

    // جدول العمليات المعلقة (لما يرجع النت)
    await db.execute('''
      CREATE TABLE pending_actions (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        action     TEXT NOT NULL,
        table_name TEXT NOT NULL,
        data       TEXT NOT NULL,
        created_at TEXT DEFAULT (datetime('now'))
      )
    ''');
  }

  static bool get isOnline => _isOnline;
  static Database get db {
    if (_db == null) throw Exception('OfflineService not initialized');
    return _db!;
  }

  // ══════════════════════════════════════
  //  المشتركون — قراءة محلية
  // ══════════════════════════════════════
  static Future<List<Subscriber>> getSubscribers() async {
    // لو النت شغال — اجلب من Supabase وحدّث المحلي
    if (_isOnline) {
      try {
        final online = await SupabaseService.getSubscribers();
        await _cacheSubscribers(online);
        return online;
      } catch (_) {
        // فشل الجلب — ارجع للمحلي
      }
    }
    // Offline أو فشل — ارجع من SQLite
    return _getLocalSubscribers();
  }

  static Future<List<Subscriber>> _getLocalSubscribers() async {
    final rows = await db.query('subscribers', orderBy: 'name');
    return rows.map(_rowToSubscriber).toList();
  }

  static Future<void> _cacheSubscribers(List<Subscriber> subs) async {
    final batch = db.batch();
    for (final s in subs) {
      batch.insert('subscribers', _subscriberToRow(s, synced: 1),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  // ══════════════════════════════════════
  //  المشتركون — كتابة (أولاً محلي، ثم Supabase)
  // ══════════════════════════════════════
  static Future<void> addSubscriber(Subscriber sub) async {
    // احفظ محلياً دائماً
    await db.insert('subscribers', _subscriberToRow(sub, synced: _isOnline ? 1 : 0),
        conflictAlgorithm: ConflictAlgorithm.replace);

    if (_isOnline) {
      try {
        await SupabaseService.addSubscriber(sub);
        await db.update('subscribers', {'synced': 1},
            where: 'id = ?', whereArgs: [sub.id]);
      } catch (_) {
        await _queueAction('insert', 'subscribers', sub.toJson());
      }
    } else {
      await _queueAction('insert', 'subscribers', sub.toJson());
    }
  }

  static Future<void> updateSubscriber(Subscriber sub) async {
    await db.update('subscribers', _subscriberToRow(sub, synced: _isOnline ? 1 : 0),
        where: 'id = ?', whereArgs: [sub.id]);

    if (_isOnline) {
      try {
        await SupabaseService.updateSubscriber(sub);
      } catch (_) {
        await _queueAction('update', 'subscribers', sub.toJson());
      }
    } else {
      await _queueAction('update', 'subscribers', sub.toJson());
    }
  }

  static Future<void> deleteSubscriber(String id) async {
    await db.delete('subscribers', where: 'id = ?', whereArgs: [id]);

    if (_isOnline) {
      try {
        await SupabaseService.deleteSubscriber(id);
      } catch (_) {
        await _queueAction('delete', 'subscribers', {'id': id});
      }
    } else {
      await _queueAction('delete', 'subscribers', {'id': id});
    }
  }

  // ══════════════════════════════════════
  //  الأبراج — قراءة محلية
  // ══════════════════════════════════════
  static Future<List<Tower>> getTowers() async {
    if (_isOnline) {
      try {
        final online = await SupabaseService.getTowers();
        await _cacheTowers(online);
        return online;
      } catch (_) {}
    }
    return _getLocalTowers();
  }

  static Future<List<Tower>> _getLocalTowers() async {
    final rows = await db.query('towers');
    return rows.map((r) => Tower(
      id:               r['id'] as String,
      name:             r['name'] as String,
      location:         r['location'] as String? ?? '',
      signalStrength:   r['signal_strength'] as int? ?? 0,
      status:           r['status'] as String? ?? 'offline',
      temperature:      r['temperature'] as double? ?? 0,
      subscriberCount:  r['subscriber_count'] as int? ?? 0,
      currentBandwidth: r['current_bandwidth'] as double? ?? 0,
    )).toList();
  }

  static Future<void> _cacheTowers(List<Tower> towers) async {
    final batch = db.batch();
    for (final t in towers) {
      batch.insert('towers', {
        'id':                t.id,
        'name':              t.name,
        'location':          t.location,
        'signal_strength':   t.signalStrength,
        'status':            t.status,
        'temperature':       t.temperature,
        'subscriber_count':  t.subscriberCount,
        'current_bandwidth': t.currentBandwidth,
        'synced':            1,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  // ══════════════════════════════════════
  //  الدفعات
  // ══════════════════════════════════════
  static Future<void> addPayment(Payment payment) async {
    await db.insert('payments', {
      'id':              payment.id,
      'subscriber_id':   payment.subscriberId,
      'subscriber_name': payment.subscriberName,
      'amount':          payment.amount,
      'method':          payment.method,
      'paid_at':         payment.paidAt.toIso8601String(),
      'synced':          _isOnline ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    if (_isOnline) {
      try {
        await SupabaseService.addPayment(payment);
      } catch (_) {
        await _queueAction('insert', 'payments', payment.toJson());
      }
    } else {
      await _queueAction('insert', 'payments', payment.toJson());
    }
  }

  // ══════════════════════════════════════
  //  مزامنة العمليات المعلقة
  // ══════════════════════════════════════
  static Future<SyncOfflineResult> syncPendingActions() async {
    if (!_isOnline) {
      return SyncOfflineResult(synced: 0, failed: 0,
          message: 'لا يوجد اتصال بالإنترنت');
    }

    final pending = await db.query('pending_actions', orderBy: 'created_at');
    int synced = 0, failed = 0;

    for (final action in pending) {
      try {
        final rawData = action['data'] as String;
        final decoded = jsonDecode(rawData);
        final data = Map<String, dynamic>.from(decoded as Map);
        final tableName = action['table_name'] as String;
        final act       = action['action'] as String;

        if (tableName == 'subscribers') {
          final sub = Subscriber.fromJson(data);
          if (act == 'insert')      await SupabaseService.addSubscriber(sub);
          else if (act == 'update') await SupabaseService.updateSubscriber(sub);
          else if (act == 'delete') await SupabaseService.deleteSubscriber(data['id']);
        } else if (tableName == 'payments') {
          final pay = Payment.fromJson(data);
          if (act == 'insert') await SupabaseService.addPayment(pay);
        }

        await db.delete('pending_actions',
            where: 'id = ?', whereArgs: [action['id']]);
        synced++;
      } catch (_) {
        failed++;
      }
    }

    return SyncOfflineResult(
      synced:  synced,
      failed:  failed,
      message: synced > 0
          ? 'تمت مزامنة $synced عملية بنجاح'
          : 'لا توجد عمليات معلقة',
    );
  }

  // عدد العمليات المعلقة
  static Future<int> getPendingCount() async {
    final res = await db.rawQuery(
        'SELECT COUNT(*) as count FROM pending_actions');
    return res.first['count'] as int;
  }

  // ══════════════════════════════════════
  //  Helpers
  // ══════════════════════════════════════
  static Future<void> _queueAction(
      String action, String table, Map<String, dynamic> data) async {
    await db.insert('pending_actions', {
      'action':     action,
      'table_name': table,
      'data':       jsonEncode(data),
    });
  }

  static Map<String, dynamic> _subscriberToRow(
      Subscriber s, {required int synced}) => {
    'id':         s.id,
    'name':       s.name,
    'phone':      s.phone,
    'area':       s.area,
    'tower_id':   s.towerId,
    'package_id': s.packageId,
    'expires_at': s.expiresAt.toIso8601String(),
    'status':     s.status,
    'synced':     synced,
    'updated_at': DateTime.now().toIso8601String(),
  };

  static Subscriber _rowToSubscriber(Map<String, dynamic> r) => Subscriber(
    id:        r['id'] as String,
    name:      r['name'] as String,
    phone:     r['phone'] as String? ?? '',
    area:      r['area'] as String? ?? '',
    towerId:   r['tower_id'] as String? ?? '',
    packageId: r['package_id'] as String? ?? '',
    expiresAt: DateTime.parse(r['expires_at'] as String),
    status:    r['status'] as String? ?? 'active',
  );
}

class SyncOfflineResult {
  final int    synced, failed;
  final String message;
  const SyncOfflineResult({
    required this.synced,
    required this.failed,
    required this.message,
  });
}
