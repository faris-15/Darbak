import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../truck_classification_models.dart';
import '../truck_classification_service.dart';
import 'truck_classification_dropdowns.dart';

/// Reusable card-based truck configuration form (registration, fleet, edit).
class TruckConfigurationForm extends StatefulWidget {
  const TruckConfigurationForm({
    super.key,
    this.initialGroup,
    this.initialCategoryId,
    this.initialAxleCount,
    this.initialBodyTypeId,
    this.initialCapacityId,
    this.onChanged,
    this.formKey,
    this.showSummary = true,
  });

  final TruckGroup? initialGroup;
  final String? initialCategoryId;
  final int? initialAxleCount;
  final String? initialBodyTypeId;
  final String? initialCapacityId;
  final ValueChanged<TruckConfiguration?>? onChanged;
  final GlobalKey<FormState>? formKey;
  final bool showSummary;

  @override
  State<TruckConfigurationForm> createState() => TruckConfigurationFormState();
}

class TruckConfigurationFormState extends State<TruckConfigurationForm> {
  final _innerFormKey = GlobalKey<FormState>();
  final _service = const TruckClassificationService();
  late TruckGroup? _group;
  late String? _categoryId;
  late int? _axleCount;
  late String? _bodyTypeId;
  late String? _capacityId;

  @override
  void initState() {
    super.initState();
    _group = widget.initialGroup;
    _categoryId = widget.initialCategoryId;
    _axleCount = widget.initialAxleCount;
    _bodyTypeId = widget.initialBodyTypeId;
    _capacityId = widget.initialCapacityId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifyParent());
  }

  @override
  void didUpdateWidget(covariant TruckConfigurationForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCategoryId != widget.initialCategoryId ||
        oldWidget.initialGroup != widget.initialGroup) {
      _group = widget.initialGroup;
      _categoryId = widget.initialCategoryId;
      _axleCount = widget.initialAxleCount;
      _bodyTypeId = widget.initialBodyTypeId;
      _capacityId = widget.initialCapacityId;
    }
  }

  TruckConfiguration? get configuration => _service.resolveConfiguration(
    group: _group,
    categoryId: _categoryId,
    axleCount: _axleCount,
    bodyTypeId: _bodyTypeId,
    capacityId: _capacityId,
  );

  String? validate() {
    return _service.validateSelection(
      group: _group,
      categoryId: _categoryId,
      axleCount: _axleCount,
      bodyTypeId: _bodyTypeId,
      capacityId: _capacityId,
    );
  }

  bool validateAll() {
    final formOk = _innerFormKey.currentState?.validate() ?? false;
    return formOk && validate() == null;
  }

  void _notifyParent() => widget.onChanged?.call(configuration);

  void _onGroupChanged(TruckGroup? group) {
    setState(() {
      _group = group;
      _categoryId = null;
      _axleCount = null;
      _bodyTypeId = null;
      _capacityId = null;
    });
    _notifyParent();
  }

  void _onCategoryChanged(String? categoryId) {
    final category = _service.categoryById(categoryId);
    setState(() {
      _categoryId = categoryId;
      _axleCount = category?.axleCounts.length == 1
          ? category!.axleCounts.first
          : null;
      _bodyTypeId = category?.bodyTypeIds.length == 1
          ? category!.defaultBodyTypeId
          : null;
      _capacityId = category?.capacities.length == 1
          ? category!.capacities.first.id
          : null;
    });
    _notifyParent();
  }

  void _onAxleChanged(int? value) {
    setState(() => _axleCount = value);
    _notifyParent();
  }

  void _onBodyChanged(String? value) {
    setState(() => _bodyTypeId = value);
    _notifyParent();
  }

  void _onCapacityChanged(String? value) {
    setState(() => _capacityId = value);
    _notifyParent();
  }

  @override
  Widget build(BuildContext context) {
    final category = _service.categoryById(_categoryId);
    final categories = _service.categoriesForGroup(_group);
    final config = configuration;

    return Form(
      key: widget.formKey ?? _innerFormKey,
      child: Card(
        elevation: 0,
        color: DarbakColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: DarbakColors.borderSoft),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.local_shipping, color: DarbakColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'تصنيف الشاحنة',
                    style: DarbakTypography.style(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: DarbakColors.text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'اختر المجموعة ثم الفئة — تظهر الخيارات المتوافقة فقط',
                style: DarbakTypography.style(
                  fontSize: 13,
                  color: DarbakColors.subText,
                ),
              ),
              const SizedBox(height: 14),
              TruckGroupDropdown(
                value: _group,
                onChanged: _onGroupChanged,
                validator: (v) =>
                    v == null ? 'مجموعة الشاحنة مطلوبة' : null,
              ),
              const SizedBox(height: 12),
              TruckCategoryDropdown(
                categories: categories,
                value: _categoryId,
                enabled: _group != null,
                onChanged: _onCategoryChanged,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'فئة الشاحنة مطلوبة' : null,
              ),
              if (category != null) ...[
                const SizedBox(height: 12),
                TruckAxleDropdown(
                  axleCounts: _service.axleOptions(category),
                  value: _axleCount,
                  enabled: category.axleCounts.length > 1,
                  onChanged: _onAxleChanged,
                  validator: (v) => v == null ? 'عدد المحاور مطلوب' : null,
                ),
                const SizedBox(height: 12),
                TruckBodyTypeDropdown(
                  bodyTypes: _service.bodyTypeOptions(category),
                  value: _bodyTypeId,
                  enabled: category.bodyTypeIds.length > 1,
                  onChanged: _onBodyChanged,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'نوع الهيكل مطلوب' : null,
                ),
                const SizedBox(height: 12),
                TruckCapacityDropdown(
                  capacities: _service.capacityOptions(category),
                  value: _capacityId,
                  enabled: category.capacities.length > 1,
                  onChanged: _onCapacityChanged,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'الحمولة مطلوبة' : null,
                ),
              ],
              if (widget.showSummary && config != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: DarbakColors.lightGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: DarbakColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          config.displayLabelAr,
                          style: DarbakTypography.style(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: DarbakColors.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
