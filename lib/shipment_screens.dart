import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'api_service.dart';

/// شاشة سوق الشحنات للسائق
class DriverShipmentsMarketScreen extends StatefulWidget {
  const DriverShipmentsMarketScreen({super.key});

  @override
  State<DriverShipmentsMarketScreen> createState() => _DriverShipmentsMarketScreenState();
}

class _DriverShipmentsMarketScreenState extends State<DriverShipmentsMarketScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _shipments = [];

  @override
  void initState() {
    super.initState();
    _loadShipments();
  }

  Future<void> _loadShipments() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final shipments = await ApiService.getShipments();
      _shipments = shipments.map((s) => s as Map<String, dynamic>).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _showBidDialog(Map<String, dynamic> shipment) async {
    final _formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final etaController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('قدم عرض سعر'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: amountController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'المبلغ (ريال)'),
                validator: (value) => (value == null || value.isEmpty) ? 'أدخل مبلغ' : null,
              ),
              TextFormField(
                controller: etaController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'الايام المقدرة'),
                validator: (value) => (value == null || value.isEmpty) ? 'أدخل عدد الأيام' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState?.validate() ?? false) {
                final amount = double.tryParse(amountController.text.trim()) ?? 0;
                final days = int.tryParse(etaController.text.trim()) ?? 0;
                await ApiService.placeBid({
                  'shipmentId': shipment['id'],
                  'driverId': 2,
                  'bidAmount': amount,
                  'estimatedDays': days,
                });
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال العرض بنجاح')));
                Navigator.pop(context, true);
              }
            },
            child: const Text('إرسال العرض'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _loadShipments();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('خطأ: $_error'));
    }

    if (_shipments.isEmpty) {
      return const Center(
        child: Text('لا توجد شحنات متاحة حالياً'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _shipments.length,
      itemBuilder: (context, index) {
        final shipment = _shipments[index];

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('شحنة #${shipment['id']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('من: ${shipment['pickup_address'] ?? '-'}'),
                Text('إلى: ${shipment['dropoff_address'] ?? '-'}'),
                Text('الوزن (كجم): ${shipment['weight_kg']}'),
                Text('السعر الأساسي: ${shipment['base_price']}'),
                Text('حالة الطلب: ${shipment['status']}'),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => _showBidDialog(shipment),
                  child: const Text('قدم عرضًا'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// شاشة عرض العروض للمُرسل
class ShipperBidsListScreen extends StatefulWidget {
  const ShipperBidsListScreen({super.key});

  @override
  State<ShipperBidsListScreen> createState() => _ShipperBidsListScreenState();
}

class _ShipperBidsListScreenState extends State<ShipperBidsListScreen> {
  final _shipmentIdController = TextEditingController(text: '1');
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _bids = [];

  Future<void> _loadBids() async {
    setState(() {
      _loading = true;
      _error = null;
      _bids = [];
    });

    final shipmentId = int.tryParse(_shipmentIdController.text);
    if (shipmentId == null) {
      setState(() {
        _error = 'رقم الشحنة غير صالح';
        _loading = false;
      });
      return;
    }

    try {
      final bids = await ApiService.getBids(shipmentId);
      _bids = bids.map((b) => b as Map<String, dynamic>).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('عروض السائقين')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _shipmentIdController,
                    decoration: const InputDecoration(labelText: 'رقم الشحنة'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(onPressed: _loadBids, child: const Text('جلب العروض')),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading) const CircularProgressIndicator(),
            if (_error != null) Text('خطأ: $_error', style: const TextStyle(color: Colors.red)),
            if (!_loading && _bids.isEmpty)
              const Text('لا يوجد عروض حتى الآن', style: TextStyle(color: DarbakColors.textSecondary)),
            if (!_loading && _bids.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _bids.length,
                  itemBuilder: (context, index) {
                    final bid = _bids[index];
                    final isBest = index == 0;
                    return Card(
                      color: isBest ? Colors.green.shade50 : null,
                      child: ListTile(
                        title: Text('عرض ${bid['bid_amount']} ريال'),
                        subtitle: Text('السائق: ${bid['driver_id']} - ETA: ${bid['estimated_days']} يوم\nالحالة: ${bid['bid_status']}'),
                        trailing: isBest ? const Text('الأفضل', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)) : null,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

