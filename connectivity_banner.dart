import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../theme/app_theme.dart';
import '../services/offline_service.dart';

// ─── مؤشر حالة الاتصال يظهر في أعلى كل شاشة ───
class ConnectivityBanner extends StatefulWidget {
  final Widget child;
  const ConnectivityBanner({super.key, required this.child});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  bool _isOnline    = true;
  int  _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _checkStatus();
    Connectivity().onConnectivityChanged.listen((result) {
      setState(() {
        _isOnline = !result.contains(ConnectivityResult.none);
        if (result.isEmpty) _isOnline = false;
      });
      if (_isOnline) _syncPending();
    });
  }

  Future<void> _checkStatus() async {
    final conn    = await Connectivity().checkConnectivity();
    final pending = await OfflineService.getPendingCount();
    setState(() {
      _isOnline     = !conn.contains(ConnectivityResult.none);
      if (conn.isEmpty) _isOnline = false;
      _pendingCount = pending;
    });
  }

  Future<void> _syncPending() async {
    if (_pendingCount > 0) {
      await OfflineService.syncPendingActions();
      final p = await OfflineService.getPendingCount();
      setState(() => _pendingCount = p);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!_isOnline)
          Material(
            color: AppColors.orange,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off_rounded,
                        size: 16, color: Colors.white),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'وضع عدم الاتصال — البيانات محفوظة محلياً',
                        style: TextStyle(
                            fontSize: 12, color: Colors.white,
                            fontFamily: 'Cairo', fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (_pendingCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('$_pendingCount معلق',
                            style: const TextStyle(
                                fontSize: 10, color: Colors.white,
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        if (_isOnline && _pendingCount > 0)
          Material(
            color: AppColors.neon,
            child: GestureDetector(
              onTap: _syncPending,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 5),
                child: Row(
                  children: [
                    const Icon(Icons.sync_rounded,
                        size: 14, color: AppColors.background),
                    const SizedBox(width: 6),
                    Text(
                      'يوجد $_pendingCount عملية غير مزامنة — اضغط للمزامنة',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.background,
                          fontFamily: 'Cairo', fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}

// ─── Badge صغير يظهر في AppBar ─────────
class OfflineBadge extends StatelessWidget {
  const OfflineBadge({super.key});

  @override
  Widget build(BuildContext context) {
    if (OfflineService.isOnline) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.orange,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded, size: 12, color: Colors.white),
          SizedBox(width: 4),
          Text('Offline',
              style: TextStyle(fontSize: 10, color: Colors.white,
                  fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
