import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/supabase_service.dart';
import '../models/subscriber.dart';

class SubscribersScreen extends StatefulWidget {
  const SubscribersScreen({super.key});

  @override
  State<SubscribersScreen> createState() => _SubscribersScreenState();
}

class _SubscribersScreenState extends State<SubscribersScreen> {
  List<Subscriber> _all = [];
  List<Subscriber> _filtered = [];
  String _filter = 'all';
  bool _isLoading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final subs = await SupabaseService.getSubscribers();
    setState(() {
      _all = subs;
      _filtered = subs;
      _isLoading = false;
    });
  }

  void _applyFilter(String filter) {
    setState(() {
      _filter = filter;
      _filtered = _all.where((s) {
        if (filter == 'all')      return true;
        if (filter == 'active')   return s.status == 'active';
        if (filter == 'expiring') return s.isExpiringSoon;
        if (filter == 'offline')  return s.status == 'offline';
        return true;
      }).toList();
    });
  }

  void _search(String q) {
    setState(() {
      _filtered = _all.where((s) =>
          s.name.contains(q) || s.phone.contains(q)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المشتركون'),
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/add-subscriber'),
            icon: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: AppColors.neon,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.add, color: Colors.black, size: 18),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _search,
              style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo'),
              decoration: const InputDecoration(
                hintText: 'ابحث عن مشترك...',
                prefixIcon: Icon(Icons.search, color: AppColors.textMuted, size: 20),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _filterChip('all',      'الكل (${_all.length})'),
                _filterChip('active',   'نشط'),
                _filterChip('expiring', 'ينتهي'),
                _filterChip('offline',  'منقطع'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.neon))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => _buildSubCard(_filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    final active = _filter == value;
    return GestureDetector(
      onTap: () => _applyFilter(value),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.neon : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppColors.neon : AppColors.border, width: 0.5),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Cairo',
                color: active ? Colors.black : AppColors.textMuted)),
      ),
    );
  }

  Widget _buildSubCard(Subscriber sub) {
    final daysLeft = sub.expiresAt.difference(DateTime.now()).inDays;
    Color badgeColor;
    String badgeText;
    if (sub.status == 'offline') {
      badgeColor = AppColors.red; badgeText = 'منقطع';
    } else if (sub.isExpiringSoon) {
      badgeColor = AppColors.orange;
      badgeText = daysLeft <= 0 ? 'منتهي' : '$daysLeft أيام';
    } else {
      badgeColor = AppColors.neon; badgeText = 'نشط';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.neonGlow,
            child: Text(
              sub.name.characters.first,
              style: const TextStyle(
                  color: AppColors.neon, fontWeight: FontWeight.w700, fontFamily: 'Cairo'),
            ),
          ),
          const SizedBox(width: 12),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(badgeText,
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: badgeColor, fontFamily: 'Cairo')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
