// تسجيل خروج يمسح الجلسة المحلية ويُسجّل خروج Firebase حتى لا تبقى جلسة مزدوجة.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';
import 'app_widgets.dart';
import 'available_loads_screen.dart';
import 'trip_screens.dart';
import 'api_service.dart';
import 'contract/open_contract_pdf.dart';
import 'job_tracking_screen.dart';
import 'vehicle_management_screen.dart';
import 'ratings_screen.dart';
import 'services/profile_image_flow.dart';
import 'services/profile_repository.dart';
import 'widgets/profile_avatar.dart';
import 'widgets/sar_price.dart';
import 'utils/shipment_display.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  int _currentIndex = 0;
  int _activeJobsCount = 0;
  bool _isRefreshingBadge = false;
  Timer? _badgePollingTimer;
  final _appLifecycleObserver = _DriverLifecycleObserver();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_appLifecycleObserver);
    _appLifecycleObserver.onResume = _refreshActiveJobsBadge;
    _refreshActiveJobsBadge();
    _badgePollingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      _refreshActiveJobsBadge();
    });
  }

  Future<void> _refreshActiveJobsBadge() async {
    if (_isRefreshingBadge) return;
    _isRefreshingBadge = true;
    try {
      final shipments = await ApiService.getDriverActiveShipments();
      if (!mounted) return;
      setState(() {
        _activeJobsCount = shipments.length;
      });
    } catch (_) {
      // Keep previous badge state on intermittent errors.
    } finally {
      _isRefreshingBadge = false;
    }
  }

  @override
  void dispose() {
    _badgePollingTimer?.cancel();
    WidgetsBinding.instance.removeObserver(_appLifecycleObserver);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const AvailableLoadsScreen(), // سوق الشحنات - Professional UI
      DriverTripsScreen(
        onActiveJobsChanged: (count) {
          if (!mounted) return;
          setState(() {
            _activeJobsCount = count;
          });
        },
      ),
      const DriverMessagesScreen(), // الرسائل
      const DriverProfileScreen(), // الملف الشخصي
    ];

    final titles = ['سوق الشحنات', 'رحلاتي', 'الرسائل', 'حسابي'];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_currentIndex]),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: DarbakColors.primaryGreen,
        unselectedItemColor: DarbakColors.textSecondary,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping_outlined),
            activeIcon: Icon(Icons.local_shipping_rounded),
            label: 'السوق',
          ),
          BottomNavigationBarItem(
            icon: _TripsNavIcon(hasActiveJobs: _activeJobsCount > 0),
            activeIcon: Icon(Icons.route_rounded),
            label: 'رحلاتي',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            activeIcon: Icon(Icons.chat_bubble_rounded),
            label: 'الرسائل',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'حسابي',
          ),
        ],
      ),
    );
  }
}

// شاشات مؤقتة للتابات الأخرى (سنطوّرها في دفعات لاحقة)

class DriverTripsScreen extends StatefulWidget {
  final ValueChanged<int>? onActiveJobsChanged;

  const DriverTripsScreen({super.key, this.onActiveJobsChanged});

  @override
  State<DriverTripsScreen> createState() => _DriverTripsScreenState();
}

class _DriverTripsScreenState extends State<DriverTripsScreen> {
  static const Set<String> _activeStatuses = {
    'assigned',
    'at_pickup',
    'en_route',
    'at_dropoff',
  };

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _activeTrips = const [];
  List<Map<String, dynamic>> _historyTrips = const [];
  String _lastSignature = '';

  bool _isActiveStatus(String status) => _activeStatuses.contains(status);

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  String _buildSignature(
    List<Map<String, dynamic>> active,
    List<Map<String, dynamic>> history,
  ) {
    final parts = <String>[];
    for (final shipment in [...active, ...history]) {
      parts.add(
        '${shipment['id']}:${shipment['status']}:${shipment['updated_at'] ?? shipment['created_at'] ?? ''}',
      );
    }
    return parts.join('|');
  }

