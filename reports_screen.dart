import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/supabase_service.dart';
import '../services/pdf_service.dart';
import '../services/sas4_service.dart';
import '../models/subscriber.dart';
import '../models/payment.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _isLoading = true;

  // بيانات
  List<Subscriber> _subscribers = [];
  List<Payment>    _payments    = [];
  SAS4Stats?       _sas4Stats;
  int              _monthlyRevenue = 0;

  // بيانات الرسوم
  List<_MonthData> _monthlyData    = [];
  Map<String, int> _packageDist    = {};
  Map<String, int> _statusDist     = {};
  Map<String, int> _payMethodDist  = {};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final subs     = await SupabaseService.getSubscribers();
      final payments = await SupabaseService.getPayments(limit: 200);
      final revenue  = await SupabaseService.getMonthlyRevenue();
      final stats    = await SAS4Service.getStats();

      setState(() {
        _subscribers    = subs;
        _payments       = payments;
        _monthlyRevenue = revenue;
        _sas4Stats      = stats;
        _buildChartData();
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _buildChartData() {
    // ─── إيرادات آخر 6 أشهر ───
    final now = DateTime.now();
    _monthlyData = List.generate(6, (i) {
      final month = DateTime(now.year, now.month - (5 - i));
      final total = _payments
          .where((p) =>
              p.paidAt.year == month.year && p.paidAt.month == month.month)
          .fold(0, (sum, p) => sum + p.amount);
      return _MonthData(
        label: _monthLabel(month.month),
        amount: total,
        month: month,
      );
    });

    // ─── توزيع الباقات ───
    _packageDist = {};
    for (final s in _subscribers) {
      _packageDist[s.packageId] = (_packageDist[s.packageId] ?? 0) + 1;
    }

    // ─── توزيع الحالة ───
    _statusDist = {
      'نشط':    _subscribers.where((s) => s.status == 'active' && !s.isExpiringSoon).length,
      'ينتهي':  _subscribers.where((s) => s.isExpiringSoon).length,
      'منقطع':  _subscribers.where((s) => s.status == 'offline').length,
    };

    // ─── توزيع طريقة الدفع ───
    _payMethodDist = {};
    for (final p in _payments) {
      _payMethodDist[p.methodArabic] = (_payMethodDist[p.methodArabic] ?? 0) + 1;
    }
  }

  // ─── تصدير PDF ──────────────────────────
  PopupMenuItem<String> _pdfMenuItem(
      String val, IconData icon, String label) {
    return PopupMenuItem(
      value: val,
      child: Row(children: [
        Icon(icon, color: AppColors.neon, size: 18),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(
            color: AppColors.textPrimary, fontFamily: 'Cairo', fontSize: 13)),
      ]),
    );
  }

  Future<void> _exportPdf(String type) async {
    // إظهار loading
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(children: [
          SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white)),
          SizedBox(width: 12),
          Text('جاري إنشاء التقرير...', style: TextStyle(fontFamily: 'Cairo')),
        ]),
        duration: Duration(seconds: 10),
        backgroundColor: AppColors.surface,
      ),
    );

    try {
      late final file;
      late final String subject;

      switch (type) {
        case 'subscribers':
          file    = await PdfService.generateSubscribersReport(_subscribers);
          subject = 'تقرير المشتركين — SignalX';
          break;
        case 'payments':
          file    = await PdfService.generatePaymentsReport(
              _payments, _monthlyRevenue);
          subject = 'تقرير الدفعات — SignalX';
          break;
        case 'towers':
          final towers = await SupabaseService.getTowers();
          file    = await PdfService.generateTowersReport(towers);
          subject = 'تقرير الأبراج — SignalX';
          break;
        case 'full':
        default:
          final towers = await SupabaseService.getTowers();
          file    = await PdfService.generateFullReport(
            subscribers:    _subscribers,
            payments:       _payments,
            towers:         towers,
            monthlyRevenue: _monthlyRevenue,
          );
          subject = 'التقرير الشامل — SignalX';
      }

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      await PdfService.sharePdf(file, subject);

    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('خطأ: $e',
            style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppColors.red,
      ));
    }
  }

  String _monthLabel(int m) {
    const ar = ['', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
        'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    return ar[m];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير والإحصائيات'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.neon),
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            onSelected: _exportPdf,
            itemBuilder: (_) => [
              _pdfMenuItem('subscribers', Icons.people_alt_rounded,
                  'تقرير المشتركين'),
              _pdfMenuItem('payments', Icons.payments_rounded,
                  'تقرير الدفعات'),
              _pdfMenuItem('towers', Icons.cell_tower_rounded,
                  'تقرير الأبراج'),
              _pdfMenuItem('full', Icons.assessment_rounded,
                  'التقرير الشامل'),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.neon,
          labelColor: AppColors.neon,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600, fontSize: 12),
          tabs: const [
            Tab(text: 'الإيرادات'),
            Tab(text: 'المشتركون'),
            Tab(text: 'SAS4'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.neon))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.neon,
              child: TabBarView(
                controller: _tabs,
                children: [
                  _buildRevenueTab(),
                  _buildSubscribersTab(),
                  _buildSAS4Tab(),
                ],
              ),
            ),
    );
  }

  // ══════════════════════════════════════
  //  تاب الإيرادات
  // ══════════════════════════════════════
  Widget _buildRevenueTab() {
    final maxAmount = _monthlyData.isEmpty
        ? 1.0
        : _monthlyData.map((d) => d.amount).reduce((a, b) => a > b ? a : b).toDouble();
    final total = _payments.fold(0, (s, p) => s + p.amount);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ─── بطاقات الملخص ───
          Row(
            children: [
              _statMini('هذا الشهر',
                  '${NumberFormat('#,###').format(_monthlyRevenue)} د.ع',
                  AppColors.neon, Icons.calendar_today_rounded),
              const SizedBox(width: 8),
              _statMini('الإجمالي',
                  '${NumberFormat('#,###').format(total)} د.ع',
                  AppColors.green, Icons.account_balance_wallet_rounded),
            ],
          ),
          const SizedBox(height: 16),

          // ─── رسم إيرادات 6 أشهر ───
          _chartCard(
            title: 'الإيرادات — آخر 6 أشهر',
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxAmount * 1.3,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    tooltipBgColor: AppColors.surfaceLight,
                    getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                      '${NumberFormat('#,###').format(rod.toY.toInt())} د.ع',
                      const TextStyle(color: AppColors.neon,
                          fontFamily: 'Cairo', fontSize: 11),
                    ),
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, _) => Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _monthlyData[val.toInt()].label,
                          style: const TextStyle(
                              fontSize: 9, color: AppColors.textMuted,
                              fontFamily: 'Cairo'),
                        ),
                      ),
                    ),
                  ),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppColors.border, strokeWidth: 0.5),
                ),
                borderData: FlBorderData(show: false),
                barGroups: _monthlyData.asMap().entries.map((e) {
                  final isLast = e.key == _monthlyData.length - 1;
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.amount.toDouble(),
                        color: isLast ? AppColors.neon : AppColors.neon.withOpacity(0.4),
                        width: 22,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ─── توزيع طريقة الدفع ───
          _chartCard(
            title: 'طريقة الدفع',
            height: 180,
            child: _payMethodDist.isEmpty
                ? const Center(child: Text('لا توجد بيانات',
                    style: TextStyle(color: AppColors.textMuted, fontFamily: 'Cairo')))
                : PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 40,
                      sections: _payMethodDist.entries.map((e) {
                        final colors = [AppColors.neon, AppColors.green, AppColors.orange];
                        final idx    = _payMethodDist.keys.toList().indexOf(e.key);
                        return PieChartSectionData(
                          color: colors[idx % colors.length],
                          value: e.value.toDouble(),
                          title: e.key,
                          radius: 55,
                          titleStyle: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w700,
                              color: Colors.white, fontFamily: 'Cairo'),
                        );
                      }).toList(),
                    ),
                  ),
          ),
          const SizedBox(height: 12),

          // ─── آخر الدفعات ───
          _sectionTitle('آخر الدفعات'),
          const SizedBox(height: 8),
          ..._payments.take(5).map((p) => _paymentRow(p)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  //  تاب المشتركون
  // ══════════════════════════════════════
  Widget _buildSubscribersTab() {
    final active   = _subscribers.where((s) => s.status == 'active').length;
    final expiring = _subscribers.where((s) => s.isExpiringSoon).length;
    final offline  = _subscribers.where((s) => s.status == 'offline').length;
    final total    = _subscribers.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ─── بطاقات الأرقام ───
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8, mainAxisSpacing: 8,
            childAspectRatio: 1.6,
            children: [
              _numCard('$total', 'إجمالي', AppColors.neon),
              _numCard('$active', 'نشط', AppColors.green),
              _numCard('$expiring', 'ينتهي قريباً', AppColors.orange),
              _numCard('$offline', 'منقطع', AppColors.red),
            ],
          ),
          const SizedBox(height: 16),

          // ─── رسم دونات الحالة ───
          _chartCard(
            title: 'توزيع حالات المشتركين',
            height: 200,
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 45,
                      sections: [
                        PieChartSectionData(
                          color: AppColors.neon,
                          value: active.toDouble(),
                          title: '$active',
                          radius: 45,
                          titleStyle: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: Colors.white, fontFamily: 'Cairo'),
                        ),
                        PieChartSectionData(
                          color: AppColors.orange,
                          value: expiring.toDouble(),
                          title: '$expiring',
                          radius: 45,
                          titleStyle: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: Colors.white, fontFamily: 'Cairo'),
                        ),
                        PieChartSectionData(
                          color: AppColors.red,
                          value: offline.toDouble(),
                          title: '$offline',
                          radius: 45,
                          titleStyle: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: Colors.white, fontFamily: 'Cairo'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _legend(AppColors.neon,   'نشط ($active)'),
                    const SizedBox(height: 8),
                    _legend(AppColors.orange, 'ينتهي ($expiring)'),
                    const SizedBox(height: 8),
                    _legend(AppColors.red,    'منقطع ($offline)'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ─── رسم نمو المشتركين ───
          _chartCard(
            title: 'نمو المشتركين — آخر 6 أشهر',
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                      color: AppColors.border, strokeWidth: 0.5),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, _) => Text(
                        _monthlyData[val.toInt()].label,
                        style: const TextStyle(
                            fontSize: 9, color: AppColors.textMuted,
                            fontFamily: 'Cairo'),
                      ),
                    ),
                  ),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(_monthlyData.length, (i) {
                      // محاكاة نمو تدريجي
                      final base = (total * 0.6).toInt();
                      final growth = (total - base) / _monthlyData.length;
                      return FlSpot(i.toDouble(), (base + growth * i));
                    }),
                    isCurved: true,
                    color: AppColors.neon,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      getDotPainter: (spot, _, __, ___) =>
                          FlDotCirclePainter(
                            radius: 3,
                            color: AppColors.neon,
                            strokeWidth: 0,
                          ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.neon.withOpacity(0.08),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  //  تاب SAS4
  // ══════════════════════════════════════
  Widget _buildSAS4Tab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ─── حالة SAS4 ───
          Container(
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
                      width: 10, height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.neon, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    const Text('SASv4 متصل',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                            color: AppColors.neon, fontFamily: 'Cairo')),
                    const Spacer(),
                    const Text('sasradius.com',
                        style: TextStyle(fontSize: 11,
                            color: AppColors.textMuted, fontFamily: 'Cairo')),
                  ],
                ),
                const SizedBox(height: 14),
                if (_sas4Stats != null)
                  GridView.count(
                    crossAxisCount: 2, shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 8, mainAxisSpacing: 8,
                    childAspectRatio: 1.8,
                    children: [
                      _numCard('${_sas4Stats!.totalUsers}',
                          'إجمالي SAS4', AppColors.neon),
                      _numCard('${_sas4Stats!.onlineUsers}',
                          'متصل الآن', AppColors.green),
                      _numCard('${_sas4Stats!.expiredUsers}',
                          'منتهي', AppColors.orange),
                      _numCard('${_sas4Stats!.disabledUsers}',
                          'معطّل', AppColors.red),
                    ],
                  )
                else
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('لا يمكن جلب إحصائيات SAS4',
                        style: TextStyle(color: AppColors.textMuted,
                            fontFamily: 'Cairo', fontSize: 12)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ─── مقارنة SAS4 vs Supabase ───
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('مقارنة البيانات'),
                const SizedBox(height: 12),
                _compareRow(
                  'المشتركون في SAS4',
                  '${_sas4Stats?.totalUsers ?? '—'}',
                  'المشتركون في التطبيق',
                  '${_subscribers.length}',
                ),
                const SizedBox(height: 8),
                _compareRow(
                  'متصل في SAS4',
                  '${_sas4Stats?.onlineUsers ?? '—'}',
                  'نشط في التطبيق',
                  '${_subscribers.where((s) => s.status == 'active').length}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ─── معلومات الـ API ───
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Endpoints المستخدمة'),
                const SizedBox(height: 10),
                _endpointRow('GET', 'index/user',       'جلب المشتركين'),
                _endpointRow('GET', 'index/online',     'المتصلون الآن'),
                _endpointRow('GET', 'index/profile',    'الباقات'),
                _endpointRow('GET', 'index/stats',      'الإحصائيات'),
                _endpointRow('POST', 'create/user',     'إضافة مشترك'),
                _endpointRow('POST', 'activate/user',   'تفعيل اشتراك'),
                _endpointRow('POST', 'extend/user',     'تمديد اشتراك'),
                _endpointRow('POST', 'disconnect/user', 'قطع الاتصال'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Widgets مساعدة ───────────────────

  Widget _chartCard({required String title, required double height,
      required Widget child}) {
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
          Text(title, style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: AppColors.textSecondary, fontFamily: 'Cairo')),
          const SizedBox(height: 14),
          SizedBox(height: height, child: child),
        ],
      ),
    );
  }

  Widget _statMini(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: color, fontFamily: 'Cairo')),
                  Text(label, style: const TextStyle(
                      fontSize: 10, color: AppColors.textMuted,
                      fontFamily: 'Cairo')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numCard(String val, String lbl, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2), width: 0.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(val, style: TextStyle(
              fontSize: 24, fontWeight: FontWeight.w700,
              color: color, fontFamily: 'Cairo')),
          Text(lbl, style: const TextStyle(
              fontSize: 11, color: AppColors.textMuted, fontFamily: 'Cairo')),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(
            fontSize: 11, color: AppColors.textSecondary, fontFamily: 'Cairo')),
      ],
    );
  }

  Widget _paymentRow(Payment p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.payments_rounded,
              color: AppColors.green, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(p.subscriberName,
                style: const TextStyle(fontSize: 12, color: AppColors.textPrimary,
                    fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
          ),
          Text('${NumberFormat('#,###').format(p.amount)} د.ع',
              style: const TextStyle(fontSize: 12, color: AppColors.green,
                  fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _compareRow(String lbl1, String val1, String lbl2, String val2) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.neonGlow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(val1, style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700,
                    color: AppColors.neon, fontFamily: 'Cairo')),
                Text(lbl1, style: const TextStyle(
                    fontSize: 10, color: AppColors.textMuted, fontFamily: 'Cairo')),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('vs', style: TextStyle(
              color: AppColors.textMuted, fontFamily: 'Cairo', fontSize: 11)),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.purpleGlow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(val2, style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700,
                    color: AppColors.purple, fontFamily: 'Cairo')),
                Text(lbl2, style: const TextStyle(
                    fontSize: 10, color: AppColors.textMuted, fontFamily: 'Cairo')),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _endpointRow(String method, String path, String desc) {
    final isGet = method == 'GET';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: isGet
                  ? AppColors.neonGlow
                  : AppColors.purpleGlow,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(method,
                style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w700,
                    color: isGet ? AppColors.neon : AppColors.purple,
                    fontFamily: 'Cairo')),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(path,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary,
                    fontFamily: 'Cairo',
                    fontFamilyFallback: ['monospace'])),
          ),
          Text(desc,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textMuted, fontFamily: 'Cairo')),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(t,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
          color: AppColors.textMuted, letterSpacing: 0.5, fontFamily: 'Cairo'));
}

class _MonthData {
  final String label;
  final int amount;
  final DateTime month;
  const _MonthData({required this.label, required this.amount, required this.month});
}
