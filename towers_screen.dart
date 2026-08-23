import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/supabase_service.dart';
import '../models/tower.dart';

class TowersScreen extends StatefulWidget {
  const TowersScreen({super.key});
  @override
  State<TowersScreen> createState() => _TowersScreenState();
}

class _TowersScreenState extends State<TowersScreen> {
  List<Tower> _towers = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final towers = await SupabaseService.getTowers();
    setState(() { _towers = towers; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('حالة الأبراج'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.neon),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.neon))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.neon,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _towers.length,
                itemBuilder: (_, i) => _buildCard(_towers[i]),
              ),
            ),
    );
  }

  Widget _buildCard(Tower t) {
    final color = t.isOnline ? AppColors.neon
        : t.isWarning ? AppColors.orange : AppColors.red;
    final statusText = t.isOnline ? '● نشط'
        : t.isWarning ? '⚠ تحذير' : '✕ معطل';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.cell_tower_rounded, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.name, style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary, fontFamily: 'Cairo')),
                      Text(t.location, style: const TextStyle(
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
                  child: Text(statusText, style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: color, fontFamily: 'Cairo')),
                ),
              ],
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
            ),
            child: Row(
              children: [
                _metric('${t.subscriberCount}', 'مشترك', AppColors.textPrimary),
                _metric('${t.currentBandwidth.toInt()} mb', 'بث', AppColors.neon),
                _metric('${t.signalStrength}%', 'إشارة', color),
                _metric('${t.temperature.toInt()}°', 'حرارة',
                    t.temperature > 55 ? AppColors.orange : AppColors.textPrimary),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Row(
              children: [
                const Text('الإشارة', style: TextStyle(
                    fontSize: 11, color: AppColors.textMuted, fontFamily: 'Cairo')),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: t.signalStrength / 100,
                      backgroundColor: AppColors.surfaceLight,
                      valueColor: AlwaysStoppedAnimation(color),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${t.signalStrength}%', style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: color, fontFamily: 'Cairo')),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _metric(String val, String lbl, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: Column(
          children: [
            Text(val, style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: color, fontFamily: 'Cairo')),
            Text(lbl, style: const TextStyle(
                fontSize: 10, color: AppColors.textMuted, fontFamily: 'Cairo')),
          ],
        ),
      ),
    );
  }
}
