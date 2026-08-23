import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/subscriber.dart';

/// SAS4Service — يتصل بـ SASv4 API مباشرة
/// الـ API يشتغل بنظام: login → session cookie → POST requests
class SAS4Service {
  static const String _baseUrl = 'YOUR_SAS4_SERVER_URL';
  static String? _sessionCookie;
  static DateTime? _lastLogin;
  static const _sessionTimeout = Duration(minutes: 30);
  static const String _username = 'YOUR_MANAGER_USERNAME';
  static const String _password = 'YOUR_MANAGER_PASSWORD';

  // ══════════════════════════════════════
  //  تسجيل الدخول وحفظ الـ Session
  // ══════════════════════════════════════
  static Future<bool> login() async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'username': _username, 'password': _password},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final cookies = res.headers['set-cookie'];
        if (cookies != null) {
          _sessionCookie = cookies.split(';').first;
          _lastLogin = DateTime.now();
          return true;
        }
      }
      return false;
    } catch (e) {
      print('SAS4 login error: $e');
      return false;
    }
  }

  static Future<void> _ensureSession() async {
    final needsLogin = _sessionCookie == null ||
        _lastLogin == null ||
        DateTime.now().difference(_lastLogin!) > _sessionTimeout;
    if (needsLogin) await login();
  }

  static Future<Map<String, dynamic>?> _post(
      String endpoint, Map<String, dynamic> body) async {
    await _ensureSession();
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          if (_sessionCookie != null) 'Cookie': _sessionCookie!,
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) return jsonDecode(res.body);
      return null;
    } catch (e) {
      print('SAS4 POST error ($endpoint): $e');
      return null;
    }
  }

  // ══════════════════════════════════════
  //  جلب كل المشتركين
  // ══════════════════════════════════════
  static Future<List<SAS4User>> getUsers() async {
    final res = await _post('index/user', {});
    if (res == null) return [];
    final data = res['data'] as List? ?? res['users'] as List? ?? [];
    return data.map((u) => SAS4User.fromJson(u)).toList();
  }

  // ══════════════════════════════════════
  //  المشتركين المتصلين الآن
  // ══════════════════════════════════════
  static Future<List<SAS4User>> getOnlineUsers() async {
    final res = await _post('index/online', {});
    if (res == null) return [];
    final data = res['data'] as List? ?? [];
    return data.map((u) => SAS4User.fromJson(u)).toList();
  }

  // ══════════════════════════════════════
  //  تحويل SAS4User → Subscriber
  // ══════════════════════════════════════
  static List<Subscriber> convertToSubscribers(List<SAS4User> sas4Users) {
    return sas4Users.map((u) => Subscriber(
      id:        u.username,
      name:      u.fullName.isNotEmpty ? u.fullName : u.username,
      phone:     u.mobile,
      area:      u.address,
      towerId:   '',
      packageId: u.profile,
      expiresAt: u.expiration ?? DateTime.now().add(const Duration(days: 30)),
      status:    _mapStatus(u.status),
    )).toList();
  }

  static String _mapStatus(String s) {
    switch (s.toLowerCase()) {
      case 'active':
      case 'online':   return 'active';
      case 'expired':
      case 'disabled': return 'offline';
      default:         return 'active';
    }
  }

  // ══════════════════════════════════════
  //  إنشاء مشترك جديد
  // ══════════════════════════════════════
  static Future<bool> createUser({
    required String username,
    required String password,
    required String profile,
    String? fullName,
    String? mobile,
    String? address,
  }) async {
    final res = await _post('create/user', {
      'username':  username,
      'password':  password,
      'profile':   profile,
      'full_name': fullName ?? '',
      'mobile':    mobile ?? '',
      'address':   address ?? '',
      'enabled':   1,
    });
    return res != null && (res['success'] == true || res['status'] == 'ok');
  }

  // ══════════════════════════════════════
  //  تفعيل / تمديد / قطع / حذف
  // ══════════════════════════════════════
  static Future<bool> activateUser(String username, String profile) async {
    final res = await _post('activate/user', {'username': username, 'profile': profile});
    return res != null && (res['success'] == true || res['status'] == 'ok');
  }

  static Future<bool> extendUser(String username, int days) async {
    final res = await _post('extend/user', {'username': username, 'days': days});
    return res != null && (res['success'] == true || res['status'] == 'ok');
  }

  static Future<bool> disconnectUser(String username) async {
    final res = await _post('disconnect/user', {'username': username});
    return res != null && (res['success'] == true || res['status'] == 'ok');
  }

  static Future<bool> deleteUser(String username) async {
    final res = await _post('delete/user', {'username': username});
    return res != null && (res['success'] == true || res['status'] == 'ok');
  }

  // ══════════════════════════════════════
  //  الباقات (Profiles)
  // ══════════════════════════════════════
  static Future<List<SAS4Profile>> getProfiles() async {
    final res = await _post('index/profile', {});
    if (res == null) return [];
    final data = res['data'] as List? ?? [];
    return data.map((p) => SAS4Profile.fromJson(p)).toList();
  }

  // ══════════════════════════════════════
  //  إحصائيات النظام
  // ══════════════════════════════════════
  static Future<SAS4Stats?> getStats() async {
    final res = await _post('index/stats', {});
    if (res == null) return null;
    return SAS4Stats.fromJson(res);
  }
}

