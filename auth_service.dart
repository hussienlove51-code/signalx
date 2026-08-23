import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────
//  AuthService — إدارة تسجيل الدخول والصلاحيات
// ─────────────────────────────────────────
class AuthService extends ChangeNotifier {
  static const _keyLoggedIn = 'is_logged_in';
  static const _keyUsername = 'username';
  static const _keyRole     = 'user_role';
  static const _keyName     = 'user_name';

  bool   _isLoggedIn = false;
  String _username   = '';
  String _role       = 'viewer'; // admin | employee | viewer
  String _name       = '';

  bool   get isLoggedIn => _isLoggedIn;
  String get username   => _username;
  String get role       => _role;
  String get name       => _name;
  bool   get isAdmin    => _role == 'admin';
  bool   get isEmployee => _role == 'admin' || _role == 'employee';

  // ══════════════════════════════════════
  //  المستخدمون المبدئيون (تغيّرهم بعدين من الإعدادات)
  // ══════════════════════════════════════
  static final _users = {
    'admin': {
      'password': _hash('admin123'),
      'role': 'admin',
      'name': 'عبدالله صالح',
    },
    'musa': {
      'password': _hash('musa456'),
      'role': 'employee',
      'name': 'موسى حسن',
    },
    'view': {
      'password': _hash('view789'),
      'role': 'viewer',
      'name': 'مشاهد',
    },
  };

  static String _hash(String input) =>
      sha256.convert(utf8.encode(input)).toString();

  // ══════════════════════════════════════
  //  تسجيل الدخول
  // ══════════════════════════════════════
  Future<LoginResult> login(String username, String password) async {
    await Future.delayed(const Duration(milliseconds: 500)); // محاكاة تأخير

    final user = _users[username.trim().toLowerCase()];
    if (user == null) {
      return LoginResult(success: false, message: 'اسم المستخدم غير موجود');
    }
    if (user['password'] != _hash(password)) {
      return LoginResult(success: false, message: 'كلمة المرور غير صحيحة');
    }

    _isLoggedIn = true;
    _username   = username;
    _role       = user['role']!;
    _name       = user['name']!;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLoggedIn, true);
    await prefs.setString(_keyUsername, username);
    await prefs.setString(_keyRole,     _role);
    await prefs.setString(_keyName,     _name);

    notifyListeners();
    return LoginResult(success: true, message: 'مرحباً $_name!');
  }

  // ══════════════════════════════════════
  //  استعادة الجلسة عند فتح التطبيق
  // ══════════════════════════════════════
  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool(_keyLoggedIn) ?? false;
    _username   = prefs.getString(_keyUsername) ?? '';
    _role       = prefs.getString(_keyRole)     ?? 'viewer';
    _name       = prefs.getString(_keyName)     ?? '';
    notifyListeners();
  }

  // ══════════════════════════════════════
  //  تسجيل الخروج
  // ══════════════════════════════════════
  Future<void> logout() async {
    _isLoggedIn = false;
    _username   = '';
    _role       = 'viewer';
    _name       = '';

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLoggedIn);
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyRole);
    await prefs.remove(_keyName);

    notifyListeners();
  }

  // فحص الصلاحية
  bool canDo(String action) {
    switch (action) {
      case 'add_subscriber':
      case 'edit_subscriber':
      case 'delete_subscriber':
      case 'add_payment':
        return isEmployee;
      case 'manage_towers':
      case 'change_settings':
      case 'export_pdf':
        return isAdmin;
      case 'view_reports':
      case 'view_subscribers':
        return true;
      default:
        return isAdmin;
    }
  }
}

class LoginResult {
  final bool   success;
  final String message;
  const LoginResult({required this.success, required this.message});
}

// ─────────────────────────────────────────
//  شاشة تسجيل الدخول
// ─────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure   = true;
  bool _loading   = false;
  String? _error;
  late AnimationController _anim;
  late Animation<double>   _fade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_userCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'يرجى إدخال اسم المستخدم وكلمة المرور');
      return;
    }
    setState(() { _loading = true; _error = null; });

    final auth = context.read<AuthService>();
    final result = await auth.login(_userCtrl.text, _passCtrl.text);

    setState(() => _loading = false);

    if (!result.success) {
      setState(() => _error = result.message);
    }
    // إذا نجح، الـ provider يغيّر الحالة تلقائياً
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 48),

                // ─── شعار التطبيق ───
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.neon, AppColors.neonDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.neon.withOpacity(0.3),
                        blurRadius: 24, spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.cell_tower_rounded,
                      size: 40, color: Colors.white),
                ),
                const SizedBox(height: 20),

                RichText(
                  text: const TextSpan(
                    style: TextStyle(fontFamily: 'Cairo',
                        fontSize: 28, fontWeight: FontWeight.w700),
                    children: [
                      TextSpan(text: 'Signal',
                          style: TextStyle(color: Colors.white)),
                      TextSpan(text: 'X',
                          style: TextStyle(color: AppColors.neon)),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                const Text('إدارة أبراج الإنترنت',
                    style: TextStyle(fontSize: 13,
                        color: AppColors.textMuted, fontFamily: 'Cairo')),
                const SizedBox(height: 48),

                // ─── نموذج الدخول ───
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('تسجيل الدخول',
                          style: TextStyle(fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              fontFamily: 'Cairo')),
                      const SizedBox(height: 20),

                      // اسم المستخدم
                      TextField(
                        controller: _userCtrl,
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontFamily: 'Cairo'),
                        decoration: const InputDecoration(
                          hintText: 'اسم المستخدم',
                          prefixIcon: Icon(Icons.person_rounded,
                              color: AppColors.textMuted, size: 20),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // كلمة المرور
                      TextField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        onSubmitted: (_) => _login(),
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontFamily: 'Cairo'),
                        decoration: InputDecoration(
                          hintText: 'كلمة المرور',
                          prefixIcon: const Icon(Icons.lock_rounded,
                              color: AppColors.textMuted, size: 20),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                              color: AppColors.textMuted, size: 20,
                            ),
                          ),
                        ),
                      ),

                      // رسالة الخطأ
                      if (_error != null) ...[
                        const SizedBox(height: 10),
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
                                style: const TextStyle(
                                    color: AppColors.red, fontSize: 12,
                                    fontFamily: 'Cairo')),
                          ]),
                        ),
                      ],

                      const SizedBox(height: 18),

                      // زر الدخول
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _loading
                              ? const SizedBox(width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text('دخول',
                                  style: TextStyle(fontFamily: 'Cairo',
                                      fontSize: 15, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ─── تلميح الصلاحيات ───
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.neonGlow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.neon.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.info_outline,
                            color: AppColors.neon, size: 15),
                        SizedBox(width: 6),
                        Text('مستويات الصلاحية',
                            style: TextStyle(fontSize: 12,
                                color: AppColors.neon,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Cairo')),
                      ]),
                      const SizedBox(height: 8),
                      _roleHint('🔴 مدير',    'كل الصلاحيات'),
                      _roleHint('🟡 موظف',    'إضافة وتعديل المشتركين'),
                      _roleHint('🟢 مشاهد',   'عرض فقط بدون تعديل'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleHint(String role, String desc) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(children: [
        Text(role, style: const TextStyle(
            fontSize: 11, color: AppColors.textSecondary, fontFamily: 'Cairo')),
        const Text(' — ', style: TextStyle(color: AppColors.textMuted)),
        Text(desc, style: const TextStyle(
            fontSize: 11, color: AppColors.textMuted, fontFamily: 'Cairo')),
      ]),
    );
  }
}
