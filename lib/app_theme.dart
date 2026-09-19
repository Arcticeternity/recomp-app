import 'package:flutter/material.dart';

/// 一套应用主题：配色种子 + 明暗。
class AppThemeDef {
  const AppThemeDef({
    required this.id,
    required this.label,
    required this.seed,
    required this.brightness,
  });

  final String id;
  final String label;
  final Color seed;
  final Brightness brightness;
}

/// 预置主题集合（浅/深/暖/冷）。
const List<AppThemeDef> appThemes = [
  AppThemeDef(
      id: 'forest',
      label: '森绿',
      seed: Color(0xFF1B5E20),
      brightness: Brightness.light),
  AppThemeDef(
      id: 'forestDark',
      label: '森绿·深',
      seed: Color(0xFF1B5E20),
      brightness: Brightness.dark),
  AppThemeDef(
      id: 'ocean',
      label: '海洋蓝',
      seed: Color(0xFF1565C0),
      brightness: Brightness.light),
  AppThemeDef(
      id: 'sunset',
      label: '暖阳橙',
      seed: Color(0xFFE65100),
      brightness: Brightness.light),
  AppThemeDef(
      id: 'rose',
      label: '玫瑰粉',
      seed: Color(0xFFAD1457),
      brightness: Brightness.light),
  AppThemeDef(
      id: 'slate',
      label: '石墨灰',
      seed: Color(0xFF455A64),
      brightness: Brightness.dark),
  AppThemeDef(
      id: 'practicebook',
      label: '深色练习簿',
      seed: Color(0xFF0E0F11),
      brightness: Brightness.dark),
];

/// 按 id 找主题；找不到返回默认（第一套）。
AppThemeDef themeById(String? id) =>
    appThemes.firstWhere((t) => t.id == id, orElse: () => appThemes.first);

/// 三宏量语义色。
///
/// 「练习簿」主题的 primary 是近白色 (#F2F1ED)，而今日页的进度条画在
/// primary 背景上 —— 固定用 Colors.lightBlueAccent 这类亮色会直接看不见。
/// 因此按**背景亮度**取色：亮底用 700 深调，暗底用 200 浅调（对比度 ≥ 4.5:1）。
@immutable
class MacroColors {
  const MacroColors({
    required this.carbs,
    required this.protein,
    required this.fat,
  });

  final Color carbs;
  final Color protein;
  final Color fat;
}

/// 页面主色背景（今日页 header、卡片强调区）上的宏量配色。
MacroColors macroColorsOnBackground(Brightness background) =>
    background == Brightness.dark
        ? const MacroColors(
            carbs: Color(0xFF81D4FA),
            protein: Color(0xFFA5D6A7),
            fat: Color(0xFFFFCC80),
          )
        : const MacroColors(
            carbs: Color(0xFF0277BD),
            protein: Color(0xFF2E7D32),
            fat: Color(0xFFEF6C00),
          );

/// 普通页面背景（surface）上的宏量配色。
MacroColors macroColorsOnSurface(Brightness surface) =>
    surface == Brightness.dark
        ? const MacroColors(
            carbs: Color(0xFF4FC3F7),
            protein: Color(0xFF66BB6A),
            fat: Color(0xFFFFA726),
          )
        : const MacroColors(
            carbs: Color(0xFF0277BD),
            protein: Color(0xFF2E7D32),
            fat: Color(0xFFEF6C00),
          );

/// 状态语义色：摄入是否超标（替代散落的 Colors.red / Colors.green）。
@immutable
class StatusColors {
  const StatusColors({required this.over, required this.onTrack});

  /// 超出目标。
  final Color over;

  /// 在目标内。
  final Color onTrack;
}

StatusColors statusColorsFor(Brightness brightness) =>
    brightness == Brightness.dark
        ? const StatusColors(
            over: Color(0xFFEF9A9A),
            onTrack: Color(0xFFA5D6A7),
          )
        : const StatusColors(
            over: Color(0xFFC62828),
            onTrack: Color(0xFF2E7D32),
          );
