import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/subscriber.dart';
import '../models/payment.dart';
import '../models/tower.dart';

/// ─────────────────────────────────────────
///  PdfService — تصدير التقارير كـ PDF
///  يستخدم مكتبة pdf الرسمية لـ Flutter
/// ─────────────────────────────────────────
class PdfService {

  // ── ألوان SignalX ─────────────────────
  static const _neon   = PdfColor.fromInt(0xFF00D4FF);
  static const _dark   = PdfColor.fromInt(0xFF0A0E1A);
  static const _surface= PdfColor.fromInt(0xFF0D1220);
  static const _green  = PdfColor.fromInt(0xFF00E676);
  static const _orange = PdfColor.fromInt(0xFFFFA000);
  static const _red    = PdfColor.fromInt(0xFFFF4D6D);
  static const _grey   = PdfColor.fromInt(0xFF4A6FA5);
  static const _white  = PdfColors.white;
  static const _border = PdfColor.fromInt(0xFF1A2540);

  // ══════════════════════════════════════
  //  تقرير المشتركين
  // ══════════════════════════════════════
  static Future<File> generateSubscribersReport(
      List<Subscriber> subscribers) async {
    final pdf  = pw.Document();
    final now  = DateTime.now();
    final fmt  = NumberFormat('#,###');

    // إحصائيات
    final active   = subscribers.where((s) => s.status == 'active').length;
    final expiring = subscribers.where((s) => s.isExpiringSoon).length;
    final offline  = subscribers.where((s) => s.status == 'offline').length;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
        ),
        header: (_) => _buildHeader('تقرير المشتركين', now),
        footer: (_) => _buildFooter(),
        build: (ctx) => [
          // ─── ملخص أرقام ───
          _buildStatsRow([
            _Stat('إجمالي المشتركين', '${subscribers.length}', _neon),
            _Stat('نشط',    '$active',   _green),
            _Stat('ينتهي',  '$expiring', _orange),
            _Stat('منقطع',  '$offline',  _red),
          ]),
          pw.SizedBox(height: 20),

          // ─── جدول المشتركين ───
          _buildSectionTitle('قائمة المشتركين'),
          pw.SizedBox(height: 10),
          _buildTable(
            headers: ['الاسم', 'الهاتف', 'المنطقة', 'الباقة', 'الانتهاء', 'الحالة'],
            widths:  [2.5, 1.5, 1.5, 1.5, 1.5, 1.0],
            rows: subscribers.map((s) {
              final days = s.expiresAt.difference(DateTime.now()).inDays;
              return [
                s.name,
                s.phone,
                s.area,
                s.packageId,
                DateFormat('dd/MM/yyyy').format(s.expiresAt),
                days < 0 ? 'منتهي' : s.status == 'active' ? 'نشط' : 'منقطع',
              ];
            }).toList(),
            statusCol: 5,
          ),
        ],
      ),
    );

    return _savePdf(pdf, 'subscribers_report');
  }

  // ══════════════════════════════════════
  //  تقرير الدفعات
  // ══════════════════════════════════════
  static Future<File> generatePaymentsReport(
      List<Payment> payments, int monthlyRevenue) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final fmt = NumberFormat('#,###');

    final total     = payments.fold(0, (s, p) => s + p.amount);
    final cashCount = payments.where((p) => p.method == 'cash').length;
    final appCount  = payments.where((p) => p.method == 'app').length;
    final zainCount = payments.where((p) => p.method == 'zain_cash').length;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
        ),
        header: (_) => _buildHeader('تقرير الدفعات', now),
        footer: (_) => _buildFooter(),
        build: (ctx) => [
          _buildStatsRow([
            _Stat('هذا الشهر', '${fmt.format(monthlyRevenue)} IQD', _neon),
            _Stat('الإجمالي',  '${fmt.format(total)} IQD',          _green),
            _Stat('نقداً',     '$cashCount دفعة',                    _orange),
            _Stat('إلكتروني', '${appCount + zainCount} دفعة',        _neon),
          ]),
          pw.SizedBox(height: 20),
          _buildSectionTitle('سجل الدفعات'),
          pw.SizedBox(height: 10),
          _buildTable(
            headers: ['المشترك', 'المبلغ (د.ع)', 'الطريقة', 'التاريخ'],
            widths:  [3.0, 2.0, 2.0, 2.0],
            rows: payments.map((p) => [
              p.subscriberName,
              fmt.format(p.amount),
              p.methodArabic,
              DateFormat('dd/MM/yyyy HH:mm').format(p.paidAt),
            ]).toList(),
          ),
        ],
      ),
    );

    return _savePdf(pdf, 'payments_report');
  }

  // ══════════════════════════════════════
  //  تقرير الأبراج
  // ══════════════════════════════════════
  static Future<File> generateTowersReport(List<Tower> towers) async {
    final pdf = pw.Document();
    final now = DateTime.now();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
        ),
        header: (_) => _buildHeader('تقرير حالة الأبراج', now),
        footer: (_) => _buildFooter(),
        build: (ctx) => [
          _buildStatsRow([
            _Stat('إجمالي', '${towers.length}',
                _neon),
            _Stat('نشط',
                '${towers.where((t) => t.isOnline).length}',  _green),
            _Stat('تحذير',
                '${towers.where((t) => t.isWarning).length}', _orange),
            _Stat('معطل',
                '${towers.where((t) => t.isOffline).length}', _red),
          ]),
          pw.SizedBox(height: 20),
          _buildSectionTitle('تفاصيل الأبراج'),
          pw.SizedBox(height: 10),
          ...towers.map((t) => _buildTowerCard(t)),
        ],
      ),
    );

    return _savePdf(pdf, 'towers_report');
  }

  // ══════════════════════════════════════
  //  تقرير شامل (كل شيء)
  // ══════════════════════════════════════
  static Future<File> generateFullReport({
    required List<Subscriber> subscribers,
    required List<Payment> payments,
    required List<Tower> towers,
    required int monthlyRevenue,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final fmt = NumberFormat('#,###');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
        ),
        header: (_) => _buildHeader('التقرير الشهري الشامل', now),
        footer: (_) => _buildFooter(),
        build: (ctx) => [
          // ── لوحة الملخص الرئيسية ──
          _buildMainSummary(subscribers, payments, towers, monthlyRevenue),
          pw.SizedBox(height: 24),

          // ── المشتركون ──
          _buildSectionTitle('ملخص المشتركين'),
          pw.SizedBox(height: 10),
          _buildStatsRow([
            _Stat('الإجمالي', '${subscribers.length}', _neon),
            _Stat('نشط', '${subscribers.where((s) => s.status == "active").length}', _green),
            _Stat('ينتهي', '${subscribers.where((s) => s.isExpiringSoon).length}', _orange),
            _Stat('منقطع', '${subscribers.where((s) => s.status == "offline").length}', _red),
          ]),
          pw.SizedBox(height: 24),

          // ── الأبراج ──
          _buildSectionTitle('حالة الأبراج'),
          pw.SizedBox(height: 10),
          ...towers.map((t) => _buildTowerCard(t)),
          pw.SizedBox(height: 24),

          // ── الدفعات ──
          _buildSectionTitle('ملخص الدفعات'),
          pw.SizedBox(height: 10),
          _buildStatsRow([
            _Stat('هذا الشهر', '${fmt.format(monthlyRevenue)} IQD', _neon),
            _Stat('الإجمالي',  '${fmt.format(payments.fold(0, (s, p) => s + p.amount))} IQD', _green),
          ]),
          pw.SizedBox(height: 12),
          _buildTable(
            headers: ['المشترك', 'المبلغ', 'الطريقة', 'التاريخ'],
            widths:  [3.0, 2.0, 2.0, 2.0],
            rows: payments.take(20).map((p) => [
              p.subscriberName,
              '${fmt.format(p.amount)} IQD',
              p.methodArabic,
              DateFormat('dd/MM/yyyy').format(p.paidAt),
            ]).toList(),
          ),
        ],
      ),
    );

    return _savePdf(pdf, 'full_report_${DateFormat('yyyy_MM').format(now)}');
  }

  // ──────────────────────────────────────
  //  Widgets مساعدة
  // ──────────────────────────────────────

  static pw.Widget _buildHeader(String title, DateTime date) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: _neon, width: 1.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('SignalX',
                  style: pw.TextStyle(
                      font: pw.Font.helveticaBold(),
                      fontSize: 20,
                      color: _neon)),
              pw.Text('إدارة أبراج الإنترنت',
                  style: const pw.TextStyle(fontSize: 10, color: _grey)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(title,
                  style: pw.TextStyle(
                      font: pw.Font.helveticaBold(),
                      fontSize: 14,
                      color: _white)),
              pw.Text(
                DateFormat('dd/MM/yyyy — HH:mm').format(date),
                style: const pw.TextStyle(fontSize: 10, color: _grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
            top: pw.BorderSide(color: _border, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('SignalX — تقرير سري',
              style: const pw.TextStyle(fontSize: 8, color: _grey)),
          pw.Text('صُنع بـ SignalX App',
              style: const pw.TextStyle(fontSize: 8, color: _grey)),
        ],
      ),
    );
  }

  static pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: _surface,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: _neon, width: 0.5),
      ),
      child: pw.Text(title,
          style: pw.TextStyle(
              font: pw.Font.helveticaBold(),
              fontSize: 12, color: _neon)),
    );
  }

  static pw.Widget _buildStatsRow(List<_Stat> stats) {
    return pw.Row(
      children: stats.map((s) => pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.symmetric(horizontal: 4),
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: _surface,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: _border, width: 0.5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(s.value,
                  style: pw.TextStyle(
                      font: pw.Font.helveticaBold(),
                      fontSize: 14, color: s.color)),
              pw.SizedBox(height: 2),
              pw.Text(s.label,
                  style: const pw.TextStyle(fontSize: 9, color: _grey)),
            ],
          ),
        ),
      )).toList(),
    );
  }

  static pw.Widget _buildTable({
    required List<String> headers,
    required List<double> widths,
    required List<List<String>> rows,
    int? statusCol,
  }) {
    return pw.Table(
      columnWidths: {
        for (int i = 0; i < widths.length; i++)
          i: pw.FlexColumnWidth(widths[i]),
      },
      border: pw.TableBorder.all(color: _border, width: 0.5),
      children: [
        // رأس الجدول
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _surface),
          children: headers.map((h) => pw.Padding(
            padding: const pw.EdgeInsets.all(7),
            child: pw.Text(h,
                style: pw.TextStyle(
                    font: pw.Font.helveticaBold(),
                    fontSize: 10, color: _neon)),
          )).toList(),
        ),
        // صفوف البيانات
        ...rows.asMap().entries.map((entry) {
          final i   = entry.key;
          final row = entry.value;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: i.isEven
                  ? const PdfColor.fromInt(0xFF0A0E1A)
                  : const PdfColor.fromInt(0xFF0D1220),
            ),
            children: row.asMap().entries.map((cell) {
              PdfColor cellColor = _white;
              if (statusCol != null && cell.key == statusCol) {
                if (cell.value == 'نشط')    cellColor = _green;
                if (cell.value == 'منقطع')  cellColor = _red;
                if (cell.value == 'منتهي')  cellColor = _orange;
              }
              return pw.Padding(
                padding: const pw.EdgeInsets.all(7),
                child: pw.Text(cell.value,
                    style: pw.TextStyle(fontSize: 9, color: cellColor)),
              );
            }).toList(),
          );
        }),
      ],
    );
  }

  static pw.Widget _buildTowerCard(Tower tower) {
    final color = tower.isOnline ? _green : tower.isWarning ? _orange : _red;
    final status = tower.isOnline ? 'نشط' : tower.isWarning ? 'تحذير' : 'معطل';

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _surface,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _border, width: 0.5),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 8, height: 8,
            decoration: pw.BoxDecoration(color: color, shape: pw.BoxShape.circle),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(tower.name,
                    style: pw.TextStyle(
                        font: pw.Font.helveticaBold(),
                        fontSize: 11, color: _white)),
                pw.Text(tower.location,
                    style: const pw.TextStyle(fontSize: 9, color: _grey)),
              ],
            ),
          ),
          pw.Text(status,
              style: pw.TextStyle(
                  font: pw.Font.helveticaBold(),
                  fontSize: 10, color: color)),
          pw.SizedBox(width: 16),
          pw.Text('${tower.subscriberCount} مشترك',
              style: const pw.TextStyle(fontSize: 10, color: _grey)),
          pw.SizedBox(width: 16),
          pw.Text('إشارة: ${tower.signalStrength}%',
              style: pw.TextStyle(fontSize: 10, color: color)),
        ],
      ),
    );
  }

  static pw.Widget _buildMainSummary(
      List<Subscriber> subs, List<Payment> pays,
      List<Tower> towers, int revenue) {
    final fmt = NumberFormat('#,###');
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: _surface,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: _neon, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('ملخص شهر ${DateFormat('MMMM yyyy').format(DateTime.now())}',
              style: pw.TextStyle(
                  font: pw.Font.helveticaBold(),
                  fontSize: 13, color: _neon)),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _summaryItem('المشتركون', '${subs.length}'),
              _summaryItem('الأبراج النشطة',
                  '${towers.where((t) => t.isOnline).length}/${towers.length}'),
              _summaryItem('الدفعات', '${pays.length}'),
              _summaryItem('الإيرادات', '${fmt.format(revenue)} IQD'),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _summaryItem(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(value,
            style: pw.TextStyle(
                font: pw.Font.helveticaBold(),
                fontSize: 16, color: _white)),
        pw.Text(label,
            style: const pw.TextStyle(fontSize: 9, color: _grey)),
      ],
    );
  }

  // ══════════════════════════════════════
  //  حفظ ومشاركة الـ PDF
  // ══════════════════════════════════════
  static Future<File> _savePdf(pw.Document pdf, String name) async {
    final dir    = await getApplicationDocumentsDirectory();
    final path   = '${dir.path}/$name.pdf';
    final file   = File(path);
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static Future<void> sharePdf(File file, String subject) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: subject,
    );
  }
}

class _Stat {
  final String label, value;
  final PdfColor color;
  const _Stat(this.label, this.value, this.color);
}
