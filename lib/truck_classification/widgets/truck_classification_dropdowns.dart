import 'package:flutter/material.dart';

import '../truck_classification_models.dart';

class TruckGroupDropdown extends StatelessWidget {
  const TruckGroupDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.validator,
  });

  final TruckGroup? value;
  final ValueChanged<TruckGroup?> onChanged;
  final String? Function(TruckGroup?)? validator;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<TruckGroup>(
      initialValue: value,
      decoration: const InputDecoration(
        labelText: 'مجموعة الشاحنة',
        prefixIcon: Icon(Icons.local_shipping_outlined),
      ),
      items: TruckGroup.values
          .map(
            (g) => DropdownMenuItem(
              value: g,
              child: Text(g.labelAr, textAlign: TextAlign.start),
            ),
          )
          .toList(),
      onChanged: onChanged,
      validator: validator != null ? (_) => validator!(value) : null,
    );
  }
}

class TruckCategoryDropdown extends StatelessWidget {
  const TruckCategoryDropdown({
    super.key,
    required this.categories,
    required this.value,
    required this.onChanged,
    this.validator,
    this.enabled = true,
  });

  final List<TruckCategory> categories;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: categories.any((c) => c.id == value) ? value : null,
      decoration: const InputDecoration(
        labelText: 'فئة الشاحنة',
        prefixIcon: Icon(Icons.category_outlined),
      ),
      items: categories
          .map(
            (c) => DropdownMenuItem(
              value: c.id,
              child: Text(c.labelAr, textAlign: TextAlign.start),
            ),
          )
          .toList(),
      onChanged: enabled ? onChanged : null,
      validator: validator,
    );
  }
}

class TruckAxleDropdown extends StatelessWidget {
  const TruckAxleDropdown({
    super.key,
    required this.axleCounts,
    required this.value,
    required this.onChanged,
    this.validator,
    this.enabled = true,
  });

  final List<int> axleCounts;
  final int? value;
  final ValueChanged<int?> onChanged;
  final String? Function(int?)? validator;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: axleCounts.contains(value) ? value : null,
      decoration: const InputDecoration(
        labelText: 'عدد المحاور',
        prefixIcon: Icon(Icons.settings_ethernet),
      ),
      items: axleCounts
          .map(
            (count) => DropdownMenuItem(
              value: count,
              child: Text('$count محور', textAlign: TextAlign.start),
            ),
          )
          .toList(),
      onChanged: enabled ? onChanged : null,
      validator: validator,
    );
  }
}

class TruckBodyTypeDropdown extends StatelessWidget {
  const TruckBodyTypeDropdown({
    super.key,
    required this.bodyTypes,
    required this.value,
    required this.onChanged,
    this.validator,
    this.enabled = true,
  });

  final List<TruckBodyType> bodyTypes;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: bodyTypes.any((b) => b.id == value) ? value : null,
      decoration: const InputDecoration(
        labelText: 'نوع الهيكل',
        prefixIcon: Icon(Icons.inventory_2_outlined),
      ),
      items: bodyTypes
          .map(
            (b) => DropdownMenuItem(
              value: b.id,
              child: Text(b.labelAr, textAlign: TextAlign.start),
            ),
          )
          .toList(),
      onChanged: enabled ? onChanged : null,
      validator: validator,
    );
  }
}

class TruckCapacityDropdown extends StatelessWidget {
  const TruckCapacityDropdown({
    super.key,
    required this.capacities,
    required this.value,
    required this.onChanged,
    this.validator,
    this.enabled = true,
  });

  final List<TruckCapacity> capacities;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: capacities.any((c) => c.id == value) ? value : null,
      decoration: const InputDecoration(
        labelText: 'الحمولة القصوى',
        prefixIcon: Icon(Icons.scale_outlined),
      ),
      items: capacities
          .map(
            (c) => DropdownMenuItem(
              value: c.id,
              child: Text(c.labelAr, textAlign: TextAlign.start),
            ),
          )
          .toList(),
      onChanged: enabled ? onChanged : null,
      validator: validator,
    );
  }
}
