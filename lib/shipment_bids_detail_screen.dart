import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'api_service.dart';
import 'contract/open_contract_pdf.dart';
import 'models/bid_model.dart';
import 'utils/sar_formatter.dart';
import 'utils/shipment_display.dart';
import 'widgets/sar_price.dart';

/// شاشة تفاصيل عروض الشحنة للشاحن
class ShipmentBidsDetailScreen extends StatefulWidget {
  final int shipmentId;
  final String? pickupAddress;
  final String? dropoffAddress;
  final double? suggestedPrice;

  const ShipmentBidsDetailScreen({
    required this.shipmentId,
    required this.pickupAddress,
    required this.dropoffAddress,
    this.suggestedPrice,
    super.key,
  });

  @override
  State<ShipmentBidsDetailScreen> createState() =>
      _ShipmentBidsDetailScreenState();
}

class _ShipmentBidsDetailScreenState extends State<ShipmentBidsDetailScreen> {
  List<BidModel> _bids = [];
  bool _loading = true;
  String? _error;
  int? _acceptingBidId; // For showing loading state during acceptance
  int? _acceptedBidId; // Track which bid was accepted

  @override
  void initState() {
    super.initState();
    _loadBids();
  }

  Future<void> _loadBids() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final bids = await ApiService.getBids(widget.shipmentId);
      setState(() {
        _bids = bids;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _acceptBid(int bidId) async {
    setState(() {
      _acceptingBidId = bidId;
    });

    try {
      final result = await ApiService.acceptBid(bidId);

      if (mounted) {
        setState(() {
          _acceptedBidId = bidId;
          _acceptingBidId = null;
        });

        final contractKey = (result['contract_pdf_key'] ?? '')
            .toString()
            .trim();
        final contractId = result['contract_id'];
        BidModel? acceptedBid;
        try {
          acceptedBid = _bids.firstWhere((b) => b.id == bidId);
        } catch (_) {
          acceptedBid = null;
        }
        final amtStr = acceptedBid != null
            ? SarFormatter.format(acceptedBid.bidAmount, decimalDigits: 0)
            : '';
        if (contractKey.isNotEmpty) {
          final idPart = contractId != null ? ' رقم #$contractId' : '';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم إنشاء عقد$idPart بقيمة $amtStr'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'عرض العقد',
                textColor: Colors.white,
                onPressed: () {
                  if (!context.mounted) return;
                  openShipmentContractPdfInApp(context, widget.shipmentId);
                },
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم قبول العرض بنجاح'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }

        // Go back after a short delay
        Future.delayed(Duration(seconds: contractKey.isNotEmpty ? 5 : 2), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _acceptingBidId = null;
        });

        // Extract error message
        String errorMessage = 'فشل قبول العرض';
        if (e.toString().contains('Failed to accept bid')) {
          errorMessage = 'فشل قبول العرض. يرجى المحاولة مرة أخرى';
        } else if (e.toString().contains('Server error')) {
          errorMessage = 'خطأ في الخادم. تأكد من اتصالك بالإنترنت';
        } else if (e.toString().contains('Connection')) {
          errorMessage = 'خطأ في الاتصال. تحقق من الشبكة';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'accepted':
        return 'مقبول';
      case 'rejected':
        return 'مرفوض';
      case 'pending':
        return 'قيد المراجعة';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatAmount(dynamic amount, {int decimalDigits = 2}) {
    return SarFormatter.format(amount, decimalDigits: decimalDigits);
  }

  String _comparisonLabel(double bidAmount) {
    final suggested = widget.suggestedPrice;
    if (suggested == null || suggested <= 0) {
      return 'لا يوجد سعر مقترح للمقارنة';
    }

    final difference = bidAmount - suggested;
    if (difference.abs() < 0.01) return 'مطابق للسعر المقترح';

    final direction = difference > 0 ? 'أعلى' : 'أقل';
    final percent = (difference.abs() / suggested) * 100;
    return '$direction من السعر المقترح بـ ${_formatAmount(difference.abs())} (${percent.toStringAsFixed(1)}%)';
  }

  @override
  Widget build(BuildContext context) {
    final routeWidth = MediaQuery.sizeOf(context).width * 0.58;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: SizedBox(
            width: routeWidth,
            child: _ShipmentBidsAppBarRoute(
              pickupAddress: widget.pickupAddress,
              dropoffAddress: widget.dropoffAddress,
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: DarbakColors.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'خطأ في تحميل العروض',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _error ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        color: DarbakColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loadBids,
                    child: const Text('إعادة محاولة'),
                  ),
                ],
              ),
            )
          : _bids.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 48,
                    color: DarbakColors.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'لا توجد عروض حتى الآن',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'سيظهر هنا جميع عروض السائقين على الشحنة',
                      style: TextStyle(
                        fontSize: 14,
                        color: DarbakColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadBids,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _bids.length,
                itemBuilder: (context, index) {
                  final bid = _bids[index];
                  final isLowestPrice = index == 0;
                  final isAccepted = bid.bidStatus == 'accepted';
                  final isRejected = bid.bidStatus == 'rejected';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    color: isAccepted
                        ? Colors.green.shade50
                        : isRejected
                        ? Colors.red.shade50
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Driver name + Status badge
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      bid.driverName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (isLowestPrice)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 4),
                                        child: Text(
                                          'أقل سعر',
                                          style: TextStyle(
                                            color: Colors.green,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                    bid.bidStatus,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _getStatusLabel(bid.bidStatus),
                                  style: TextStyle(
                                    color: _getStatusColor(bid.bidStatus),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Driver details
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Directionality(
                              textDirection: TextDirection.rtl,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (bid.phone != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.phone_outlined,
                                            size: 14,
                                            color: DarbakColors.textSecondary,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            bid.phone ?? '',
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (bid.licenseNo != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.badge_outlined,
                                            size: 14,
                                            color: DarbakColors.textSecondary,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'رخصة: ${bid.licenseNo}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (bid.driverRating != null &&
                                      bid.ratingCount > 0)
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.star_rounded,
                                          size: 14,
                                          color: Colors.amber,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${bid.driverRating!.toStringAsFixed(1)} ⭐ (${bid.ratingCount} تقييم)',
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Bid details: Amount + ETA
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'السعر المعروض',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: DarbakColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  SarPrice(
                                    amount: bid.bidAmount,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: DarbakColors.primaryGreen,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'الموعد المقدر',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: DarbakColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${bid.estimatedDays} أيام',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _comparisonLabel(bid.bidAmount),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: DarbakColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Accept button - only show for pending bids
                          if (bid.bidStatus == 'pending' &&
                              _acceptedBidId == null)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _acceptingBidId == bid.id
                                    ? null
                                    : () => _acceptBid(bid.id),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: DarbakColors.primaryGreen,
                                  disabledBackgroundColor: Colors.grey.shade300,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                child: _acceptingBidId == bid.id
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : const Text(
                                        'قبول العرض',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          // Show accepted status
                          if (isAccepted)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.green,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'تم قبول هذا العرض',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // Show rejected status
                          if (isRejected)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.cancel_rounded,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'تم رفض هذا العرض',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

/// مسار مضغوط لشريط التطبيق: نقطة استلام (أخضر) — خط متقطع — نقطة تسليم (برتقالي)، بدون رموز أسهم.
class _ShipmentBidsAppBarRoute extends StatelessWidget {
  const _ShipmentBidsAppBarRoute({
    required this.pickupAddress,
    required this.dropoffAddress,
  });

  final String? pickupAddress;
  final String? dropoffAddress;

  @override
  Widget build(BuildContext context) {
    final from = shipmentCitySegment(pickupAddress);
    final to = shipmentCitySegment(dropoffAddress);

    return Semantics(
      container: true,
      label: 'مسار الشحنة من $from إلى $to',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: DarbakColors.lightGreen.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(DarbakRadius.pill),
          border: Border.all(color: DarbakColors.borderSoft),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Row(
              children: [
                const _ShipmentRouteDot(color: DarbakColors.primaryGreen),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    from,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: DarbakTypography.style(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: DarbakColors.primaryGreen,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: SizedBox(
                    width: 28,
                    height: 10,
                    child: CustomPaint(
                      painter: _HorizontalDashedLinePainter(
                        color: DarbakColors.textSecondary.withValues(alpha: 0.42),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    to,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.left,
                    style: DarbakTypography.style(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: DarbakColors.orange,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                const _ShipmentRouteDot(color: DarbakColors.orange),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShipmentRouteDot extends StatelessWidget {
  const _ShipmentRouteDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.28),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }
}

class _HorizontalDashedLinePainter extends CustomPainter {
  const _HorizontalDashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.65
      ..strokeCap = StrokeCap.round;
    const dash = 4.0;
    const gap = 3.5;
    var x = 0.0;
    while (x < size.width) {
      final end = (x + dash).clamp(0.0, size.width).toDouble();
      canvas.drawLine(Offset(x, y), Offset(end, y), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _HorizontalDashedLinePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
