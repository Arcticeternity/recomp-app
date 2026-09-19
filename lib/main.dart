import 'dart:async';

import 'package:flutter/material.dart';

import 'app_state.dart';
import 'app_theme.dart';
import 'core/fitness/fitness_database.dart';
import 'core/food/local_food_database.dart';
import 'core/storage/app_repository.dart';
import 'core/storage/memory_app_repository.dart';
import 'core/storage/sqlite_app_repository.dart';
import 'pages/home_shell.dart';
import 'pages/onboarding_page.dart';

/// 启动步骤的预算上限。
///
/// 这些东西全部在 runApp() **之前**执行，任何一步卡死都会让应用永远停在
/// 白屏（Web 上尤其明显：WASM/IndexedDB 在移动浏览器里可能既慢又不报错）。
/// 因此每步都给上限，超时就走降级 —— 宁可功能降级，也不能白屏。
const _mainDbBudget = Duration(seconds: 5);
const _staticDbBudget = Duration(seconds: 6);
const _initStateBudget = Duration(seconds: 6);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final repo = await _openRepository();
  final foodDb = await _loadGuard(
    '食物成分表',
    LocalFoodDatabase.openFromAsset,
  );
  final fitnessDb = await _loadGuard(
    '健身数据',
    FitnessDatabase.openFromAsset,
  );

  final state = AppState(repo, localFoodDb: foodDb, fitnessDb: fitnessDb);
  try {
    await state.init().timeout(_initStateBudget);
  } on TimeoutException {
    debugPrint('[boot] state.init 超时，以空数据继续启动');
  }

  runApp(RecompApp(state: state));
}

/// 打开用户数据仓库；Web 上失败/超时则降级为纯内存仓库（本次会话可用）。
Future<AppRepository> _openRepository() async {
  try {
    return await SqliteAppRepository.openDefault().timeout(_mainDbBudget);
  } catch (e) {
    debugPrint('[boot] 本地数据库不可用（$e），降级为内存存储');
    return createMemoryRepository();
  }
}

/// 加载只读静态库；失败/超时返回 null（应用已有可空处理）。
Future<T?> _loadGuard<T>(String label, Future<T> Function() load) async {
  try {
    return await load().timeout(_staticDbBudget);
  } catch (e) {
    debugPrint('[boot] $label 加载失败（$e），该功能降级');
    return null;
  }
}

class RecompApp extends StatelessWidget {
  const RecompApp({super.key, required this.state});

  final AppState state;

  ThemeData _theme(AppThemeDef def) {
    final scheme = def.id == 'practicebook'
        ? _practicebookScheme()
        : ColorScheme.fromSeed(
            seedColor: def.seed,
            brightness: def.brightness,
          );

    // 全局按钮样式：无边框无底色 + 聚焦白色 outline + 按下涟漪反馈 + 150ms 过渡
    final baseButton = ButtonStyle(
      animationDuration: const Duration(milliseconds: 150),
      backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
      foregroundColor: WidgetStatePropertyAll(scheme.primary),
      elevation: const WidgetStatePropertyAll(0),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return scheme.primary.withValues(alpha: 0.12);
        }
        return Colors.transparent;
      }),
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.focused)) {
          return BorderSide(color: Colors.white, width: 1.5);
        }
        return BorderSide.none;
      }),
    );

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      // 中文正文行高默认约 1.2，长段落读起来挤。只放宽正文/辅助文字，
      // 标题保持紧凑，避免撑高既有布局。
      textTheme: _readableTextTheme(ThemeData(colorScheme: scheme).textTheme),
      // SnackBar 统一为悬浮圆角：贴底的手势条附近既不好看也难点。
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(style: baseButton),
      textButtonTheme: TextButtonThemeData(style: baseButton),
      outlinedButtonTheme: OutlinedButtonThemeData(style: baseButton),
      elevatedButtonTheme: ElevatedButtonThemeData(style: baseButton),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: scheme.primaryContainer,
      ),
    );
  }

  /// 中文可读性：正文行高 1.45、辅助文字 1.4。
  TextTheme _readableTextTheme(TextTheme base) => base.copyWith(
        bodyLarge: base.bodyLarge?.copyWith(height: 1.45),
        bodyMedium: base.bodyMedium?.copyWith(height: 1.45),
        bodySmall: base.bodySmall?.copyWith(height: 1.4),
        labelLarge: base.labelLarge?.copyWith(height: 1.4),
        labelMedium: base.labelMedium?.copyWith(height: 1.4),
      );

  /// 深色练习簿主题（仿原站配色）。
  ///
  /// surfaceContainer 系列必须按「数字越大越亮」排布（Material 3 约定），
  /// 否则卡片与弹层的层级会倒挂：原先 surfaceContainer(#202125) 比
  /// surfaceContainerHigh(#18191C) 还亮，弹层比卡片更暗，层级失去意义。
  ColorScheme _practicebookScheme() {
    return ColorScheme.dark().copyWith(
      surface: const Color(0xFF0E0F11),
      onSurface: const Color(0xFFF2F1ED),
      surfaceContainerLowest: const Color(0xFF0E0F11),
      surfaceContainerLow: const Color(0xFF141518),
      surfaceContainer: const Color(0xFF1B1C20),
      surfaceContainerHigh: const Color(0xFF1E1F23),
      surfaceContainerHighest: const Color(0xFF232428),
      onSurfaceVariant: const Color(0xFFA4A5AD),
      outline: const Color(0xFF2B2C31),
      outlineVariant: const Color(0xFF71727B),
      primary: const Color(0xFFF2F1ED),
      onPrimary: const Color(0xFF0E0F11),
      primaryContainer: const Color(0xFF202125),
      onPrimaryContainer: const Color(0xFFF2F1ED),
      secondary: const Color(0xFFA4A5AD),
      onSecondary: const Color(0xFF0E0F11),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => MaterialApp(
        title: '增肌减脂',
        theme: _theme(themeById(state.themeName)),
        scrollBehavior: const _AppScrollBehavior(),
        home: state.profile == null
            ? OnboardingPage(state: state)
            : HomeShell(state: state),
      ),
    );
  }
}

/// 全局滚动行为：iOS 回弹手感（BouncingScrollPhysics），替换 Android 默认硬停。
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
}
