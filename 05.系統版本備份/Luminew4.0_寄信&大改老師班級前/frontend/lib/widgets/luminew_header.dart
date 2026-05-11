import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class LuminewHeader extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBackButton;
  final Color? textColor; // 新增：可選文字顏色
  final bool centerTitle; // 新增：是否置中
  final BorderRadius? borderRadius; // 新增：導角
  final bool usePositioned; // 新增：是否使用 Positioned 包裹

  const LuminewHeader({
    super.key,
    required this.title,
    this.actions,
    this.showBackButton = false,
    this.textColor,
    this.centerTitle = false,
    this.borderRadius,
    this.usePositioned = true, // 預設為 true 以保持相容性
  });

  @override
  Widget build(BuildContext context) {
    Widget content = ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 75,
          decoration: BoxDecoration(
            color: AppColors.headerPurpleGlass,
            borderRadius: borderRadius,
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.2),
                width: 0.5,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  if (showBackButton)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
                        onPressed: () => Navigator.pop(context),
                        color: textColor ?? const Color(0xFF675B83),
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                        splashRadius: 28,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: centerTitle
                          ? TextAlign.center
                          : TextAlign.start,
                      style: TextStyle(
                        color: textColor ?? const Color(0xFF675B83),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  if (actions != null) ...actions!,
                  if (centerTitle &&
                      showBackButton &&
                      (actions == null || actions!.isEmpty))
                    const SizedBox(width: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (!usePositioned) return content;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: content,
    );
  }
}
