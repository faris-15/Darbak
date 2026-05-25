import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'api_service.dart';
import 'app_theme.dart';
import 'app_widgets.dart';
import 'bidding_room_screen.dart';
import 'widgets/sar_price.dart';
import 'truck_classification/truck_classification_catalog.dart';
import 'truck_classification/truck_classification_models.dart';
import 'truck_classification/widgets/truck_classification_dropdowns.dart';

class AvailableLoadsScreen extends StatefulWidget {
  const AvailableLoadsScreen({super.key});

  @override
  State<AvailableLoadsScreen> createState() => _AvailableLoadsScreenState();
}

class _AvailableLoadsScreenState extends State<AvailableLoadsScreen> {
  static const Duration _dashboardRefreshInterval = Duration(seconds: 30);
  static const Duration _filterDebounceDuration = Duration(milliseconds: 450);
  static const int _pageSize = 20;

  List<dynamic> shipments = [];
  bool isLoading = true;
  String errorMessage = '';
  String userName = 'المستخدم';
  int userId = 0;
  String userRating = 'جديد';
  String ratingCountLabel = 'لا تقييمات';
  String totalEarnings = '0';
  String completedTrips = '0';
  bool _isLoadingUserData = false;
  bool _isLoadingMore = false;
  bool _isRefreshingShipments = false;
  bool _hasMoreShipments = true;
  bool _isSearchExpanded = false;
  int _currentPage = 1;
  int _totalShipments = 0;
  int _activeRequestId = 0;
  String? _lastRequestKey;
  final TextEditingController _originCityController = TextEditingController();
  final TextEditingController _destinationCityController =
      TextEditingController();
  final TextEditingController _cargoTypeController = TextEditingController();
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();
  final TextEditingController _minWeightController = TextEditingController();
  final TextEditingController _maxWeightController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _matchMyTruck = false;
  TruckGroup? _filterTruckGroup;
  String? _filterTruckCategory;
  Timer? _filtersDebounce;
  Timer? _ticker;
  Timer? _dashboardRefreshTimer;
  /// غرفة مزايدة واحدة: رقم الشحنة التي يملك عليها السائق عرضاً معلّقاً، إن وُجد.
  int? _myActiveBidShipmentId;
  int? _withdrawingShipmentId;
  String _verificationStatus = 'pending';

  bool get _driverKybVerified =>
      _verificationStatus.toLowerCase() == 'verified';

  String _driverKybBannerMessage() {
    switch (_verificationStatus.toLowerCase()) {
      case 'rejected':
        return 'لم تُقبل وثائقك من الإدارة. تواصل مع الدعم أو انتظر مراجعة جديدة.';
      case 'verified':
        return '';
      default:
        return 'حسابك قيد مراجعة الوثائق (الرخصة وغيرها). بعد اعتماد الإدارة يمكنك تقديم العروض على الشحنات.';
    }
  }

  @override
  void initState() {
    super.initState();
    _wireFilterControllers();
    _scrollController.addListener(_onScroll);
    _loadUserData();
    _loadAvailableShipments(reset: true);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _dashboardRefreshTimer = Timer.periodic(_dashboardRefreshInterval, (_) {
      _loadUserData();
    });
  }