  Future<void> _loadTrips({bool forceLoadingState = false}) async {
    if (forceLoadingState && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final raw = await ApiService.getDriverShipments();
      final shipments = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final active = shipments
          .where((s) => _isActiveStatus((s['status'] ?? '').toString()))
          .toList();
      final history = shipments
          .where((s) => !_isActiveStatus((s['status'] ?? '').toString()))
          .toList();

      final nextSignature = _buildSignature(active, history);

      if (!mounted) return;

      final didChangeData = nextSignature != _lastSignature;
      if (didChangeData || _isLoading || _errorMessage != null) {
        setState(() {
          _activeTrips = active;
          _historyTrips = history;
          _isLoading = false;
          _errorMessage = null;
          _lastSignature = nextSignature;
        });
      } else if (_isLoading) {
        setState(() {
          _isLoading = false;
        });
      }

      widget.onActiveJobsChanged?.call(active.length);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'تعذر تحميل الرحلات.\n$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: DarbakColors.textSecondary),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _loadTrips(forceLoadingState: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
      );
    }

    if (_activeTrips.isEmpty && _historyTrips.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'لا توجد رحلات حالية',
                style: TextStyle(
                  fontSize: 16,
                  color: DarbakColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _loadTrips(forceLoadingState: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadTrips(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_activeTrips.isNotEmpty) ...[
            const Text(
              'الرحلات النشطة',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: DarbakColors.primaryGreen,
              ),
            ),
            const SizedBox(height: 10),
            ..._activeTrips.map(
              (shipment) => _ShipmentTripCard(
                shipment: shipment,
                isActive: true,
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => JobTrackingScreen(
                        shipmentId: shipment['id'] as int,
                        shipmentData: shipment,
                      ),
                    ),
                  );
                  await _loadTrips(forceLoadingState: true);
                },
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (_historyTrips.isNotEmpty) ...[
            const Text(
              'السجل السابق',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
            const SizedBox(height: 10),
            ..._historyTrips.map(
              (shipment) => _ShipmentTripCard(
                shipment: shipment,
                isActive: false,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ShipmentSummaryScreen(shipment: shipment),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TripsNavIcon extends StatelessWidget {
  final bool hasActiveJobs;

  const _TripsNavIcon({required this.hasActiveJobs});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.route_outlined),
        if (hasActiveJobs)
          Positioned(
            right: -1,
            top: -1,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: DarbakColors.primaryGreen,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}

({Color background, Color foreground, Color borderColor, IconData icon})
    _tripCardStatusTheme(String? statusRaw) {
  final s = statusRaw?.toString().trim() ?? '';
  switch (s) {
    case 'assigned':
      return (
        background: DarbakColors.primaryGreen.withValues(alpha: 0.16),
        foreground: DarbakColors.primaryDark,
        borderColor: DarbakColors.primaryGreen,
        icon: Icons.assignment_turned_in_rounded,
      );
    case 'at_pickup':
      return (
        background: const Color(0xFFE3F2FD),
        foreground: const Color(0xFF0D47A1),
        borderColor: const Color(0xFF1976D2),
        icon: Icons.upload_rounded,
      );
    case 'en_route':
      return (
        background: const Color(0xFFFFF8E1),
        foreground: const Color(0xFFE65100),
        borderColor: DarbakColors.orange,
        icon: Icons.route_rounded,
      );
    case 'at_dropoff':
      return (
        background: const Color(0xFFFFF3E0),
        foreground: const Color(0xFFE65100),
        borderColor: const Color(0xFFFB8C00),
        icon: Icons.place_rounded,
      );
    case 'delivered':
      return (
        background: const Color(0xFFE8F5E9),
        foreground: const Color(0xFF1B5E20),
        borderColor: DarbakColors.successGreen,
        icon: Icons.check_circle_rounded,
      );
    case 'cancelled':
      return (
        background: const Color(0xFFFFEBEE),
        foreground: const Color(0xFFB71C1C),
        borderColor: DarbakColors.danger,
        icon: Icons.cancel_rounded,
      );
    case 'pending':
    case 'bidding':
      return (
        background: const Color(0xFFF3E5F5),
        foreground: const Color(0xFF4A148C),
        borderColor: const Color(0xFF8E24AA),
        icon: Icons.hourglass_top_rounded,
      );
    default:
      return (
        background: DarbakColors.cardBackground,
        foreground: DarbakColors.dark,
        borderColor: DarbakColors.border,
        icon: Icons.info_outline_rounded,
      );
  }
}

class _TripStatusBanner extends StatelessWidget {
  final Map<String, dynamic> shipment;
  final String heading;

  const _TripStatusBanner({
    required this.shipment,
    this.heading = 'حالة الرحلة',
  });

  @override
  Widget build(BuildContext context) {
    final st = shipment['status']?.toString();
    final t = _tripCardStatusTheme(st);
    final text = shipmentLifecycleStatusAr(st);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: t.borderColor.withValues(alpha: 0.55),
          width: 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(t.icon, size: 22, color: t.foreground),
              const SizedBox(width: 8),
              Text(
                heading,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: t.foreground.withValues(alpha: 0.88),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              height: 1.3,
              color: t.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _TripLocationMiniRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _TripLocationMiniRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: DarbakColors.textSecondary,
                ),
              ),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: DarbakColors.text,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TripPickupDropoffBlock extends StatelessWidget {
  final Map<String, dynamic> shipment;
  final bool isActive;

  const _TripPickupDropoffBlock({
    required this.shipment,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final accent =
        isActive ? DarbakColors.primaryGreen : Colors.blueGrey.shade700;
    final pickup = shipmentAddressPrimaryLine(
      shipment['pickup_address']?.toString(),
    );
    final drop = shipmentAddressPrimaryLine(
      shipment['dropoff_address']?.toString(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TripLocationMiniRow(
          icon: Icons.store_mall_directory_outlined,
          iconColor: const Color(0xFF1565C0),
          label: kShipmentPickupLocationLabelAr,
          value: pickup,
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 9, top: 2, bottom: 2),
          child: Container(
            width: 2,
            height: 12,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        _TripLocationMiniRow(
          icon: Icons.flag_circle_outlined,
          iconColor: accent,
          label: kShipmentDropoffLocationLabelAr,
          value: drop,
        ),
      ],
    );
  }
}

class _TripCompanyHighlight extends StatelessWidget {
  final Map<String, dynamic> shipment;
  final bool isActive;

  const _TripCompanyHighlight({
    required this.shipment,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isActive ? DarbakColors.primaryGreen : Colors.blueGrey;
    final name = shipmentShipperDisplayName(shipment);
    final hasName = name.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.apartment_rounded,
          size: 22,
          color: hasName ? accent : DarbakColors.textSecondary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'الشركة',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: DarbakColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hasName ? name : 'غير متوفرة',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: hasName
                      ? (isActive
                            ? DarbakColors.primaryGreen
                            : DarbakColors.dark)
                      : DarbakColors.textSecondary,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ShipmentTripCard extends StatelessWidget {
  final Map<String, dynamic> shipment;
  final bool isActive;
  final VoidCallback onTap;

  const _ShipmentTripCard({
    required this.shipment,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isActive ? DarbakColors.primaryGreen : Colors.blueGrey;
    final cardBg = isActive
        ? DarbakColors.primaryGreen.withValues(alpha: 0.08)
        : Colors.blueGrey.withValues(alpha: 0.08);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: borderColor, width: 1.4),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    isActive
                        ? Icons.local_shipping_rounded
                        : Icons.receipt_long_rounded,
                    size: 26,
                    color: borderColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TripStatusBanner(shipment: shipment),
                      const SizedBox(height: 10),
                      _TripPickupDropoffBlock(
                        shipment: shipment,
                        isActive: isActive,
                      ),
                      const SizedBox(height: 10),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: DarbakColors.border.withValues(alpha: 0.65),
                      ),
                      const SizedBox(height: 8),
                      _TripCompanyHighlight(
                        shipment: shipment,
                        isActive: isActive,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 15,
                    color: borderColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ShipmentSummaryScreen extends StatefulWidget {
  final Map<String, dynamic> shipment;

  const ShipmentSummaryScreen({super.key, required this.shipment});

  @override
  State<ShipmentSummaryScreen> createState() => _ShipmentSummaryScreenState();
}

DateTime? _parseShipmentDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}

double? _shipmentDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

/// Active shipments: grace 5 days after [final_delivery_date] or [expected_delivery_date], then +5%/day capped at 25%.
Map<String, dynamic>? _latePenaltyBannerInfo(Map<String, dynamic> s) {
  final st = (s['status'] ?? '').toString();
  if (st == 'delivered' || st == 'cancelled') return null;
  final deadline = _parseShipmentDate(s['final_delivery_date']) ??
      _parseShipmentDate(s['expected_delivery_date']);
  if (deadline == null) return null;
  final bid = _shipmentDouble(s['accepted_bid_amount']) ??
      _shipmentDouble(s['suggested_price']) ??
      _shipmentDouble(s['base_price']);
  if (bid == null || bid <= 0) return null;

  final serverPct = (s['late_penalty_percent'] as num?)?.toInt();
  final serverAmt = _shipmentDouble(s['late_penalty_amount']);
  int pct;
  double amt;
  if (serverPct != null && serverPct > 0 && serverAmt != null && serverAmt > 0) {
    pct = serverPct.clamp(0, 25).toInt();
    amt = serverAmt;
  } else {
    final now = DateTime.now();
    final d0 = DateTime(deadline.year, deadline.month, deadline.day);
    final d1 = DateTime(now.year, now.month, now.day);
    final daysSince = d1.difference(d0).inDays;
    if (daysSince <= 5) return null;
    final tier = daysSince - 5;
    pct = (tier * 5).clamp(0, 25).toInt();
    amt = double.parse((bid * pct / 100).toStringAsFixed(2));
  }
  if (pct <= 0 || amt <= 0) return null;
  return {'percent': pct, 'amount': amt};
}

class _ShipmentSummaryScreenState extends State<ShipmentSummaryScreen> {
  Map<String, dynamic>? _full;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final id = (widget.shipment['id'] as num?)?.toInt();
      if (id == null) return;
      final s = await ApiService.getShipment(id);
      if (!mounted) return;
      setState(() => _full = s);
    } catch (_) {}
  }

  Future<void> _openContract() async {
    final id = (widget.shipment['id'] as num?)?.toInt();
    if (id == null) return;
    await openShipmentContractPdfInApp(context, id);
  }

  Future<void> _openRate() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getInt('user_id');
    final role = prefs.getString('user_role');
    final s = _full ?? widget.shipment;
    final sid = (s['shipper_id'] as num?)?.toInt();
    final did = (s['driver_id'] as num?)?.toInt();
    final shipId = (s['id'] as num?)?.toInt();
    if (uid == null ||
        role == null ||
        sid == null ||
        did == null ||
        shipId == null) {
      return;
    }
    final otherId = role == 'driver' ? sid : did;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RatingsScreen(
          shipmentId: shipId,
          otherUserId: otherId,
          otherUserRole: role == 'driver' ? 'shipper' : 'driver',
          otherUserName: role == 'driver' ? 'الشاحن' : 'السائق',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shipment = _full ?? widget.shipment;
    final delivered = (shipment['status'] ?? '').toString() == 'delivered';
    final contractKey = (shipment['contract_pdf_key'] ?? '').toString().trim();
    final st = (shipment['status'] ?? '').toString();
    final latePenalty = _latePenaltyBannerInfo(shipment);
    final canShowContract =
        contractKey.isNotEmpty &&
        const {
          'assigned',
          'at_pickup',
          'en_route',
          'at_dropoff',
          'delivered',
        }.contains(st);

    return Scaffold(
      appBar: AppBar(title: const Text('ملخص الرحلة')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (latePenalty != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Material(
                color: Colors.deepOrange.shade50,
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.deepOrange.shade300, width: 1.2),
                  ),
                  leading: Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.deepOrange.shade800,
                    size: 32,
                  ),
                  title: Text(
                    'تنبيه: لقد تجاوزت مهلة التوصيل (5 أيام). تم تطبيق جزاء تأخير بنسبة ${latePenalty['percent']}% وسيتم خصم ${(latePenalty['amount'] as double).toStringAsFixed(2)} ريال من مستحقاتك. تزداد العقوبة 5% يومياً.',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Colors.deepOrange.shade900,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            ),
          if (canShowContract)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OutlinedButton.icon(
                onPressed: _openContract,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('العقد الإلكتروني'),
              ),
            ),
          if (delivered)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ElevatedButton.icon(
                onPressed: _openRate,
                icon: const Icon(Icons.star_rate_rounded),
                label: const Text('تقييم الطرف الآخر'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DarbakColors.primaryGreen,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          Card(
            color: Colors.blueGrey.withValues(alpha: 0.08),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.blueGrey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TripStatusBanner(
                    shipment: shipment,
                    heading: 'الحالة النهائية',
                  ),
                  const SizedBox(height: 10),
                  _TripPickupDropoffBlock(
                    shipment: shipment,
                    isActive: false,
                  ),
                  const SizedBox(height: 10),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: DarbakColors.border.withValues(alpha: 0.65),
                  ),
                  const SizedBox(height: 8),
                  _TripCompanyHighlight(
                    shipment: shipment,
                    isActive: false,
                  ),
                  const SizedBox(height: 8),
                  Text('من: ${shipment['pickup_address'] ?? '-'}'),
                  Text('إلى: ${shipment['dropoff_address'] ?? '-'}'),
                  Text('الوزن: ${shipment['weight_kg'] ?? '-'} كجم'),
                  Row(
                    children: [
                      const Text('السعر المتفق عليه: '),
                      SarPrice(
                        amount: shipmentAgreedPriceValue(shipment),
                        style: const TextStyle(fontSize: 14),
                        iconSize: 14,
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('السعر النهائي: '),
                      SarPrice(
                        amount: shipment['final_price'],
                        style: const TextStyle(fontSize: 14),
                        iconSize: 14,
                      ),
                    ],
                  ),
                  Text('تاريخ الإنشاء: ${formatShipmentDateTimeForUi(shipment['created_at'])}'),
                  Text(
                    'تاريخ التسليم: ${shipment['actual_delivery_date'] != null ? formatShipmentDateTimeForUi(shipment['actual_delivery_date']) : 'غير متوفر'}',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverLifecycleObserver with WidgetsBindingObserver {
  VoidCallback? onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResume?.call();
    }
  }
}

class DriverMessagesScreen extends StatefulWidget {
  const DriverMessagesScreen({super.key});

  @override
  State<DriverMessagesScreen> createState() => _DriverMessagesScreenState();
}

class _DriverMessagesScreenState extends State<DriverMessagesScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await ApiService.getMyChatConversations();
      final rows = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
      await ProfileRepository.preloadProfileImagesFromRows(
        rows,
        urlField: 'other_party_profile_image_url',
        keyField: 'other_party_profile_image_key',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }
    if (_rows.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد محادثات بعد',
          style: TextStyle(color: DarbakColors.textSecondary),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _rows.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final r = _rows[i];
          final sid = _intFromRowValue(r['shipment_id']);
          final otherUserId = _intFromRowValue(r['other_party_id']);
          final name = (r['other_party_name'] ?? 'محادثة').toString();
          final imageUrl = r['other_party_profile_image_url']?.toString();
          final imageKey = r['other_party_profile_image_key']?.toString();
          final role = r['other_party_role']?.toString() ?? 'shipper';
          final last = (r['last_preview'] ?? r['last_message'] ?? '')
              .toString();
          final unreadCount = _intFromRowValue(r['unread_count']) ?? 0;
          return _ConversationTile(
            avatar: ProfileAvatar(
              imageUrl: imageUrl,
              imageKey: imageKey,
              role: role,
              radius: 22,
            ),
            title: name,
            subtitle: last,
            trailing: unreadCount > 0
                ? _UnreadBadge(count: unreadCount)
                : const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            onTap: () async {
              if (sid == null) return;
              await ProfileRepository.preloadProfileImage(
                imageUrl: imageUrl,
                imageKey: imageKey,
              );
              if (!context.mounted) return;
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    shipmentId: sid.toString(),
                    otherUser: name,
                    otherUserId: otherUserId,
                    otherUserProfileImageUrl: imageUrl,
                    otherUserProfileImageKey: imageKey,
                    otherUserRole: role,
                  ),
                ),
              );
              if (mounted) unawaited(_load());
            },
          );
        },
      ),
    );
  }
}

int? _intFromRowValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.avatar,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  final Widget avatar;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            avatar,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: DarbakColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(width: 40, child: Center(child: trailing)),
          ],
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _operatingCard;
  bool _isLoading = true;
  bool _isLoadingCard = true;
  bool _isEditing = false;
  bool _isUploadingProfileImage = false;
  bool _isUploadingCard = false;
  double? _profileImageUploadProgress;
  double _cardUploadProgress = 0;
  String? _cardError;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _licenseController;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _licenseController = TextEditingController();
    _loadProfile();
    _loadOperatingCard();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لم يتم العثور على بيانات المستخدم')),
        );
      }
      setState(() => _isLoading = false);
      return;
    }
    try {
      final user = await ProfileRepository.getMe();
      if (!mounted) return;
      setState(() {
        _user = user;
        _fullNameController.text = user['full_name']?.toString() ?? '';
        _emailController.text = user['email']?.toString() ?? '';
        _phoneController.text = user['phone']?.toString() ?? '';
        _licenseController.text = user['license_no']?.toString() ?? '';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في تحميل البيانات: $e')));
    }
  }

  Future<void> _loadOperatingCard() async {
    setState(() => _isLoadingCard = true);
    try {
      final card = await ApiService.getOperatingCard();
      if (!mounted) return;
      setState(() {
        _operatingCard = card;
        _isLoadingCard = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingCard = false);
    }
  }

  Future<void> _uploadOperatingCard() async {
    final type = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('ملف PDF'),
              onTap: () => Navigator.pop(context, 'pdf'),
            ),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('صورة'),
              onTap: () => Navigator.pop(context, 'image'),
            ),
          ],
        ),
      ),
    );

    if (type == null) return;

    String? fileName;
    Uint8List? fileBytes;

    if (type == 'pdf') {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      fileName = result.files.first.name;
      fileBytes = result.files.first.bytes;
      if (fileBytes == null && result.files.first.path != null) {
        final f = File(result.files.first.path!);
        fileBytes = await f.readAsBytes();
      }
    } else {
      final picker = ImagePicker();
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('الكاميرا'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('المعرض'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
      if (source == null) return;
      final file = await picker.pickImage(source: source);
      if (file == null) return;
      fileName = file.name;
      fileBytes = await file.readAsBytes();
    }

    if (fileBytes == null || fileName == null) return;

    final expiryDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
      helpText: 'تاريخ انتهاء بطاقة التشغيل',
    );

    if (expiryDate == null) return;

    setState(() {
      _isUploadingCard = true;
      _cardUploadProgress = 0;
      _cardError = null;
    });

    try {
      final result = await ApiService.uploadOperatingCard(
        fileName: fileName,
        bytes: fileBytes,
        expiryDate: expiryDate.toIso8601String().split('T')[0],
        onProgress: (p) => setState(() => _cardUploadProgress = p),
      );

      if (!mounted) return;
      setState(() {
        _operatingCard = result['data'];
        _isUploadingCard = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم رفع بطاقة التشغيل بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploadingCard = false;
        _cardError = e.toString();
      });
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final userId = prefs.getInt('user_id');
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لم يتم العثور على بيانات المستخدم')),
      );
      setState(() => _isLoading = false);
      return;
    }
    try {
      final updated = await ProfileRepository.updateProfile({
        'fullName': _fullNameController.text,
        'email': _emailController.text,
        'phone': _phoneController.text,
        'licenseNo': _licenseController.text,
        'commercialNo': _user?['commercial_no'],
      });
      if (!mounted) return;
      setState(() {
        _user = updated;
        _isEditing = false;
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تحديث البيانات بنجاح')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في التحديث: $e')));
    }
  }

  Future<void> _showProfileImageActions() async {
    final action = await ProfileImageFlow.showActionSheet(
      context,
      hasImage: ProfileImageFlow.hasImage(_user),
    );
    if (action == null) return;

    if (action == ProfileImageAction.remove) {
      await _applyProfileImageChange(
        () => ProfileImageFlow.remove(),
        'تم حذف صورة الحساب',
      );
    } else {
      await _applyProfileImageChange(
        () => ProfileImageFlow.uploadFromAction(
          action,
          onProgress: (value) {
            if (!mounted) return;
            setState(() => _profileImageUploadProgress = value);
          },
        ),
        'تم تحديث صورة الحساب',
      );
    }
  }

  Future<void> _applyProfileImageChange(
    Future<ProfileImageChange?> Function() action,
    String successMessage,
  ) async {
    setState(() {
      _isUploadingProfileImage = true;
      _profileImageUploadProgress = 0;
    });
    try {
      final change = await action();
      if (change == null) return;
      if (!mounted) return;
      setState(() => _user = ProfileImageFlow.applyToProfile(_user, change));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر تحديث الصورة: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingProfileImage = false;
          _profileImageUploadProgress = null;
        });
      }
    }
  }

  Future<void> _openVehicleManagement() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const VehicleManagementScreen()));
    if (mounted) {
      await _loadProfile();
    }
  }

  Future<void> _logout() async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text(
                'تأكيد تسجيل الخروج',
                textAlign: TextAlign.center,
              ),
              content: const Text(
                'هل تريد فعلاً تسجيل الخروج؟',
                textAlign: TextAlign.center,
              ),
              actionsAlignment: MainAxisAlignment.center,
              actionsOverflowAlignment: OverflowBarAlignment.center,
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('إلغاء'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('تسجيل الخروج'),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (!confirmed) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await FirebaseAuth.instance.signOut();

      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تسجيل الخروج: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_user == null) {
      return const Scaffold(body: Center(child: Text('فشل في تحميل البيانات')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            )
          else
            IconButton(icon: const Icon(Icons.save), onPressed: _updateProfile),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: ValueListenableBuilder<ProfileImageState>(
                  valueListenable: ProfileRepository.profileImageNotifier,
                  builder: (context, state, _) {
                    final imageUrl =
                        _user?['profileImageUrl']?.toString() ??
                        _user?['profile_image_url']?.toString() ??
                        state.imageUrl;
                    final imageKey =
                        _user?['profileImageKey']?.toString() ?? state.imageKey;
                    return ProfileAvatar(
                      imageUrl: imageUrl,
                      imageKey: imageKey,
                      role: 'driver',
                      radius: 52,
                      showEditButton: true,
                      onEdit: _showProfileImageActions,
                      isUploading: _isUploadingProfileImage,
                      uploadProgress: _profileImageUploadProgress,
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              if (!_isEditing) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: DarbakColors.warningYellow,
                      size: 22,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_user!['average_rating'] ?? _user!['rating'] ?? '0.0'}  (${_user!['ratings_total'] ?? 0} تقييم)',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: DarbakColors.dark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (_isEditing) ...[
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: TextFormField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(
                      labelText: 'الاسم الكامل',
                    ),
                    textAlign: TextAlign.start,
                    textDirection: TextDirection.rtl,
                    validator: (value) => value!.isEmpty ? 'مطلوب' : null,
                  ),
                ),
                const SizedBox(height: 8),
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني',
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textAlign: TextAlign.start,
                    textDirection: TextDirection.ltr,
                    validator: (value) => value!.isEmpty ? 'مطلوب' : null,
                  ),
                ),
                const SizedBox(height: 8),
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(labelText: 'رقم الجوال'),
                    keyboardType: TextInputType.phone,
                    textAlign: TextAlign.start,
                    textDirection: TextDirection.ltr,
                    validator: (value) => value!.isEmpty ? 'مطلوب' : null,
                  ),
                ),
                const SizedBox(height: 8),
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: TextFormField(
                    controller: _licenseController,
                    decoration: const InputDecoration(labelText: 'رقم الرخصة'),
                    textAlign: TextAlign.start,
                    textDirection: TextDirection.ltr,
                  ),
                ),
              ] else ...[
                Text(
                  _user!['full_name'],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'البريد الإلكتروني: ${_user!['email'] ?? ''}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: DarbakColors.textSecondary),
                ),
                const SizedBox(height: 6),
                Text(
                  'رقم الجوال: ${_user!['phone']}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: DarbakColors.textSecondary),
                ),
                const SizedBox(height: 6),
                if (_user!['license_no'] != null)
                  Text(
                    'رقم رخصة: ${_user!['license_no']}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: DarbakColors.textSecondary),
                  ),
                const SizedBox(height: 8),
                Text(
                  'حالة التحقق: ${_kybStatusArabic(_user!['verification_status'])}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: DarbakColors.primaryGreen,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const DarbakSectionTitle(title: 'معلومات الشاحنة'),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _openVehicleManagement,
                icon: const Icon(Icons.local_shipping_rounded),
                label: const Text('إدارة شاحناتي'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: DarbakColors.primaryGreen),
                  foregroundColor: DarbakColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 16),
              const DarbakSectionTitle(title: 'المستندات'),
              const SizedBox(height: 8),
              _buildDocumentTile(
                'رخصة قيادة',
                isUploaded: _user!['document_path'] != null,
              ),
              const SizedBox(height: 8),
              _buildDocumentTile(
                'بطاقة التشغيل',
                isUploaded: _operatingCard != null,
                isUploading: _isUploadingCard,
                progress: _cardUploadProgress,
                errorMessage: _cardError,
                statusText: _operatingCard != null
                    ? _kybStatusArabic(_operatingCard!['verification_status'])
                    : null,
                onPressed: _uploadOperatingCard,
                onRetry: _cardError != null ? _uploadOperatingCard : null,
              ),
              const SizedBox(height: 24),
              DarbakLogoutBarButton(onPressed: _logout),
            ],
          ),
        ),
      ),
    );
  }

  String _kybStatusArabic(dynamic status) {
    switch ((status ?? 'pending').toString().toLowerCase()) {
      case 'verified':
        return 'موثّق';
      case 'rejected':
        return 'مرفوض';
      default:
        return 'قيد المراجعة';
    }
  }

  Widget _buildDocumentTile(
    String title, {
    required bool isUploaded,
    bool isUploading = false,
    double progress = 0,
    String? statusText,
    String? buttonLabel,
    String? errorMessage,
    VoidCallback? onPressed,
    VoidCallback? onRetry,
  }) {
    final resolvedStatusText = isUploading
        ? 'جاري الرفع ${(progress * 100).clamp(0, 100).round()}%'
        : errorMessage ??
              statusText ??
              (isUploaded ? 'تم حفظ الملف' : 'PDF أو صورة حتى 10 ميجابايت');
    final resolvedButtonLabel =
        buttonLabel ??
        (onPressed == null
            ? (isUploaded ? 'مرفوع' : 'غير متاح')
            : (isUploaded ? 'تحديث' : 'رفع'));

    return Card(
      elevation: 0,
      color: DarbakColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(title),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                resolvedStatusText,
                style: TextStyle(
                  color: errorMessage != null
                      ? Colors.red
                      : DarbakColors.textSecondary,
                ),
              ),
              if (isUploading) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress > 0 ? progress.clamp(0, 1).toDouble() : null,
                  color: DarbakColors.primaryGreen,
                ),
              ],
              if (!isUploading && onRetry != null) ...[
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('إعادة المحاولة'),
                ),
              ],
            ],
          ),
        ),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isUploaded
                ? DarbakColors.successGreen
                : DarbakColors.primaryGreen,
            minimumSize: const Size(100, 36),
          ),
          onPressed: isUploading ? null : onPressed,
          child: isUploading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  resolvedButtonLabel,
                  style: const TextStyle(color: Colors.white),
                ),
        ),
      ),
    );
  }
}
