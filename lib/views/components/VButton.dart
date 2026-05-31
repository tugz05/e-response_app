import 'package:flutter/material.dart';
import 'package:e_response_app_nemsu/theme/app_theme.dart';
import 'package:e_response_app_nemsu/views/components/press_scale.dart';

class VButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;
  final Color? textColor;
  final Color outlineBorderColor;
  final IconData? icon;
  final double width;
  final bool isOutlined;
  final bool isLoading;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;

  const VButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.icon,
    this.textColor = AppColors.primary,
    this.outlineBorderColor = AppColors.primary,
    this.width = double.infinity,
    this.isOutlined = false,
    this.isLoading = false,
    this.padding = const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final Color baseColor =
        isOutlined
            ? Colors.transparent
            : (backgroundColor ?? AppColors.primary);
    final Color buttonTextColor =
        isOutlined ? (textColor ?? AppColors.primary) : Colors.white;

    return Center(
      child: PressScale(
        enabled: !isLoading,
        child: SizedBox(
          width: width,
          child: InkWell(
            onTap: isLoading ? null : onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              padding: padding,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isOutlined ? outlineBorderColor : AppColors.primary,
                  width: isOutlined ? 1.5 : 0,
                ),
                boxShadow:
                    isOutlined
                        ? const []
                        : const [
                          BoxShadow(
                            color: AppColors.shadowPrimary,
                            blurRadius: 14,
                            offset: Offset(0, 6),
                          ),
                        ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isLoading)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: isOutlined ? AppColors.primary : Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  else
                    Text(
                      text,
                      style: TextStyle(
                        color: buttonTextColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (icon != null && !isLoading) ...[
                    const SizedBox(width: 8),
                    Icon(icon, color: buttonTextColor, size: 18),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
