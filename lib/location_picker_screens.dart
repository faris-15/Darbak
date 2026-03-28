import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'app_theme.dart'; // تأكد من وجود الثيم الخاص بكم
import 'app_widgets.dart';

class MapLocationPickerScreen extends StatefulWidget {
  final String title;
  final Color themeColor;
  final LatLng initialLocation;

  const MapLocationPickerScreen({
    super.key,
    required this.title,
    required this.themeColor,
    required this.initialLocation,
  });

  @override
  State<MapLocationPickerScreen> createState() => _MapLocationPickerScreenState();
}

class _MapLocationPickerScreenState extends State<MapLocationPickerScreen> {
  final MapController _mapController = MapController();
  late LatLng _selectedLocation;
  bool _isMoving = false;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl, // لضمان اللغة العربية
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          backgroundColor: widget.themeColor,
          elevation: 0,
        ),
        body: Stack(
          children: [
            // 1. الخريطة المفتوحة المصدر (OpenStreetMap)
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: widget.initialLocation,
                initialZoom: 15.0,
                maxZoom: 18.0,
                minZoom: 5.0,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                // تحديث الإحداثيات عند تحريك الخريطة
                onPositionChanged: (MapPosition position, bool hasGesture) {
                  if (hasGesture && position.center != null) {
                    setState(() {
                      _isMoving = true;
                      _selectedLocation = position.center!;
                    });
                  }
                },
                onMapReady: () {
                  setState(() {
                    _selectedLocation = _mapController.camera.center;
                  });
                },
              ),
              children: [
                // طبقة بيانات OpenStreetMap (مجانية ومفتوحة المصدر)
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.darbak', // ضع الـ Package Name الحقيقي هنا
                ),
              ],
            ),

            // 2. مؤشر الاختيار (Marker) الثابت في المنتصف
            Center(
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 150),
                padding: EdgeInsets.only(bottom: _isMoving ? 40.0 : 20.0),
                child: Icon(
                  Icons.location_on_sharp,
                  size: 50,
                  color: widget.themeColor,
                ),
              ),
            ),

            // 3. زر التأكيد ( Floating Confirmation Button)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: DarbakPrimaryButton( // استخدم الويدجت الجاهزة لديكم
                label: 'تأكيد الموقع الحالي',
                icon: Icons.check_circle_outline,
                onPressed: () {
                  // إعادة الإحداثيات الحقيقية للشاشة السابقة
                  Navigator.pop(context, {
                    'lat': _selectedLocation.latitude,
                    'lng': _selectedLocation.longitude,
                    'mapsUrl': 'https://www.google.com/maps?q=${_selectedLocation.latitude},${_selectedLocation.longitude}',
                  });
                },
              ),
            ),

            // 4. مؤشر إحداثيات (اختياري - لمسة احترافية للجنة)
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white70,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  "${_selectedLocation.latitude.toStringAsFixed(6)}, ${_selectedLocation.longitude.toStringAsFixed(6)}",
                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PickupLocationPickerScreen extends StatelessWidget {
  const PickupLocationPickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MapLocationPickerScreen(
      title: 'اختيار موقع الاستلام',
      themeColor: DarbakColors.primaryGreen,
      initialLocation: const LatLng(24.7136, 46.6753), // Riyadh coordinates
    );
  }
}

class DropoffLocationPickerScreen extends StatelessWidget {
  const DropoffLocationPickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MapLocationPickerScreen(
      title: 'اختيار موقع التسليم',
      themeColor: DarbakColors.primaryGreen,
      initialLocation: const LatLng(24.7136, 46.6753), // Riyadh coordinates
    );
  }
}