  @override
  void dispose() {
    _filtersDebounce?.cancel();
    _originCityController.dispose();
    _destinationCityController.dispose();
    _cargoTypeController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _minWeightController.dispose();
    _maxWeightController.dispose();
    _scrollController.dispose();
    _ticker?.cancel();
    _dashboardRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    if (_isLoadingUserData) return;
    _isLoadingUserData = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedUserName = prefs.getString('user_name') ?? 'المستخدم';
      final storedUserId = prefs.getInt('user_id') ?? 0;
      if (!mounted) return;
      setState(() {
        userName = storedUserName;
        userId = storedUserId;
      });

      if (storedUserId <= 0) {
        if (mounted) {
          setState(() => _myActiveBidShipmentId = null);
        }
        return;
      }

      final profile = await ApiService.getProfile(storedUserId);
      final dashboardStats = _DriverDashboardStats.fromProfile(
        profile,
        fallbackName: storedUserName,
      );
      if (!mounted) return;
      setState(() {
        userName = dashboardStats.userName;
        userRating = dashboardStats.ratingLabel;
        ratingCountLabel = dashboardStats.ratingCountLabel;
        completedTrips = dashboardStats.completedTripsLabel;
        totalEarnings = dashboardStats.totalEarningsLabel;
        _verificationStatus =
            profile['verification_status']?.toString() ?? 'pending';
      });
      await _refreshMyActiveBid();
    } catch (e) {
      debugPrint('Error loading driver dashboard data: $e');
    } finally {
      _isLoadingUserData = false;
    }
  }

  void _wireFilterControllers() {
    for (final controller in [
      _originCityController,
      _destinationCityController,
      _cargoTypeController,
      _minPriceController,
      _maxPriceController,
      _minWeightController,
      _maxWeightController,
    ]) {
      controller.addListener(_onFilterChanged);
    }
  }

  void _onFilterChanged() {
    // Root cause: the old filter row was static UI, so every reload pulled the
    // full market. Debouncing keeps typing responsive without flooding the API.
    _scheduleFilterReload();
  }

  void _scheduleFilterReload() {
    _filtersDebounce?.cancel();
    setState(() {});
    _filtersDebounce = Timer(_filterDebounceDuration, () {
      _loadAvailableShipments(reset: true);
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients || !_hasMoreShipments) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 280) {
      _loadAvailableShipments(loadMore: true);
    }
  }

  Future<void> _loadAvailableShipments({
    bool reset = false,
    bool loadMore = false,
    bool forceRefresh = false,
  }) async {
    if (loadMore && (_isLoadingMore || isLoading || _isRefreshingShipments)) {
      return;
    }
    if (!loadMore && (isLoading && shipments.isNotEmpty)) return;

    final nextPage = loadMore ? _currentPage + 1 : 1;
    final query = _buildShipmentQuery(nextPage);
    final requestKey = _requestKey(query);
    if (!forceRefresh && _lastRequestKey == requestKey) return;
    _lastRequestKey = requestKey;
    final requestId = ++_activeRequestId;

    try {
      setState(() {
        if (loadMore) {
          _isLoadingMore = true;
        } else {
          isLoading = shipments.isEmpty;
          _isRefreshingShipments = shipments.isNotEmpty;
          if (reset) {
            _currentPage = 1;
            _hasMoreShipments = true;
          }
        }
        errorMessage = '';
      });

      final response = await ApiService.getShipmentPage(query);

      // Defensive client-side guard keeps older servers from showing assigned
      // work in the driver's tender market while the backend filter rolls out.
      final filteredShipments = response.data
          .where(
            (shipment) =>
                shipment['status'] == 'pending' ||
                shipment['status'] == 'bidding',
          )
          .where(_matchesClientFilters)
          .toList();

      if (!mounted || requestId != _activeRequestId) return;
      setState(() {
        shipments = loadMore
            ? [...shipments, ...filteredShipments]
            : filteredShipments;
        _currentPage = response.page;
        _totalShipments = response.total == response.data.length
            ? filteredShipments.length
            : response.total;
        _hasMoreShipments = response.hasMore;
        isLoading = false;
        _isLoadingMore = false;
        _isRefreshingShipments = false;
      });
      if (!mounted || requestId != _activeRequestId) return;
      await _refreshMyActiveBid();
    } catch (e) {
      if (!mounted || requestId != _activeRequestId) return;
      setState(() {
        isLoading = false;
        _isLoadingMore = false;
        _isRefreshingShipments = false;
        errorMessage = 'فشل في تحميل الشحنات: ${e.toString()}';
      });
      debugPrint('Error loading shipments: $e');
    }
  }

  int? _shipmentIdFromMap(Map<String, dynamic> data) {
    final v = data['id'];
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '');
  }

  Future<void> _refreshMyActiveBid() async {
    if (userId <= 0) {
      if (mounted) setState(() => _myActiveBidShipmentId = null);
      return;
    }
    try {
      final r = await ApiService.getMyActiveBid();
      if (!mounted) return;
      int? sid;
      if (r['active'] == true && r['bid'] is Map) {
        final b = r['bid'] as Map;
        final v = b['shipmentId'];
        sid = v is num ? v.toInt() : int.tryParse(v?.toString() ?? '');
      }
      setState(() => _myActiveBidShipmentId = sid);
    } catch (_) {
      if (mounted) setState(() => _myActiveBidShipmentId = null);
    }
  }

  Future<void> _handleWithdrawFromMarket(int shipmentId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('سحب العرض؟'),
        content: const Text(
          'سيتم إلغاء عرضك على هذه الشحنة. يمكنك بعدها المزايدة على شحنة أخرى إن رغبت.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('سحب العرض'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _withdrawingShipmentId = shipmentId);
    try {
      await ApiService.withdrawMyPendingBid(shipmentId: shipmentId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم سحب عرضك'),
          backgroundColor: DarbakColors.success,
        ),
      );
      await _refreshMyActiveBid();
      await _loadAvailableShipments(reset: true, forceRefresh: true);
    } on DarbakException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: DarbakColors.danger,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: DarbakColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _withdrawingShipmentId = null);
    }
  }

  bool _matchesClientFilters(dynamic rawShipment) {
    if (rawShipment is! Map) return false;
    final shipment = Map<String, dynamic>.from(rawShipment);

    bool containsFilter(dynamic rawValue, TextEditingController controller) {
      final filter = controller.text.trim().toLowerCase();
      if (filter.isEmpty) return true;
      return (rawValue?.toString().toLowerCase() ?? '').contains(filter);
    }

    if (!containsFilter(shipment['pickup_address'], _originCityController)) {
      return false;
    }
    if (!containsFilter(
      shipment['dropoff_address'],
      _destinationCityController,
    )) {
      return false;
    }
    if (!containsFilter(shipment['cargo_description'], _cargoTypeController)) {
      return false;
    }

    final price = _readPrice(
      (shipment['suggested_price'] ?? shipment['base_price'] ?? '').toString(),
    );
    final range = _normalizedPriceRange();
    if (range.$1 != null && (price == null || price < range.$1!)) return false;
    if (range.$2 != null && (price == null || price > range.$2!)) return false;

    final weight = _readNumber(shipment['weight_kg']?.toString() ?? '');
    final weightRange = _normalizedWeightRange();
    if (weightRange.$1 != null &&
        (weight == null || weight < weightRange.$1!)) {
      return false;
    }
    if (weightRange.$2 != null &&
        (weight == null || weight > weightRange.$2!)) {
      return false;
    }
    return true;
  }

  ShipmentListQuery _buildShipmentQuery(int page) {
    final prices = _normalizedPriceRange();
    final weights = _normalizedWeightRange();
    return ShipmentListQuery(
      status: 'pending,bidding',
      pickupCity: _cleanText(_originCityController.text),
      dropoffCity: _cleanText(_destinationCityController.text),
      cargoCategory: _cleanText(_cargoTypeController.text),
      minWeight: weights.$1,
      maxWeight: weights.$2,
      minPrice: prices.$1,
      maxPrice: prices.$2,
      truckGroup: _filterTruckGroup?.id,
      truckCategory: _filterTruckCategory,
      matchMyTruck: _matchMyTruck,
      page: page,
      limit: _pageSize,
    );
  }

  String _requestKey(ShipmentListQuery query) => query
      .toQueryParameters()
      .entries
      .map((e) => '${e.key}=${e.value}')
      .join('&');

  String? _cleanText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  (double?, double?) _normalizedPriceRange() {
    final min = _readPrice(_minPriceController.text);
    final max = _readPrice(_maxPriceController.text);
    if (min != null && max != null && min > max) return (max, min);
    return (min, max);
  }

  (double?, double?) _normalizedWeightRange() {
    final min = _readNumber(_minWeightController.text);
    final max = _readNumber(_maxWeightController.text);
    if (min != null && max != null && min > max) return (max, min);
    return (min, max);
  }

  double? _readPrice(String value) {
    return _readNumber(value);
  }

  double? _readNumber(String value) {
    final cleaned = value.trim().replaceAll(',', '');
    if (cleaned.isEmpty) return null;
    final parsed = double.tryParse(cleaned);
    if (parsed == null || !parsed.isFinite || parsed < 0) return null;
    return parsed;
  }

  bool get _hasActiveFilters =>
      _originCityController.text.trim().isNotEmpty ||
      _destinationCityController.text.trim().isNotEmpty ||
      _cargoTypeController.text.trim().isNotEmpty ||
      _minWeightController.text.trim().isNotEmpty ||
      _maxWeightController.text.trim().isNotEmpty ||
      _minPriceController.text.trim().isNotEmpty ||
      _maxPriceController.text.trim().isNotEmpty ||
      _filterTruckGroup != null ||
      _filterTruckCategory != null ||
      _matchMyTruck;

  int get _activeFilterCount {
    var count = 0;
    if (_originCityController.text.trim().isNotEmpty) count++;
    if (_destinationCityController.text.trim().isNotEmpty) count++;
    if (_minWeightController.text.trim().isNotEmpty ||
        _maxWeightController.text.trim().isNotEmpty) {
      count++;
    }
    if (_minPriceController.text.trim().isNotEmpty ||
        _maxPriceController.text.trim().isNotEmpty) {
      count++;
    }
    if (_matchMyTruck) count++;
    if (_filterTruckGroup != null || _filterTruckCategory != null) count++;
    return count;
  }

  void _resetFilters() {
    _filtersDebounce?.cancel();
    _originCityController.clear();
    _destinationCityController.clear();
    _cargoTypeController.clear();
    _minPriceController.clear();
    _maxPriceController.clear();
    _minWeightController.clear();
    _maxWeightController.clear();
    setState(() {
      _matchMyTruck = false;
      _filterTruckGroup = null;
      _filterTruckCategory = null;
    });
    _loadAvailableShipments(reset: true, forceRefresh: true);
  }

  void _toggleSearchPanel() {
    setState(() {
      _isSearchExpanded = !_isSearchExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DarbakColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _TopDashboardHeader(
              userName: userName,
              rating: userRating,
              ratingCount: ratingCountLabel,
              completedTrips: completedTrips,
              totalEarnings: totalEarnings,
            ),
            if (!_driverKybVerified)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Material(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding:
                        const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          color: Colors.amber.shade900,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _driverKybBannerMessage(),
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              color: Colors.brown.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(child: _buildShipmentContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildShipmentContent() {
    if (isLoading && shipments.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: DarbakColors.primary),
      );
    }

    if (errorMessage.isNotEmpty && shipments.isEmpty) {
      return _ErrorState(
        message: errorMessage,
        onRetry: () => _loadAvailableShipments(reset: true, forceRefresh: true),
      );
    }

    return RefreshIndicator(
      color: DarbakColors.primary,
      onRefresh: () async {
        await _loadUserData();
        await _loadAvailableShipments(reset: true, forceRefresh: true);
      },
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 24),
        children: [
          _ShipmentFilterPanel(
            originCityController: _originCityController,
            destinationCityController: _destinationCityController,
            minWeightController: _minWeightController,
            maxWeightController: _maxWeightController,
            minPriceController: _minPriceController,
            maxPriceController: _maxPriceController,
            matchMyTruck: _matchMyTruck,
            filterTruckGroup: _filterTruckGroup,
            filterTruckCategory: _filterTruckCategory,
            onMatchMyTruckChanged: (value) {
              setState(() => _matchMyTruck = value);
              _scheduleFilterReload();
            },
            onFilterTruckGroupChanged: (group) {
              setState(() {
                _filterTruckGroup = group;
                _filterTruckCategory = null;
              });
              _scheduleFilterReload();
            },
            onFilterTruckCategoryChanged: (categoryId) {
              setState(() => _filterTruckCategory = categoryId);
              _scheduleFilterReload();
            },
            activeFilterCount: _activeFilterCount,
            hasActiveFilters: _hasActiveFilters,
            isExpanded: _isSearchExpanded,
            onToggle: _toggleSearchPanel,
            onReset: _resetFilters,
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _isRefreshingShipments
                ? const Padding(
                    key: ValueKey('refreshing'),
                    padding: EdgeInsets.only(top: 14),
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      color: DarbakColors.primary,
                      backgroundColor: Color(0xffE7EFEA),
                    ),
                  )
                : const SizedBox(key: ValueKey('not-refreshing'), height: 14),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'الشحنات المتاحة',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: DarbakColors.text,
                ),
              ),
              _CountChip(label: '$_totalShipments شحنة'),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: shipments.isEmpty
                ? _EmptyShipmentsState(
                    key: ValueKey(
                      'empty-${_hasActiveFilters ? 'filters' : 'all'}',
                    ),
                    hasActiveFilters: _hasActiveFilters,
                    onReset: _resetFilters,
                  )
                : Column(
                    key: ValueKey('list-${shipments.length}'),
                    children: shipments.asMap().entries.map((entry) {
                      final index = entry.key;
                      final shipment = Map<String, dynamic>.from(entry.value);
                      final sid = _shipmentIdFromMap(shipment);
                      final hasHere = sid != null &&
                          _myActiveBidShipmentId != null &&
                          _myActiveBidShipmentId == sid;
                      final blockedElsewhere = sid != null &&
                          _myActiveBidShipmentId != null &&
                          _myActiveBidShipmentId != sid;
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index < shipments.length - 1 ? 14 : 0,
                        ),
                        child: ShipmentCard(
                          shipmentData: shipment,
                          isAuctionExpired: _isAuctionExpired(shipment),
                          countdownText: _countdownText(shipment),
                          hasMyPendingBidHere: hasHere,
                          blockedByActiveBidElsewhere: blockedElsewhere,
                          isWithdrawingHere:
                              sid != null && _withdrawingShipmentId == sid,
                          onWithdrawTap: hasHere
                              ? () => _handleWithdrawFromMarket(sid)
                              : null,
                          onBidTap: () {
                            if (!_driverKybVerified) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(_driverKybBannerMessage()),
                                ),
                              );
                              return;
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BidDetailsScreen(
                                  shipmentId: shipment['id'],
                                  shipmentData: shipment,
                                  driverId: userId,
                                  driverName: userName,
                                ),
                              ),
                            ).then((_) async {
                              await _loadAvailableShipments(
                                reset: true,
                                forceRefresh: true,
                              );
                              await _refreshMyActiveBid();
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
          ),
          if (_isLoadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: CircularProgressIndicator(color: DarbakColors.primary),
              ),
            ),
        ],
      ),
    );
  }

  bool _isAuctionExpired(Map<String, dynamic> shipment) {
    final raw = shipment['auction_end_time']?.toString();
    if (raw == null || raw.isEmpty) return false;
    final end = DateTime.tryParse(raw);
    if (end == null) return false;
    return DateTime.now().isAfter(end);
  }

  String _countdownText(Map<String, dynamic> shipment) {
    final raw = shipment['auction_end_time']?.toString();
    if (raw == null || raw.isEmpty) return 'غير محدد';
    final end = DateTime.tryParse(raw);
    if (end == null) return 'غير محدد';
    final diff = end.difference(DateTime.now());
    if (diff.isNegative || diff.inSeconds <= 0) return 'انتهى المزاد';
    final h = diff.inHours.toString().padLeft(2, '0');
    final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class _DriverDashboardStats {
  final String userName;
  final double? averageRating;
  final int ratingsTotal;
  final String completedTripsLabel;
  final String totalEarningsLabel;

  const _DriverDashboardStats({
    required this.userName,
    required this.averageRating,
    required this.ratingsTotal,
    required this.completedTripsLabel,
    required this.totalEarningsLabel,
  });

  factory _DriverDashboardStats.fromProfile(
    Map<String, dynamic> profile, {
    required String fallbackName,
  }) {
    final rating = _readDouble(profile['average_rating'] ?? profile['rating']);
    return _DriverDashboardStats(
      userName: _readText(
        profile['full_name'] ?? profile['name'],
        fallbackName,
      ),
      averageRating: rating,
      ratingsTotal: _readInt(
        profile['ratings_total'] ?? profile['total_ratings'],
      ),
      completedTripsLabel: _readNumberLabel(profile['completed_trips']),
      totalEarningsLabel: _readNumberLabel(profile['total_earnings']),
    );
  }

  bool get hasRatings => ratingsTotal > 0 || (averageRating ?? 0) > 0;

  String get ratingLabel =>
      hasRatings ? (averageRating ?? 0).toStringAsFixed(1) : 'جديد';

  String get ratingCountLabel =>
      ratingsTotal > 0 ? '$ratingsTotal تقييم' : 'لا تقييمات';

  static String _readText(dynamic value, String fallback) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? _readDouble(dynamic value) {
    if (value == null) return null;
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value.toString());
    if (parsed == null || !parsed.isFinite) return null;
    return parsed.clamp(0, 5).toDouble();
  }

  static String _readNumberLabel(dynamic value) {
    if (value == null) return '0';
    final parsed = value is num ? value : num.tryParse(value.toString());
    if (parsed == null) return value.toString();
    return parsed % 1 == 0
        ? parsed.toInt().toString()
        : parsed.toStringAsFixed(2);
  }
}

