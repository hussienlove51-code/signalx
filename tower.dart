class Tower {
  final String id;
  final String name;
  final String location;
  final int signalStrength; // 0-100
  final String status;      // online | warning | offline
  final double temperature;
  final int subscriberCount;
  final double currentBandwidth; // بالميغابايت

  Tower({
    required this.id,
    required this.name,
    required this.location,
    required this.signalStrength,
    required this.status,
    required this.temperature,
    required this.subscriberCount,
    required this.currentBandwidth,
  });

  factory Tower.fromJson(Map<String, dynamic> json) => Tower(
    id:               json['id'],
    name:             json['name'],
    location:         json['location'],
    signalStrength:   json['signal_strength'] ?? 0,
    status:           json['status'],
    temperature:      (json['temperature'] ?? 0.0).toDouble(),
    subscriberCount:  json['subscriber_count'] ?? 0,
    currentBandwidth: (json['current_bandwidth'] ?? 0.0).toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'id':                id,
    'name':              name,
    'location':          location,
    'signal_strength':   signalStrength,
    'status':            status,
    'temperature':       temperature,
    'subscriber_count':  subscriberCount,
    'current_bandwidth': currentBandwidth,
  };

  bool get isOnline  => status == 'online';
  bool get isWarning => status == 'warning';
  bool get isOffline => status == 'offline';
}
