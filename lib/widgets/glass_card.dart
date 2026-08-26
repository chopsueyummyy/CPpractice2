import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final Color? color;
  final Color? borderColor;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 16.0,
    this.blur = 20.0,
    this.color,
    this.borderColor,
    this.padding,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Auto-adjust default glass colors for Light vs Dark mode
    final defaultColor = isDark 
        ? Colors.black.withOpacity(0.25) 
        : Colors.white.withOpacity(0.45);
        
    final defaultBorder = isDark 
        ? Colors.white.withOpacity(0.12) 
        : Colors.white.withOpacity(0.35);

    final themeColor = color ?? defaultColor;
    final themeBorder = borderColor ?? defaultBorder;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: themeColor,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: themeBorder,
                width: 1.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
