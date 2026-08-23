class Package {
  final String id;
  final String name;
  final int speedMbps;
  final int price;
  final int durationDays;

  Package({
    required this.id,
    required this.name,
    required this.speedMbps,
    required this.price,
    required this.durationDays,
  });

  factory Package.fromJson(Map<String, dynamic> json) => Package(
    id:           json['id'],
    name:         json['name'],
    speedMbps:    json['speed_mbps'],
    price:        json['price'],
    durationDays: json['duration_days'],
  );

  Map<String, dynamic> toJson() => {
    'id':            id,
    'name':          name,
    'speed_mbps':    speedMbps,
    'price':         price,
    'duration_days': durationDays,
  };

  String get displaySpeed => '$speedMbps Mbps';
  String get displayPrice => '${price.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  )} د.ع';
}
