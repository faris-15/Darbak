import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'api_service.dart';
import 'models/bid_model.dart';

/// شاشة تفاصيل عروض الشحنة للشاحن
class ShipmentBidsDetailScreen extends StatefulWidget {
  final int shipmentId;
  final String shipmentTitle;

  const ShipmentBidsDetailScreen({
    required this.shipmentId,
    required this.shipmentTitle,
    super.key,
  });

  @override
  State<ShipmentBidsDetailScreen> createState() => _ShipmentBidsDetailScreenState();
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

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم قبول العرض بنجاح'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Go back after a short delay
        Future.delayed(const Duration(seconds: 2), () {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('عروض ${widget.shipmentTitle}'),
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
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
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
                          final isBestBid = index == 0; // Lowest bid is best
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
                                            if (isBestBid)
                                              const Padding(
                                                padding: EdgeInsets.only(top: 4),
                                                child: Text(
                                                  '✨ أفضل عرض',
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
                                          color: _getStatusColor(bid.bidStatus).withOpacity(0.1),
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
                                                    style: const TextStyle(fontSize: 13),
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
                                                    style: const TextStyle(fontSize: 13),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          if (bid.driverRating != null)
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.star_rounded,
                                                  size: 14,
                                                  color: Colors.amber,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  '${bid.driverRating!.toStringAsFixed(1)} ⭐ (${bid.ratingCount ?? 0} تقييم)',
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
                                          Text(
                                            '${bid.bidAmount.toStringAsFixed(2)} ريال',
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
                                  const SizedBox(height: 12),
                                  // Accept button - only show for pending bids
                                  if (bid.bidStatus == 'pending' && _acceptedBidId == null)
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: _acceptingBidId == bid.id
                                            ? null
                                            : () => _acceptBid(bid.id),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: DarbakColors.primaryGreen,
                                          disabledBackgroundColor: Colors.grey.shade300,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                        child: _acceptingBidId == bid.id
                                            ? const SizedBox(
                                                height: 20,
                                                width: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(
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
