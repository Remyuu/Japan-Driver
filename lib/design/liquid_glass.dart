import 'dart:ui';

import 'package:flutter/material.dart';

class LiquidColors {
  const LiquidColors._();

  static const primary = Color(0xFF087C73);
  static const primaryDeep = Color(0xFF075E59);
  static const sky = Color(0xFF4A8FD8);
  static const amber = Color(0xFFE1A93C);
  static const vermilion = Color(0xFFD75D4A);
  static const success = Color(0xFF248A55);
  static const danger = Color(0xFFB9413C);
  static const ink = Color(0xFF18201E);
  static const paper = Color(0xFFF6F7F3);

  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static Color pageTop(BuildContext context) {
    return isDark(context) ? const Color(0xFF101513) : const Color(0xFFF9FAF6);
  }

  static Color pageBottom(BuildContext context) {
    return isDark(context) ? const Color(0xFF161D20) : const Color(0xFFEFF6F4);
  }

  static Color glassFill(BuildContext context, {bool strong = false}) {
    if (isDark(context)) {
      return Color(0xFF202827).withValues(alpha: strong ? 0.82 : 0.66);
    }
    return Colors.white.withValues(alpha: strong ? 0.82 : 0.62);
  }

  static Color glassBorder(BuildContext context) {
    return isDark(context)
        ? Colors.white.withValues(alpha: 0.13)
        : Colors.white.withValues(alpha: 0.74);
  }

  static Color hairline(BuildContext context) {
    return isDark(context)
        ? Colors.white.withValues(alpha: 0.12)
        : const Color(0xFFDCE5E1);
  }

  static Color muted(BuildContext context) {
    return isDark(context) ? const Color(0xFFB9C4C1) : const Color(0xFF65716D);
  }
}

class LiquidBackground extends StatelessWidget {
  const LiquidBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = LiquidColors.isDark(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            LiquidColors.pageTop(context),
            if (isDark) const Color(0xFF152022) else const Color(0xFFF4F8F1),
            LiquidColors.pageBottom(context),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _LiquidRoadPainter(isDark: isDark)),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class LiquidGlass extends StatelessWidget {
  const LiquidGlass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.strong = false,
    this.borderRadius = 8,
    this.tint,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool strong;
  final double borderRadius;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final fill = tint ?? LiquidColors.glassFill(context, strong: strong);
    final shadowColor = LiquidColors.isDark(context)
        ? Colors.black.withValues(alpha: 0.22)
        : const Color(0xFF36534E).withValues(alpha: 0.10);

    Widget current = Padding(padding: padding, child: child);
    if (onTap != null) {
      current = Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, borderRadius: radius, child: current),
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: radius,
            border: Border.all(color: LiquidColors.glassBorder(context)),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: current,
        ),
      ),
    );
  }
}

class LiquidDialogPanel extends StatelessWidget {
  const LiquidDialogPanel({
    super.key,
    required this.child,
    this.maxWidth = 360,
    this.padding = const EdgeInsets.all(16),
    this.alignment = Alignment.topRight,
    this.insetPadding = const EdgeInsets.fromLTRB(16, 56, 16, 16),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final AlignmentGeometry alignment;
  final EdgeInsets insetPadding;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      alignment: alignment,
      insetPadding: insetPadding,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: LiquidGlass(padding: padding, strong: true, child: child),
      ),
    );
  }
}

class LiquidIconBadge extends StatelessWidget {
  const LiquidIconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 42,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: LiquidColors.isDark(context) ? 0.22 : 0.13,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Icon(icon, color: color, size: size * 0.52),
    );
  }
}

class LiquidMetric extends StatelessWidget {
  const LiquidMetric({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      padding: const EdgeInsets.all(14),
      strong: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LiquidIconBadge(icon: icon, color: color, size: 34),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: LiquidColors.muted(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LiquidSectionLabel extends StatelessWidget {
  const LiquidSectionLabel({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: LiquidColors.muted(context),
            ),
          ),
        ],
      ],
    );
  }
}

class _LiquidRoadPainter extends CustomPainter {
  const _LiquidRoadPainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = (isDark ? Colors.white : LiquidColors.primary).withValues(
        alpha: isDark ? 0.045 : 0.055,
      );
    final path = Path()
      ..moveTo(size.width * 0.08, 0)
      ..cubicTo(
        size.width * 0.26,
        size.height * 0.20,
        size.width * 0.18,
        size.height * 0.58,
        size.width * 0.42,
        size.height,
      );
    canvas.drawPath(path, paint);

    final paintTwo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = (isDark ? LiquidColors.sky : LiquidColors.amber).withValues(
        alpha: isDark ? 0.055 : 0.075,
      );
    final pathTwo = Path()
      ..moveTo(size.width * 0.86, 0)
      ..cubicTo(
        size.width * 0.78,
        size.height * 0.26,
        size.width * 0.92,
        size.height * 0.52,
        size.width * 0.66,
        size.height,
      );
    canvas.drawPath(pathTwo, paintTwo);
  }

  @override
  bool shouldRepaint(covariant _LiquidRoadPainter oldDelegate) {
    return oldDelegate.isDark != isDark;
  }
}
