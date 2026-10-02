import 'package:flutter/material.dart';

import '../core/theme.dart';

InputBorder _border(Color color) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: color),
  );
}

const InputDecoration nxDecoration = InputDecoration(
  filled: true,
  fillColor: NxColors.field,
  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
  labelStyle: TextStyle(color: NxColors.muted, fontSize: 15),
  hintStyle: TextStyle(color: NxColors.faint, fontSize: 15),
  errorStyle: TextStyle(color: Color(0xFFFF8A8F), fontSize: 12.5),
);

class NxField extends StatelessWidget {
  const NxField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.initialValue,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.maxLines = 1,
    this.maxLength,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.prefixIcon,
    this.suffixIcon,
    this.enabled = true,
    this.readOnly = false,
    this.autocorrect = false,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController? controller;
  final String label;
  final String? hint;
  final String? initialValue;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final int maxLines;
  final int? maxLength;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool enabled;
  final bool readOnly;
  final bool autocorrect;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      maxLines: maxLines,
      maxLength: maxLength,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      enabled: enabled,
      readOnly: readOnly,
      autocorrect: autocorrect,
      textCapitalization: textCapitalization,
      style: const TextStyle(color: NxColors.text, fontSize: 15, height: 1.3),
      decoration: nxDecoration.copyWith(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        enabledBorder: _border(NxColors.line),
        focusedBorder: _border(NxColors.brand),
        errorBorder: _border(NxColors.danger),
        focusedErrorBorder: _border(NxColors.danger),
        disabledBorder: _border(const Color(0xFF1A222D)),
        floatingLabelStyle: const TextStyle(
          color: NxColors.brand,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// A tap-to-pick field rendered as a bottom sheet. Avoids version-sensitive
/// dropdown theming and feels better on a phone.
class NxDropdown extends StatelessWidget {
  const NxDropdown({
    super.key,
    required this.label,
    required this.items,
    this.value,
    this.onChanged,
    this.hint = 'Select',
  });

  final String label;
  final List<String> items;
  final String? value;
  final ValueChanged<String>? onChanged;
  final String hint;

  Future<void> _openPicker(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: NxColors.cardRaised,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          padding: const EdgeInsets.only(bottom: 18),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 14),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: NxColors.line,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: NxColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: items.length,
                    itemBuilder: (itemContext, index) {
                      final item = items[index];
                      final isCurrent = item == value;
                      return InkWell(
                        onTap: () => Navigator.of(itemContext).pop(item),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 13,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item,
                                  style: TextStyle(
                                    color: isCurrent
                                        ? NxColors.brand
                                        : NxColors.text,
                                    fontSize: 15,
                                    fontWeight: isCurrent
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (isCurrent)
                                const Icon(
                                  Icons.check_rounded,
                                  size: 18,
                                  color: NxColors.brand,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null) onChanged?.call(selected);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openPicker(context),
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: nxDecoration.copyWith(
          labelText: label,
          enabledBorder: _border(NxColors.line),
          focusedBorder: _border(NxColors.brand),
          floatingLabelStyle: const TextStyle(
            color: NxColors.brand,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value ?? hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: value == null ? NxColors.faint : NxColors.text,
                  fontSize: 15,
                ),
              ),
            ),
            const Icon(
              Icons.expand_more_rounded,
              size: 20,
              color: NxColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}
