import 'package:e_response_app_nemsu/controllers/VTextFieldController.dart';
import 'package:flutter/material.dart';
import 'package:e_response_app_nemsu/theme/app_theme.dart';

class VTextField extends StatefulWidget {
  final String hintText;
  final bool isPassword;
  final String? headerText;
  final VTextFieldController? controller;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final int maxLines;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;
  final double topPadding;
  final double headerBottomSpacing;

  const VTextField({
    Key? key,
    required this.hintText,
    this.headerText,
    this.isPassword = false,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.maxLines = 1,
    this.enabled = true,
    this.onSubmitted,
    this.topPadding = 18,
    this.headerBottomSpacing = 8,
  }) : super(key: key);

  @override
  State<VTextField> createState() => _VTextFieldState();
}

class _VTextFieldState extends State<VTextField> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: widget.topPadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.headerText != null)
            Padding(
              padding: EdgeInsets.only(bottom: widget.headerBottomSpacing),
              child: Text(
                widget.headerText!,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          TextField(
            controller: widget.controller?.textController,
            enabled: widget.enabled,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            onSubmitted: widget.onSubmitted,
            maxLines: widget.isPassword ? 1 : widget.maxLines,
            obscureText:
                widget.isPassword
                    ? widget.controller?.obscureText ?? true
                    : false,
            decoration: InputDecoration(
              hintText: widget.hintText,
              suffixIcon:
                  widget.isPassword
                      ? IconButton(
                        icon: Icon(
                          widget.controller?.obscureText == true
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: AppColors.primary,
                        ),
                        onPressed: () {
                          setState(() {
                            widget.controller?.toggleObscureText();
                          });
                        },
                      )
                      : null,
            ),
          ),
        ],
      ),
    );
  }
}
