import 'package:flutter/material.dart';

import '../app_theme.dart';

class ShipmentPath extends StatelessWidget {
  const ShipmentPath({
    super.key,
    required this.pickupCity,
    required this.dropoffCity,
    this.pathColor,
  });

  final String? pickupCity;
  final String? dropoffCity;
  final Color? pathColor;

  static const double _connectorHeight = 34;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pathColor = this.pathColor ?? theme.colorScheme.secondary;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: DarbakColors.lightGreen.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(DarbakRadius.md),
          border: Border.all(color: DarbakColors.borderSoft),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                const _PathPointIcon(
                  icon: Icons.my_location_rounded,
                  color: DarbakColors.primaryGreen,
                  semanticLabel: 'موقع الاستلام',
                ),
                _PathConnector(color: pathColor, height: _connectorHeight),
                const _PathPointIcon(
                  icon: Icons.location_on_rounded,
                  color: DarbakColors.orange,
                  semanticLabel: 'موقع التسليم',
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LocationLabel(
                    label: 'منطقة الاستلام',
                    cityName: _cleanLocation(pickupCity),
                    accentColor: DarbakColors.primaryGreen,
                  ),
                  const SizedBox(height: 34),
                  _LocationLabel(
                    label: 'منطقة التسليم',
                    cityName: _cleanLocation(dropoffCity),
                    accentColor: DarbakColors.orange,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _cleanLocation(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) {
      return '-';
    }
    return text;
  }
}

class _PathPointIcon extends StatelessWidget {
  const _PathPointIcon({
    required this.icon,
    required this.color,
    required this.semanticLabel,
  });

  final IconData icon;
  final Color color;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, size: 19, color: Colors.white),
      ),
    );
  }
}

class _PathConnector extends StatelessWidget {
  const _PathConnector({required this.color, required this.height});

  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: height,
      child: CustomPaint(
        size: Size(2, height),
        painter: _DashedLinePainter(color: color),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.72)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    const dashHeight = 5.0;
    const dashGap = 4.0;
    var startY = 0.0;
    final centerX = size.width / 2;

    while (startY < size.height) {
      final endY = (startY + dashHeight).clamp(0.0, size.height).toDouble();
      canvas.drawLine(Offset(centerX, startY), Offset(centerX, endY), paint);
      startY += dashHeight + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _LocationLabel extends StatelessWidget {
  const _LocationLabel({
    required this.label,
    required this.cityName,
    required this.accentColor,
  });

  final String label;
  final String cityName;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DarbakRadius.sm),
        border: Border.all(color: accentColor.withValues(alpha: 0.22)),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: DarbakTypography.style(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: accentColor,
              ),
            ),
            TextSpan(
              text: cityName,
              style: DarbakTypography.style(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: DarbakColors.text,
              ),
            ),
          ],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