class _TopDashboardHeader extends StatelessWidget {
  final String userName;
  final String rating;
  final String ratingCount;
  final String completedTrips;
  final String totalEarnings;

  const _TopDashboardHeader({
    required this.userName,
    required this.rating,
    required this.ratingCount,
    required this.completedTrips,
    required this.totalEarnings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsetsDirectional.fromSTEB(16, 18, 16, 22),
      decoration: BoxDecoration(
        color: DarbakColors.primary,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'مرحباً بك',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: StatCard(title: 'إجمالي الأرباح', value: totalEarnings),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: 'التقييم',
                  value: rating,
                  subtitle: ratingCount,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(title: 'رحلة مكتملة', value: completedTrips),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          if (subtitle != null) ...[
            Text(
              subtitle!,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
          ],
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShipmentFilterPanel extends StatelessWidget {
  final TextEditingController originCityController;
  final TextEditingController destinationCityController;
  final TextEditingController minWeightController;
  final TextEditingController maxWeightController;
  final TextEditingController minPriceController;
  final TextEditingController maxPriceController;
  final bool matchMyTruck;
  final TruckGroup? filterTruckGroup;
  final String? filterTruckCategory;
  final ValueChanged<bool> onMatchMyTruckChanged;
  final ValueChanged<TruckGroup?> onFilterTruckGroupChanged;
  final ValueChanged<String?> onFilterTruckCategoryChanged;
  final int activeFilterCount;
  final bool hasActiveFilters;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onReset;

  const _ShipmentFilterPanel({
    required this.originCityController,
    required this.destinationCityController,
    required this.minWeightController,
    required this.maxWeightController,
    required this.minPriceController,
    required this.maxPriceController,
    required this.matchMyTruck,
    required this.filterTruckGroup,
    required this.filterTruckCategory,
    required this.onMatchMyTruckChanged,
    required this.onFilterTruckGroupChanged,
    required this.onFilterTruckCategoryChanged,
    required this.activeFilterCount,
    required this.hasActiveFilters,
    required this.isExpanded,
    required this.onToggle,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return DarbakSurface(
      padding: const EdgeInsets.all(14),
      radius: DarbakRadius.xl,
      boxShadow: DarbakShadows.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Material(
                color: DarbakColors.lightGreen,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: onToggle,
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 42,
                    height: 42,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: Icon(
                        isExpanded ? Icons.close_rounded : Icons.search_rounded,
                        key: ValueKey(isExpanded),
                        color: DarbakColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ابحث عن الشحنات',
                      style: TextStyle(
                        color: DarbakColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasActiveFilters && !isExpanded
                          ? '$activeFilterCount فلتر نشط'
                          : 'اضغط على أيقونة البحث لفتح الفلاتر',
                      style: const TextStyle(
                        color: DarbakColors.subText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasActiveFilters)
                TextButton(onPressed: onReset, child: const Text('مسح')),
            ],
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xffF7FAF8),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xffDDE7E1)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _RouteSearchField(
                          controller: originCityController,
                          label: 'من',
                          hint: 'مدينة الانطلاق',
                          icon: Icons.trip_origin_rounded,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: _RouteConnector(),
                      ),
                      Expanded(
                        child: _RouteSearchField(
                          controller: destinationCityController,
                          label: 'إلى',
                          hint: 'مدينة الوصول',
                          icon: Icons.flag_rounded,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _RouteSearchField(
                        controller: minWeightController,
                        label: 'أقل وزن',
                        hint: 'طن',
                        icon: Icons.scale_outlined,
                        keyboardType: TextInputType.number,

                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _RouteSearchField(
                        controller: maxWeightController,
                        label: 'أعلى وزن',
                        hint: 'طن',
                        icon: Icons.monitor_weight_outlined,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'شحنات تناسب شاحنتي النشطة',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  value: matchMyTruck,
                  activeThumbColor: DarbakColors.primary,
                  onChanged: onMatchMyTruckChanged,
                ),
                if (!matchMyTruck) ...[
                  TruckGroupDropdown(
                    value: filterTruckGroup,
                    onChanged: onFilterTruckGroupChanged,
                  ),
                  const SizedBox(height: 8),
                  if (filterTruckGroup != null)
                    TruckCategoryDropdown(
                      categories: TruckClassificationCatalog.categoriesForGroup(
                        filterTruckGroup!,
                      ),
                      value: filterTruckCategory,
                      onChanged: onFilterTruckCategoryChanged,
                    ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _RouteSearchField(
                        controller: minPriceController,
                        label: 'أقل سعر',
                        hint: 'مثال: 200',
                        icon: Icons.payments_outlined,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _RouteSearchField(
                        controller: maxPriceController,
                        label: 'أعلى سعر',
                        hint: 'مثال: 700',
                        icon: Icons.price_change_outlined,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                if (hasActiveFilters) ...[
                  const SizedBox(height: 10),
                  Text(
                    '$activeFilterCount فلتر نشط',
                    style: const TextStyle(
                      color: DarbakColors.primaryDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 240),
            firstCurve: Curves.easeOut,
            secondCurve: Curves.easeOut,
            sizeCurve: Curves.easeInOutCubic,
          ),
        ],
      ),
    );
  }
}

class _RouteSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;

  const _RouteSearchField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: TextInputAction.search,
      textAlign: TextAlign.start,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: DarbakColors.primary, size: 20),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: DarbakColors.primary, width: 1.3),
        ),
      ),
    );
  }
}

class _RouteConnector extends StatelessWidget {
  const _RouteConnector();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        3,
        (index) => Container(
          width: 5,
          height: 5,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: index == 1 ? DarbakColors.primary : const Color(0xffC9D2DC),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;

  const _CountChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xffF0F2F5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          color: DarbakColors.text,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: DarbakColors.danger,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: DarbakColors.text),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة محاولة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: DarbakColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyShipmentsState extends StatelessWidget {
  final bool hasActiveFilters;
  final VoidCallback onReset;

  const _EmptyShipmentsState({
    super.key,
    required this.hasActiveFilters,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 34),
      decoration: BoxDecoration(
        color: DarbakColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: DarbakColors.borderSoft),
      ),
      child: Column(
        children: [
          Icon(
            hasActiveFilters ? Icons.search_off_rounded : Icons.inbox_outlined,
            size: 64,
            color: DarbakColors.subText,
          ),
          const SizedBox(height: 16),
          Text(
            hasActiveFilters
                ? 'لا توجد طلبات مطابقة للفلاتر'
                : 'لا توجد شحنات متاحة حالياً',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: DarbakColors.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasActiveFilters
                ? 'جرّب توسيع نطاق السعر أو تعديل المدن ونوع الحمولة'
                : 'برجاء المحاولة لاحقاً',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: DarbakColors.subText),
          ),
          if (hasActiveFilters) ...[
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('مسح الفلاتر'),
            ),
          ],
        ],
      ),
    );
  }
}

class ShipmentCard extends StatelessWidget {
  final Map<String, dynamic> shipmentData;
  final bool isAuctionExpired;
  final String countdownText;
  final VoidCallback onBidTap;
  final bool hasMyPendingBidHere;
  final bool blockedByActiveBidElsewhere;
  final bool isWithdrawingHere;
  final VoidCallback? onWithdrawTap;

  const ShipmentCard({
    super.key,
    required this.shipmentData,
    required this.isAuctionExpired,
    required this.countdownText,
    required this.onBidTap,
    this.hasMyPendingBidHere = false,
    this.blockedByActiveBidElsewhere = false,
    this.isWithdrawingHere = false,
    this.onWithdrawTap,
  });

  String _getCategory(String? description) {
    if (description == null || description.isEmpty) return 'عام';
    // Extract category from description or return first word
    return description.split(' ').first;
  }

  String _getCityDisplay(String? address) {
    if (address == null || address.isEmpty) return 'Unknown';
    // Extract city from address (assuming format like "City, Country" or just "City")
    return address.split(',')[0].trim();
  }

  double? _readRating(dynamic value) {
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    if (parsed == null || !parsed.isFinite || parsed <= 0) return null;
    return parsed.clamp(0, 5).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final cityFrom = _getCityDisplay(shipmentData['pickup_address']);
    final cityTo = _getCityDisplay(shipmentData['dropoff_address']);
    final category = _getCategory(shipmentData['cargo_description']);
    final weight = '${shipmentData['weight_kg'] ?? 0} طن';
    final suggestedPrice =
        shipmentData['suggested_price'] ?? shipmentData['base_price'];
    final shipperRating = _readRating(
      shipmentData['shipper_rating'] ??
          shipmentData['average_rating'] ??
          shipmentData['rating'],
    );

    return DarbakSurface(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(18, 18, 18, 10),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      constraints: const BoxConstraints(maxWidth: 120),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xffEEF2FF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: DarbakColors.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'من',
                            style: TextStyle(
                              color: DarbakColors.subText,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            cityFrom,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: DarbakColors.text,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'إلى',
                            style: TextStyle(
                              color: DarbakColors.subText,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            cityTo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: DarbakColors.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 112,
                      child: Column(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: const BoxDecoration(
                              color: DarbakColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Container(
                              width: 2,
                              color: const Color(0xffE5E7EB),
                            ),
                          ),
                          Container(
                            width: 14,
                            height: 14,
                            decoration: const BoxDecoration(
                              color: Color(0xffE5E7EB),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 26, color: DarbakColors.borderSoft),
                Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  children: [
                    _MiniInfo(icon: Icons.scale_outlined, text: weight),
                    if (shipperRating != null) ...[
                      _MiniInfo(
                        icon: Icons.star_rounded,
                        text: shipperRating.toStringAsFixed(1),
                      ),
                    ],
                    _MiniInfo(
                      icon: Icons.access_time_rounded,
                      text: isAuctionExpired ? 'انتهى المزاد' : countdownText,
                      color: isAuctionExpired
                          ? DarbakColors.danger
                          : DarbakColors.orange,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Text(
                      'السعر المقترح',
                      style: TextStyle(
                        fontSize: 14,
                        color: DarbakColors.subText,
                      ),
                    ),
                    const Spacer(),
                    SarPrice(
                      amount: suggestedPrice,
                      style: const TextStyle(
                        fontSize: 20,
                        color: DarbakColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: DarbakColors.borderSoft)),
            ),
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: hasMyPendingBidHere
                    ? (isWithdrawingHere || onWithdrawTap == null
                        ? null
                        : onWithdrawTap)
                    : isAuctionExpired
                        ? null
                        : blockedByActiveBidElsewhere
                            ? () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'لديك عرض معلّق على شحنة أخرى. افتح بطاقة تلك الشحنة واضغط «سحب العرض».',
                                    ),
                                  ),
                                );
                              }
                            : onBidTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasMyPendingBidHere
                      ? DarbakColors.danger
                      : DarbakColors.primary,
                  disabledBackgroundColor: const Color(0xffDCEFE6),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: DarbakColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  hasMyPendingBidHere
                      ? (isWithdrawingHere ? 'جاري السحب...' : 'سحب العرض')
                      : 'تقديم عرض',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _MiniInfo({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color ?? DarbakColors.subText),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 15,
            color: color ?? DarbakColors.text,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
