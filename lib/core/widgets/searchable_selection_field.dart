import 'package:flutter/material.dart';
import 'package:asset_pulse_pro/core/constants/app_colors.dart';

/// Item definition for SearchableSelectionField
class SearchableItem<T> {
  final T value;
  final String label;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;

  const SearchableItem({
    required this.value,
    required this.label,
    this.subtitle,
    this.leading,
    this.trailing,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchableItem &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// A search-enabled dropdown selection field for large lists (Panels, Feeders, Locations, Types, etc.)
class SearchableSelectionField<T> extends FormField<T> {
  final String label;
  final String? hintText;
  final String? helperText;
  final T? selectedValue;
  final List<SearchableItem<T>> items;
  final ValueChanged<T?> onChanged;
  final IconData? prefixIcon;
  final bool allowClear;
  final bool isSearchable;
  final bool isGlass;

  SearchableSelectionField({
    super.key,
    required this.label,
    required this.items,
    required this.onChanged,
    this.selectedValue,
    this.hintText,
    this.helperText,
    this.prefixIcon,
    this.allowClear = true,
    this.isSearchable = true,
    this.isGlass = false,
    super.validator,
    super.onSaved,
    super.enabled = true,
    super.autovalidateMode,
  }) : super(
          initialValue: selectedValue,
          builder: (FormFieldState<T> state) {
            return _SearchableSelectionFieldWidget<T>(
              fieldState: state,
              label: label,
              items: items,
              selectedValue: selectedValue,
              onChanged: (val) {
                state.didChange(val);
                onChanged(val);
              },
              hintText: hintText,
              helperText: helperText,
              prefixIcon: prefixIcon,
              allowClear: allowClear,
              isSearchable: isSearchable,
              isGlass: isGlass,
              enabled: enabled,
            );
          },
        );
}

class _SearchableSelectionFieldWidget<T> extends StatelessWidget {
  final FormFieldState<T> fieldState;
  final String label;
  final String? hintText;
  final String? helperText;
  final T? selectedValue;
  final List<SearchableItem<T>> items;
  final ValueChanged<T?> onChanged;
  final IconData? prefixIcon;
  final bool allowClear;
  final bool isSearchable;
  final bool isGlass;
  final bool enabled;

  const _SearchableSelectionFieldWidget({
    required this.fieldState,
    required this.label,
    required this.items,
    required this.selectedValue,
    required this.onChanged,
    this.hintText,
    this.helperText,
    this.prefixIcon,
    this.allowClear = true,
    this.isSearchable = true,
    this.isGlass = false,
    this.enabled = true,
  });

  SearchableItem<T>? get _selectedItem {
    final currentVal = selectedValue ?? fieldState.value;
    if (currentVal == null) return null;
    try {
      return items.firstWhere((item) => item.value == currentVal);
    } catch (_) {
      if (currentVal is String && (currentVal as String).trim().isNotEmpty) {
        return SearchableItem<T>(value: currentVal, label: currentVal as String);
      }
      return null;
    }
  }

  void _openSelectionModal(BuildContext context) {
    if (!enabled) return;
    FocusScope.of(context).unfocus();

    final selected = _selectedItem;
    final modalItems = List<SearchableItem<T>>.from(items);
    if (selected != null && !modalItems.any((it) => it.value == selected.value)) {
      modalItems.insert(0, selected);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return _SearchSelectionBottomSheet<T>(
          title: label,
          items: modalItems,
          selectedItem: selected,
          onSelected: (item) {
            Navigator.pop(modalCtx);
            onChanged(item?.value);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final item = _selectedItem;
    final hasError = fieldState.hasError;

    return Padding(
      padding: EdgeInsets.only(bottom: isGlass ? 0 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: enabled ? () => _openSelectionModal(context) : null,
            borderRadius: BorderRadius.circular(isGlass ? 12 : 8),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: label,
                floatingLabelBehavior: FloatingLabelBehavior.always,
                helperText: helperText,
                errorText: hasError ? fieldState.errorText : null,
                border: isGlass ? InputBorder.none : const OutlineInputBorder(),
                enabledBorder: isGlass ? InputBorder.none : null,
                focusedBorder: isGlass ? InputBorder.none : null,
                prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (allowClear && item != null && enabled)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: 'Clear selection',
                        onPressed: () => onChanged(null),
                      ),
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(Icons.search, size: 20, color: AppColors.accent),
                    ),
                  ],
                ),
                filled: !enabled && !isGlass,
                fillColor: !enabled && !isGlass ? (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04)) : null,
              ),
              isEmpty: item == null,
              child: item != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            item.subtitle!,
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    )
                  : Text(
                      hintText ?? 'Tap to search & select $label',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: theme.hintColor,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchSelectionBottomSheet<T> extends StatefulWidget {
  final String title;
  final List<SearchableItem<T>> items;
  final SearchableItem<T>? selectedItem;
  final ValueChanged<SearchableItem<T>?> onSelected;

  const _SearchSelectionBottomSheet({
    required this.title,
    required this.items,
    required this.selectedItem,
    required this.onSelected,
  });

  @override
  State<_SearchSelectionBottomSheet<T>> createState() => _SearchSelectionBottomSheetState<T>();
}

class _SearchSelectionBottomSheetState<T> extends State<_SearchSelectionBottomSheet<T>> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);

    final filteredItems = widget.items.where((item) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase().trim();
      final labelMatch = item.label.toLowerCase().contains(query);
      final subMatch = item.subtitle?.toLowerCase().contains(query) ?? false;
      final valMatch = item.value.toString().toLowerCase().contains(query);
      return labelMatch || subMatch || valMatch;
    }).toList();

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 580,
            maxHeight: mediaQuery.size.height * 0.82,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top drag bar & Header
                const SizedBox(height: 10),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),

                // Title and count
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select ${widget.title}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${filteredItems.length} available items',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Search Bar Field
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _searchController,
                    autofocus: false,
                    decoration: InputDecoration(
                      hintText: 'Search ${widget.title} by name, ID, type...',
                      hintStyle: const TextStyle(fontSize: 13),
                      prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.accent),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),

              const SizedBox(height: 8),
              const Divider(height: 1),

              // Items List
              Expanded(
                child: filteredItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off, size: 48, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                            const SizedBox(height: 10),
                            Text(
                              'No matching results for "$_searchQuery"',
                              style: TextStyle(
                                fontSize: 13.5,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Clear search filter'),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: filteredItems.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                        ),
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          final isSelected = widget.selectedItem?.value == item.value;

                          return Material(
                            color: isSelected
                                ? AppColors.accent.withValues(alpha: 0.12)
                                : Colors.transparent,
                            child: ListTile(
                              leading: item.leading ??
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.accent.withValues(alpha: 0.2)
                                          : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isSelected ? Icons.check : Icons.label_outline,
                                      size: 16,
                                      color: isSelected ? AppColors.accent : (isDark ? Colors.white70 : Colors.black54),
                                    ),
                                  ),
                              title: Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? AppColors.accent : theme.colorScheme.onSurface,
                                ),
                              ),
                              subtitle: item.subtitle != null && item.subtitle!.isNotEmpty
                                  ? Text(
                                      item.subtitle!,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                      ),
                                    )
                                  : null,
                              trailing: isSelected
                                  ? const Icon(Icons.check_circle, size: 18, color: AppColors.accent)
                                  : item.trailing,
                              onTap: () => widget.onSelected(item),
                            ),
                          );
                        },
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
