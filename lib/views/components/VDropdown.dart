import 'package:flutter/material.dart';
import 'package:e_response_app_nemsu/theme/app_theme.dart';

class VDropdown extends StatefulWidget {
  final String hintText;
  final String? headerText;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const VDropdown({
    Key? key,
    required this.hintText,
    this.headerText,
    this.value,
    required this.items,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<VDropdown> createState() => _VDropdownState();
}

class _VDropdownState extends State<VDropdown> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.headerText != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                widget.headerText!,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          DropdownButtonFormField<String>(
            value: widget.value,
            decoration: InputDecoration(hintText: widget.hintText),
            icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
            items:
                widget.items.map((String item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(
                      item,
                      style: const TextStyle(fontFamily: 'Roboto'),
                    ),
                  );
                }).toList(),
            onChanged: widget.onChanged,
          ),
        ],
      ),
    );
  }
}
