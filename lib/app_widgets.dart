import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'widgets/profile_avatar.dart';

class DarbakSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color color;
  final Color borderColor;
  final double radius;
  final List<BoxShadow>? boxShadow;
  final double? width;

  const DarbakSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(DarbakSpacing.lg),
    this.margin,
    this.color = DarbakColors.card,
    this.borderColor = DarbakColors.borderSoft,
    this.radius = DarbakRadius.lg,
    this.boxShadow,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
        boxShadow: boxShadow ?? DarbakShadows.soft,
      ),
      child: child,
    );
  }
}

class DarbakPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconAlignment iconAlignment;

  /// When set (e.g. `0.82`), the button uses this fraction of the parent’s max
  /// width and stays centered — used on auth screens to match design margins.
  final double? widthFactor;

  const DarbakPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.iconAlignment = IconAlignment.end,
    this.widthFactor,
  });

  @override
  Widget build(BuildContext context) {
    final inner = SizedBox(
      height: 52,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null && iconAlignment == IconAlignment.start) ...[
              Icon(icon, size: 22),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (icon != null && iconAlignment == IconAlignment.end) ...[
              const SizedBox(width: 8),
              Icon(icon, size: 22),
            ],
          ],
        ),
      ),
    );
    final f = widthFactor;
    if (f != null) {
      return FractionallySizedBox(
        widthFactor: f.clamp(0.2, 1.0),
        alignment: Alignment.center,
        child: inner,
      );
    }
    return inner;
  }
}

class DarbakOutlinedButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const DarbakOutlinedButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: DarbakColors.primaryGreen),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: DarbakColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class DarbakSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const DarbakSectionTitle({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          textAlign: TextAlign.start,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: DarbakColors.dark,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            textAlign: TextAlign.start,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: DarbakColors.textSecondary),
          ),
        ],
      ],
    );
  }
}

class DarbakAuthTextField extends StatelessWidget {
  final String hint;
  final TextEditingController controller;
  final bool isPassword;
  final TextInputType keyboardType;
  final IconData? prefixIcon;

  const DarbakAuthTextField({
    super.key,
    required this.hint,
    required this.controller,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      textAlign: TextAlign.start,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: DarbakColors.primary)
            : null,
      ),
    );
  }
}

/// Shared logout control for driver and shipper profiles (same size, color, icon).
class DarbakLogoutBarButton extends StatelessWidget {
  final VoidCallback onPressed;

  const DarbakLogoutBarButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,

        label: Text(
          'تسجيل الخروج',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade400,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class DarbakProfileAvatar extends StatelessWidget {
  final IconData icon;

  const DarbakProfileAvatar({super.key, this.icon = Icons.person_rounded});

  @override
  Widget build(BuildContext context) {
    return ProfileAvatar(
      role: icon == Icons.domain_rounded ? 'shipper' : 'driver',
    );
  }
}
