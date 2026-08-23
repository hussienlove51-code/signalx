class Payment {
  final String id;
  final String subscriberId;
  final String subscriberName;
  final int amount;
  final String method; // cash | app | zain_cash
  final DateTime paidAt;

  Payment({
    required this.id,
    required this.subscriberId,
    required this.subscriberName,
    required this.amount,
    required this.method,
    required this.paidAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
    id:             json['id'],
    subscriberId:   json['subscriber_id'],
    subscriberName: json['subscriber_name'] ?? '',
    amount:         json['amount'],
    method:         json['method'],
    paidAt:         DateTime.parse(json['paid_at']),
  );

  Map<String, dynamic> toJson() => {
    'id':              id,
    'subscriber_id':   subscriberId,
    'amount':          amount,
    'method':          method,
    'paid_at':         paidAt.toIso8601String(),
  };

  String get methodArabic {
    switch (method) {
      case 'cash':      return 'نقداً';
      case 'app':       return 'عبر التطبيق';
      case 'zain_cash': return 'زين كاش';
      default:          return method;
    }
  }
}
