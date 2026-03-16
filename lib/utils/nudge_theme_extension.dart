import 'package:flutter/material.dart';

class NudgeThemeExtension extends ThemeExtension<NudgeThemeExtension> {
  final Color? cardBg;
  final Color? cardBorder;
  final double? cardRadius;
  final double? cardBorderWidth;
  final List<BoxShadow>? cardShadow;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final Matrix4? cardTransform; // For "bouncy" or tilted looks
  final bool? showScanlines; // For Terminal theme

  final Color? accentColor;
  final Color? scaffoldBg;
  final Color? textColor;
  final Color? textDim;

  const NudgeThemeExtension({
    this.cardBg,
    this.cardBorder,
    this.cardRadius,
    this.cardBorderWidth,
    this.cardShadow,
    this.labelStyle,
    this.valueStyle,
    this.cardTransform,
    this.showScanlines,
    this.accentColor,
    this.scaffoldBg,
    this.textColor,
    this.textDim,
  });

  BoxDecoration cardDecoration(BuildContext context) {
    return BoxDecoration(
      color: cardBg,
      borderRadius: BorderRadius.circular(cardRadius ?? 20),
      border: cardBorder != null 
          ? Border.all(color: cardBorder!, width: cardBorderWidth ?? 1)
          : null,
      boxShadow: cardShadow,
    );
  }

  @override
  NudgeThemeExtension copyWith({
    Color? cardBg,
    Color? cardBorder,
    double? cardRadius,
    double? cardBorderWidth,
    List<BoxShadow>? cardShadow,
    TextStyle? labelStyle,
    TextStyle? valueStyle,
    Matrix4? cardTransform,
    bool? showScanlines,
    Color? accentColor,
    Color? scaffoldBg,
    Color? textColor,
    Color? textDim,
  }) {
    return NudgeThemeExtension(
      cardBg: cardBg ?? this.cardBg,
      cardBorder: cardBorder ?? this.cardBorder,
      cardRadius: cardRadius ?? this.cardRadius,
      cardBorderWidth: cardBorderWidth ?? this.cardBorderWidth,
      cardShadow: cardShadow ?? this.cardShadow,
      labelStyle: labelStyle ?? this.labelStyle,
      valueStyle: valueStyle ?? this.valueStyle,
      cardTransform: cardTransform ?? this.cardTransform,
      showScanlines: showScanlines ?? this.showScanlines,
      accentColor: accentColor ?? this.accentColor,
      scaffoldBg: scaffoldBg ?? this.scaffoldBg,
      textColor: textColor ?? this.textColor,
      textDim: textDim ?? this.textDim,
    );
  }

  @override
  NudgeThemeExtension lerp(ThemeExtension<NudgeThemeExtension>? other, double t) {
    if (other is! NudgeThemeExtension) return this;
    return NudgeThemeExtension(
      cardBg: Color.lerp(cardBg, other.cardBg, t),
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t),
      cardRadius: lerpDouble(cardRadius, other.cardRadius, t),
      cardBorderWidth: lerpDouble(cardBorderWidth, other.cardBorderWidth, t),
      cardShadow: other.cardShadow,
      labelStyle: TextStyle.lerp(labelStyle, other.labelStyle, t),
      valueStyle: TextStyle.lerp(valueStyle, other.valueStyle, t),
      cardTransform: other.cardTransform,
      showScanlines: other.showScanlines,
      accentColor: Color.lerp(accentColor, other.accentColor, t),
      scaffoldBg: Color.lerp(scaffoldBg, other.scaffoldBg, t),
      textColor: Color.lerp(textColor, other.textColor, t),
      textDim: Color.lerp(textDim, other.textDim, t),
    );
  }

  static double? lerpDouble(double? a, double? b, double t) {
    if (a == null && b == null) return null;
    return (a ?? 0) + ((b ?? 0) - (a ?? 0)) * t;
  }
}
