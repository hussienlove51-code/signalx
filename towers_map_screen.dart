import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';
import '../services/supabase_service.dart';
import '../models/tower.dart';
import '../models/subscriber.dart';

class TowersMapScreen extends StatefulWidget {
  const TowersMapScreen({super.key});
  @override
  State<TowersMapScreen> createState() => _TowersMapScreenState();
}

class _TowersMapScreenState extends State<TowersMapScreen> {
  GoogleMapController? _mapCtrl;
  List<Tower>      _towers      = [];
  List<Subscriber> _subscribers = [];
  Tower?           _selected;
  bool             _isLoading   = true;
  Set<Marker>      _markers     = {};
  Position?        _myPosition;

  // موقع ديالى الخالص تقريباً
  static const _defaultPos = LatLng(33.8436, 44.5393);

  @override
  void initState() {
    super.initState();
    _loadData();
    _getMyLocation();
  }

  Future<void> _loadData() async {
    final towers = await SupabaseService.getTowers();
    final subs   = await SupabaseService.getSubscribers();
    setState(() {
      _towers      = towers;
      _subscribers = subs;
      _isLoading   = false;
    });
    _buildMarkers();
  }

  Future<void> _getMyLocation() async {
    try {
      final perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) return;
      final pos = await Geolocator.getCurrentPosition();
      setState(() => _myPosition = pos);
    } catch (_) {}
  }

  void _buildMarkers() {
    final markers = <Marker>{};

    for (final tower in _towers) {
      // في الواقع ستجيب الإحداثيات من Supabase
      // هنا نضع إحداثيات تقريبية حول ديالى
      final lat = _defaultPos.latitude  + (_towers.indexOf(tower) * 0.01);
      final lng = _defaultPos.longitude + (_towers.indexOf(tower) * 0.008);

      final color = tower.isOnline
          ? BitmapDescriptor.hueAzure
          : tower.isWarning
              ? BitmapDescriptor.hueOrange
              : BitmapDescriptor.hueRed;

      markers.add(Marker(
        markerId: MarkerId(tower.id),
        position: LatLng(lat, lng),
        icon:     BitmapDescriptor.defaultMarkerWithHue(color),
        infoWindow: InfoWindow(
          title:   tower.name,
          snippet: '${tower.subscriberCount} مشترك — ${tower.signalStrength}%',
        ),
        onTap: () => setState(() => _selected = tower),
      ));
    }

    // موقعي الحالي
    if (_myPosition != null) {
      markers.add(Marker(
        markerId: const MarkerId('my_location'),
        position: LatLng(_myPosition!.latitude, _myPosition!.longitude),
        icon:     BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'موقعي'),
      ));
    }

    setState(() => _markers = markers);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('خريطة الأبراج'),
        actions: [
          // فلتر الحالة
          PopupMenuButton<String>(
            color: AppColors.surface,
            icon: const Icon(Icons.filter_list_rounded,
                color: AppColors.neon),
            onSelected: _filterTowers,
            itemBuilder: (_) => [
              _filterItem('all',     'الكل'),
              _filterItem('online',  'نشط فقط'),
              _filterItem('warning', 'تحذير فقط'),
              _filterItem('offline', 'معطل فقط'),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.neon))
          : Stack(
              children: [
                // ─── الخريطة ───
                GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: _defaultPos,
                    zoom:   12,
                  ),
                  markers:              _markers,
                  onMapCreated: (ctrl) => _mapCtrl = ctrl,
                  myLocationEnabled:    true,
                  myLocationButtonEnabled: false,
                  mapType:              MapType.normal,
                  style:               _darkMapStyle,
                ),

                // ─── بطاقات الأبراج في الأسفل ───
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ملخص أعلى البطاقات
                      if (_selected == null) _buildSummaryBar(),

                      // بطاقة البرج المحدد
                      if (_selected != null)
                        _buildTowerDetailCard(_selected!)
                      else
                        _buildTowersList(),
                    ],
                  ),
                ),

                // ─── زر موقعي ───
                Positioned(
                  top: 16, left: 16,
                  child: _mapButton(
                    icon: Icons.my_location_rounded,
                    onTap: _goToMyLocation,
                  ),
                ),

                // ─── زر إغلاق البطاقة ───
                if (_selected != null)
                  Positioned(
                    top: 16, right: 16,
                    child: _mapButton(
                      icon: Icons.close_rounded,
                      onTap: () => setState(() => _selected = null),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildSummaryBar() {
    final online  = _towers.where((t) => t.isOnline).length;
    final warning = _towers.where((t) => t.isWarning).length;
    final offline = _towers.where((t) => t.isOffline).length;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryItem('$online',  'نشط',    AppColors.neon),
          _vDivider(),
          _summaryItem('$warning', 'تحذير',  AppColors.orange),
          _vDivider(),
          _summaryItem('$offline', 'معطل',   AppColors.red),
          _vDivider(),
          _summaryItem('${_subscribers.length}', 'مشترك', AppColors.purple),
        ],
      ),
    );
  }

  Widget _summaryItem(String val, String lbl, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(val, style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w700,
            color: color, fontFamily: 'Cairo')),
        Text(lbl, style: const TextStyle(
            fontSize: 10, color: AppColors.textMuted, fontFamily: 'Cairo')),
      ],
    );
  }

  Widget _vDivider() => Container(
      height: 30, width: 0.5, color: AppColors.border);

  Widget _buildTowersList() {
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        itemCount: _towers.length,
        itemBuilder: (_, i) => _towerMiniCard(_towers[i]),
      ),
    );
  }

  Widget _towerMiniCard(Tower t) {
    final color = t.isOnline ? AppColors.neon
        : t.isWarning ? AppColors.orange : AppColors.red;
    return GestureDetector(
      onTap: () {
        setState(() => _selected = t);
        _flyToTower(t);
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4), width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(width: 8, height: 8,
                  decoration: BoxDecoration(
                      color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(t.name,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary, fontFamily: 'Cairo'),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
            const Spacer(),
            Text('${t.subscriberCount} مشترك',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textMuted,
                    fontFamily: 'Cairo')),
            const SizedBox(height: 2),
            LinearProgressIndicator(
              value:       t.signalStrength / 100,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight:  4,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTowerDetailCard(Tower t) {
    final color  = t.isOnline ? AppColors.neon
        : t.isWarning ? AppColors.orange : AppColors.red;
    final status = t.isOnline ? 'نشط' : t.isWarning ? 'تحذير' : 'معطل';
    final towSubs = _subscribers
        .where((s) => s.towerId == t.id).toList();

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.97),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // رأس البطاقة
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(Icons.cell_tower_rounded,
                      color: color, size: 22),
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
                          fontSize: 11, color: AppColors.textMuted,
                          fontFamily: 'Cairo')),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(status, style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: color, fontFamily: 'Cairo')),
                ),
              ],
            ),
          ),
          // إحصائيات
          Container(
            decoration: const BoxDecoration(
              border: Border(
                  top:    BorderSide(color: AppColors.border, width: 0.5),
                  bottom: BorderSide(color: AppColors.border, width: 0.5)),
            ),
            child: Row(children: [
              _detailStat('${t.subscriberCount}', 'مشترك',  AppColors.textPrimary),
              _detailStat('${t.signalStrength}%', 'إشارة',  color),
              _detailStat('${t.temperature.toInt()}°', 'حرارة',
                  t.temperature > 55 ? AppColors.orange : AppColors.textPrimary),
              _detailStat('${t.currentBandwidth.toInt()}mb', 'بث', AppColors.neon),
            ]),
          ),
          // مشتركو هذا البرج
          if (towSubs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('المشتركون (${towSubs.length})',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMuted,
                          fontFamily: 'Cairo')),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 36,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: towSubs.take(8).length,
                      itemBuilder: (_, i) {
                        final s = towSubs[i];
                        return Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppColors.border, width: 0.5),
                          ),
                          child: Text(s.name.split(' ').first,
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textSecondary,
                                  fontFamily: 'Cairo')),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _detailStat(String val, String lbl, Color color) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(children: [
          Text(val, style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700,
              color: color, fontFamily: 'Cairo')),
          Text(lbl, style: const TextStyle(
              fontSize: 10, color: AppColors.textMuted, fontFamily: 'Cairo')),
        ]),
      ),
    );
  }

  Widget _mapButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: AppColors.surface.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Icon(icon, color: AppColors.neon, size: 20),
      ),
    );
  }

  PopupMenuItem<String> _filterItem(String val, String label) {
    return PopupMenuItem(
      value: val,
      child: Text(label, style: const TextStyle(
          color: AppColors.textPrimary, fontFamily: 'Cairo')),
    );
  }

  void _filterTowers(String filter) {
    setState(() {
      _selected = null;
      if (filter == 'all') {
        _buildMarkers();
      } else {
        final filtered = _towers.where((t) => t.status == filter).toList();
        _buildMarkersForList(filtered);
      }
    });
  }

  void _buildMarkersForList(List<Tower> towers) {
    final markers = <Marker>{};
    for (final t in towers) {
      final lat = _defaultPos.latitude  + (towers.indexOf(t) * 0.01);
      final lng = _defaultPos.longitude + (towers.indexOf(t) * 0.008);
      markers.add(Marker(
        markerId: MarkerId(t.id),
        position: LatLng(lat, lng),
        icon:     BitmapDescriptor.defaultMarkerWithHue(
          t.isOnline  ? BitmapDescriptor.hueAzure
          : t.isWarning ? BitmapDescriptor.hueOrange
          : BitmapDescriptor.hueRed,
        ),
        infoWindow: InfoWindow(title: t.name),
        onTap: () => setState(() => _selected = t),
      ));
    }
    setState(() => _markers = markers);
  }

  void _flyToTower(Tower t) {
    final idx = _towers.indexOf(t);
    final lat = _defaultPos.latitude  + (idx * 0.01);
    final lng = _defaultPos.longitude + (idx * 0.008);
    _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(
        LatLng(lat, lng), 14));
  }

  void _goToMyLocation() {
    if (_myPosition != null) {
      _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(
          LatLng(_myPosition!.latitude, _myPosition!.longitude), 13));
    }
  }

  // ستايل الخريطة الداكنة
  static const _darkMapStyle = '''
[{"elementType":"geometry","stylers":[{"color":"#0a0e1a"}]},
{"elementType":"labels.text.fill","stylers":[{"color":"#8ab4d4"}]},
{"elementType":"labels.text.stroke","stylers":[{"color":"#0a0e1a"}]},
{"featureType":"road","elementType":"geometry","stylers":[{"color":"#1a2540"}]},
{"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#0d1220"}]},
{"featureType":"water","elementType":"geometry","stylers":[{"color":"#0d1220"}]},
{"featureType":"poi","stylers":[{"visibility":"off"}]}]
''';
}
