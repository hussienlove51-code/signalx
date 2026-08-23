import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/supabase_service.dart';
import 'services/notification_service.dart';
import 'services/offline_service.dart';
import 'services/backup_service.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';
import 'widgets/connectivity_banner.dart';
import 'screens/dashboard_screen.dart';
import 'screens/subscribers_screen.dart';
import 'screens/towers_screen.dart';
import 'screens/towers_map_screen.dart';
import 'screens/payments_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/backup_screen.dart';
import 'screens/subscriber_portal_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  await SupabaseService.initialize();
  await NotificationService.initialize();
  await OfflineService.initialize();
  BackupService.autoBackupIfNeeded();
  NotificationService.checkExpirations();
  final auth = AuthService();
  await auth.restoreSession();
  runApp(ChangeNotifierProvider.value(
    value: auth,
    child: const SignalXApp(),
  ));
}

class SignalXApp extends StatelessWidget {
  const SignalXApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SignalX',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      // نقطتا دخول: المدير أو المشترك
      initialRoute: '/',
      routes: {
        '/':        (_) => Consumer<AuthService>(
          builder: (_, auth, __) => auth.isLoggedIn
              ? const ConnectivityBanner(child: MainNavigator())
              : const LoginScreen(),
        ),
        '/portal':  (_) => const SubscriberPortalScreen(),
      },
    );
  }
}

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});
  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _idx = 0;

  final _screens = const [
    DashboardScreen(),
    SubscribersScreen(),
    TowersScreen(),
    PaymentsScreen(),
    ReportsScreen(),
  ];

  final _items = const [
    _NavItem(Icons.grid_view_rounded,  'الرئيسية'),
    _NavItem(Icons.people_alt_rounded, 'المشتركون'),
    _NavItem(Icons.cell_tower_rounded, 'الأبراج'),
    _NavItem(Icons.payments_rounded,   'الدفعات'),
    _NavItem(Icons.bar_chart_rounded,  'التقارير'),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    return Scaffold(
      body: IndexedStack(index: _idx, children: _screens),
      bottomNavigationBar: _navBar(auth),
    );
  }

  Widget _navBar(AuthService auth) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D1220),
        border: Border(top: BorderSide(color: Color(0xFF1A2540), width: 0.5)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              ..._items.asMap().entries.map((e) {
                final active = _idx == e.key;
                return GestureDetector(
                  onTap: () => setState(() => _idx = e.key),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: active ? const Color(0x2200D4FF) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(e.value.icon,
                          color: active ? const Color(0xFF00D4FF) : const Color(0xFF4A6FA5),
                          size: 22),
                      const SizedBox(height: 3),
                      Text(e.value.label, style: TextStyle(
                          fontSize: 9, fontFamily: 'Cairo',
                          fontWeight: FontWeight.w600,
                          color: active ? const Color(0xFF00D4FF) : const Color(0xFF4A6FA5))),
                    ]),
                  ),
                );
              }),
              PopupMenuButton<String>(
                color: const Color(0xFF0D1220),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                icon: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.more_vert_rounded,
                      color: Color(0xFF4A6FA5), size: 22),
                  const SizedBox(height: 3),
                  Text(auth.name.split(' ').first,
                      style: const TextStyle(fontSize: 9, fontFamily: 'Cairo',
                          color: Color(0xFF4A6FA5))),
                ]),
                onSelected: (val) {
                  switch (val) {
                    case 'settings':
                      Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const SettingsScreen()));
                      break;
                    case 'backup':
                      Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const BackupScreen()));
                      break;
                    case 'map':
                      Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const TowersMapScreen()));
                      break;
                    case 'portal':
                      Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const SubscriberPortalScreen()));
                      break;
                    case 'logout':
                      context.read<AuthService>().logout();
                      break;
                  }
                },
                itemBuilder: (_) => [
                  _mi('map',      Icons.map_rounded,
                      'خريطة الأبراج',       const Color(0xFF00D4FF)),
                  _mi('portal',   Icons.person_pin_rounded,
                      'بوابة المشترك',       const Color(0xFF00E676)),
                  _mi('settings', Icons.settings_rounded,
                      'الإعدادات',           const Color(0xFF8AB4D4)),
                  _mi('backup',   Icons.backup_rounded,
                      'النسخ الاحتياطية',    const Color(0xFF00D4FF)),
                  const PopupMenuDivider(),
                  _mi('logout',   Icons.logout_rounded,
                      'تسجيل الخروج',        const Color(0xFFFF4D6D)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _mi(String v, IconData icon, String label, Color c) =>
      PopupMenuItem(value: v, child: Row(children: [
        Icon(icon, color: c, size: 18), const SizedBox(width: 10),
        Text(label, style: TextStyle(color: c, fontFamily: 'Cairo',
            fontSize: 13, fontWeight: FontWeight.w600)),
      ]));
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}
