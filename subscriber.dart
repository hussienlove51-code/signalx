class Subscriber {
  final String  id;
  final String  name;
  final String  phone;
  final String  area;
  final String  towerId;
  final String  packageId;
  final DateTime expiresAt;
  final String  status; // active | expiring | offline
  final String? sas4Username; // مربوط بـ SAS4 username

  Subscriber({
    required this.id,
    required this.name,
    required this.phone,
    required this.area,
    required this.towerId,
    required this.packageId,
    required this.expiresAt,
    required this.status,
    this.sas4Username,
  });

  factory Subscriber.fromJson(Map<String, dynamic> json) => Subscriber(
    id:           json['id'] as String,
    name:         json['name'] as String,
    phone:        (json['phone'] as String?) ?? '',
    area:         (json['area'] as String?) ?? '',
    towerId:      (json['tower_id'] as String?) ?? '',
    packageId:    (json['package_id'] as String?) ?? '',
    expiresAt:    DateTime.parse(json['expires_at'] as String),
    status:       (json['status'] as String?) ?? 'active',
    sas4Username: json['sas4_username'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id':            id,
    'name':          name,
    'phone':         phone,
    'area':          area,
    'tower_id':      towerId,
    'package_id':    packageId,
    'expires_at':    expiresAt.toIso8601String(),
    'status':        status,
    if (sas4Username != null) 'sas4_username': sas4Username,
  };

  bool get isExpiringSoon {
    final diff = expiresAt.difference(DateTime.now()).inDays;
    return diff <= 7 && diff >= 0;
  }

  bool get isExpired => expiresAt.isBefore(DateTime.now());

  // نسخة معدّلة بحقل واحد
  Subscriber copyWith({
    String?   id,
    String?   name,
    String?   phone,
    String?   area,
    String?   towerId,
    String?   packageId,
    DateTime? expiresAt,
    String?   status,
    String?   sas4Username,
  }) => Subscriber(
    id:           id           ?? this.id,
    name:         name         ?? this.name,
    phone:        phone        ?? this.phone,
    area:         area         ?? this.area,
    towerId:      towerId      ?? this.towerId,
    packageId:    packageId    ?? this.packageId,
    expiresAt:    expiresAt    ?? this.expiresAt,
    status:       status       ?? this.status,
    sas4Username: sas4Username ?? this.sas4Username,
  );
}
