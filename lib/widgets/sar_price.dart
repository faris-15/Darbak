import 'package:flutter/material.dart';

import '../utils/sar_formatter.dart';

class SarIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const SarIcon({super.key, this.size = 18, this.color});

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? IconTheme.of(context).color;

    return ImageIcon(
      const AssetImage('assets/icons/saudi_riyal.png'),
      size: size,
      color: iconColor,
    );
  }
}

class SarPrice extends StatelessWidget {
  final dynamic amount;
  final int decimalDigits;
  final TextStyle? style;
  final Color? color;
  final double? iconSize;
  final MainAxisSize mainAxisSize;

  const SarPrice({
    super.key,
    required this.amount,
    this.decimalDigits = 2,
    this.style,
    this.color,
    this.iconSize,
    this.mainAxisSize = MainAxisSize.min,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style ?? DefaultTextStyle.of(context).style;
    final effectiveColor = color ?? effectiveStyle.color;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: mainAxisSize,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SarIcon(
            size: iconSize ?? effectiveStyle.fontSize ?? 18,
            color: effectiveColor,
          ),
          const SizedBox(width: 5),
          Text(
            SarFormatter.formatAmount(amount, decimalDigits: decimalDigits),
            style: effectiveStyle.copyWith(color: effectiveColor),
          ),
        ],
      ),
    );
  }
}