// ─── موديل مشترك SAS4 ───────────────────
class SAS4User {
  final String username;
  final String fullName;
  final String mobile;
  final String address;
  final String profile;
  final String status;
  final DateTime? expiration;
  final String? ipAddress;

  SAS4User({
    required this.username,
    required this.fullName,
    required this.mobile,
    required this.address,
    required this.profile,
    required this.status,
    this.expiration,
    this.ipAddress,
  });

  factory SAS4User.fromJson(Map<String, dynamic> json) => SAS4User(
    username:   json['username']  ?? json['user']             ?? '',
    fullName:   json['full_name'] ?? json['name']             ?? '',
    mobile:     json['mobile']    ?? json['phone']            ?? '',
    address:    json['address']   ?? '',
    profile:    json['profile']   ?? json['service_profile']  ?? '',
    status:     json['status']    ?? 'active',
    expiration: json['expiration'] != null
        ? DateTime.tryParse(json['expiration'])
        : null,
    ipAddress:  json['ip_address'] ?? json['framedip'],
  );
}

// ─── موديل باقة SAS4 ────────────────────
class SAS4Profile {
  final String name;
  final String displayName;
  final int downloadKbps;
  final int uploadKbps;
  final double price;
  final int durationDays;

  SAS4Profile({
    required this.name,
    required this.displayName,
    required this.downloadKbps,
    required this.uploadKbps,
    required this.price,
    required this.durationDays,
  });

  factory SAS4Profile.fromJson(Map<String, dynamic> json) => SAS4Profile(
    name:         json['name']         ?? '',
    displayName:  json['display_name'] ?? json['name'] ?? '',
    downloadKbps: json['dl_speed']     ?? json['download'] ?? 0,
    uploadKbps:   json['ul_speed']     ?? json['upload'] ?? 0,
    price:        (json['price'] as num?)?.toDouble() ?? 0,
    durationDays: json['duration']     ?? 30,
  );

  String get speedDisplay {
    final dl = downloadKbps >= 1000
        ? '${(downloadKbps / 1000).toStringAsFixed(0)} Mbps'
        : '$downloadKbps Kbps';
    return dl;
  }
}

// ─── موديل إحصائيات SAS4 ────────────────
class SAS4Stats {
  final int totalUsers;
  final int onlineUsers;
  final int expiredUsers;
  final int disabledUsers;

  SAS4Stats({
    required this.totalUsers,
    required this.onlineUsers,
    required this.expiredUsers,
    required this.disabledUsers,
  });

  factory SAS4Stats.fromJson(Map<String, dynamic> json) => SAS4Stats(
    totalUsers:    json['total']    ?? 0,
    onlineUsers:   json['online']   ?? 0,
    expiredUsers:  json['expired']  ?? 0,
    disabledUsers: json['disabled'] ?? 0,
  );
}
