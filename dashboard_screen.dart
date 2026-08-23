import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/supabase_service.dart';
import '../models/subscriber.dart';
import '../models/tower.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic> _stats = {};
  List<Subscriber> _expiring = [];
  List<Tower> _towers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final stats    = await SupabaseService.getDashboardStats();
      final expiring = await SupabaseService.getExpiringSoon();
      final towers   = await SupabaseService.getTowers();
      setState(() {
        _stats    = stats;
        _expiring = expiring;
        _towers   = towers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.neon,
          backgroundColor: AppColors.surface,
          onRefresh: _loadData,
          child: CustomScrollView(
            slivers: [
              _buildAppBar(),
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.neon),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildGreeting(),
                      const SizedBox(height: 16),
                      _buildStatsGrid(),
                      const SizedBox(height: 20),
                      _buildSectionTitle('حالة الأبراج'),
                      const SizedBox(height: 10),
                      ..._towers.map((t) => _buildTowerCard(t)),
                      const SizedBox(height: 20),
                      _buildSectionTitle('ينتهون قريباً'),
                      const SizedBox(height: 10),
                      ..._expiring.map((s) => _buildSubscriberTile(s)),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppColors.surface,
      elevation: 0,
      title: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.neon, AppColors.neonDark],
              ),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.cell_tower_rounded, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          RichText(
            text: const TextSpan(
              style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w700),
              children: [
                TextSpan(text: 'Signal', style: TextStyle(color: Colors.white)),
                TextSpan(text: 'X', style: TextStyle(color: AppColors.neon)),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () {},
          icon: Stack(
            children: [
              const Icon(Icons.notifications_outlined, color: AppColors.textSecondary),
              Positioned(
                top: 0, right: 0,
                child: Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.neon,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGreeting() {
    return Text(
      'مرحباً، عبدالله 👋',
      style: TextStyle(
        fontSize: 14,
        color: AppColors.textMuted,
        fontFamily: 'Cairo',
      ),
    );
  }

  Widget _buildStatsGrid() {
    final items = [
      _StatData('إجمالي المشتركين', '${_stats['total_subscribers'] ?? 0}',
          Icons.people_alt_rounded, AppColors.neon, AppColors.neonGlow),
      _StatData('الإيرادات (د.ع)', '${((_stats['monthly_revenue'] ?? 0) / 1000).toStringAsFixed(0)}K',
          Icons.payments_rounded, AppColors.green, AppColors.greenGlow),
      _StatData('ينتهون قريباً', '${_stats['expiring_soon'] ?? 0}',
          Icons.timer_outlined, AppColors.orange, AppColors.orangeGlow),
      _StatData('وقت التشغيل', '99%',
          Icons.signal_cellular_alt_rounded, AppColors.purple, AppColors.purpleGlow),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.4,
      children: items.map((item) => _buildStatCard(item)).toList(),
    );
  }

  Widget _buildStatCard(_StatData data) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: data.glow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(data.icon, color: data.color, size: 18),
          ),
          const Spacer(),
          Text(
            data.value,
            style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w700,
              color: data.color, fontFamily: 'Cairo',
            ),
          ),
          Text(
            data.label,
            style: const TextStyle(
              fontSize: 11, color: AppColors.textMuted, fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14, fontWeight: FontWeight.w700,
        color: AppColors.textSecondary, fontFamily: 'Cairo',
      ),
    );
  }

  Widget _buildTowerCard(Tower tower) {
    final color = tower.isOnline
        ? AppColors.neon
        : tower.isWarning
            ? AppColors.orange
            : AppColors.red;

    final statusText = tower.isOnline
        ? '● نشط'
        : tower.isWarning
            ? '⚠ تحذير'
            : '✕ معطل';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.cell_tower_rounded, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tower.name,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary, fontFamily: 'Cairo')),
                    Text(tower.location,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted, fontFamily: 'Cairo')),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(statusText,
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: color, fontFamily: 'Cairo')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMiniStat('${tower.subscriberCount}', 'مشترك', AppColors.textPrimary),
              _buildMiniStat('${tower.currentBandwidth.toInt()}mb', 'بث', AppColors.neon),
              _buildMiniStat('${tower.signalStrength}%', 'إشارة', color),
              _buildMiniStat('${tower.temperature.toInt()}°', 'حرارة',
                  tower.temperature > 55 ? AppColors.orange : AppColors.textPrimary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: color, fontFamily: 'Cairo')),
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textMuted, fontFamily: 'Cairo')),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriberTile(Subscriber sub) {
    final daysLeft = sub.expiresAt.difference(DateTime.now()).inDays;
    final color = daysLeft <= 3 ? AppColors.red : AppColors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.neonGlow,
            child: Text(
              sub.name.characters.first,
              style: const TextStyle(
                  color: AppColors.neon, fontWeight: FontWeight.w700, fontFamily: 'Cairo'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sub.name,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary, fontFamily: 'Cairo')),
                Text(sub.phone,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted, fontFamily: 'Cairo')),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              daysLeft <= 0 ? 'منتهي' : '$daysLeft أيام',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: color, fontFamily: 'Cairo'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatData {
  final String label, value;
  final IconData icon;
  final Color color, glow;
  const _StatData(this.label, this.value, this.icon, this.color, this.glow);
}
