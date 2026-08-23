import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/supabase_service.dart';
import '../models/payment.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});
  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  List<Payment> _payments = [];
  int _monthlyTotal = 0;
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final payments = await SupabaseService.getPayments();
    final total    = await SupabaseService.getMonthlyRevenue();
    setState(() {
      _payments = payments;
      _monthlyTotal = total;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الدفعات')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.neon))
          : Column(
              children: [
                _buildMonthlyCard(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _payments.length,
                    itemBuilder: (_, i) => _buildPaymentTile(_payments[i]),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMonthlyCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0066CC), Color(0xFF00D4FF)],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet_rounded,
              color: Colors.white, size: 28),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('إيرادات هذا الشهر',
                  style: TextStyle(color: Colors.white70,
                      fontSize: 12, fontFamily: 'Cairo')),
              Text(
                '${NumberFormat('#,###').format(_monthlyTotal)} د.ع',
                style: const TextStyle(color: Colors.white,
                    fontSize: 22, fontWeight: FontWeight.w700, fontFamily: 'Cairo'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentTile(Payment p) {
    Color methodColor;
    IconData methodIcon;
    switch (p.method) {
      case 'cash':      methodColor = AppColors.green;  methodIcon = Icons.payments_rounded; break;
      case 'app':       methodColor = AppColors.neon;   methodIcon = Icons.phone_android_rounded; break;
      case 'zain_cash': methodColor = AppColors.orange; methodIcon = Icons.account_balance_wallet_rounded; break;
      default:          methodColor = AppColors.textMuted; methodIcon = Icons.payment;
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
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: methodColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(methodIcon, color: methodColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.subscriberName,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary, fontFamily: 'Cairo')),
                Text(p.methodArabic,
                    style: const TextStyle(fontSize: 11,
                        color: AppColors.textMuted, fontFamily: 'Cairo')),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${NumberFormat('#,###').format(p.amount)} د.ع',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                      color: AppColors.green, fontFamily: 'Cairo')),
              Text(
                DateFormat('dd/MM/yyyy').format(p.paidAt),
                style: const TextStyle(fontSize: 10,
                    color: AppColors.textMuted, fontFamily: 'Cairo'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
