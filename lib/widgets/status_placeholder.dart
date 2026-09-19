import 'package:flutter/material.dart';

/// 加载占位（spinner + 文案）。
class LoadingPlaceholder extends StatelessWidget {
  const LoadingPlaceholder({super.key, this.message = '加载中…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// 空态占位（图标 + 主文案 + 副文案）。
class EmptyPlaceholder extends StatelessWidget {
  const EmptyPlaceholder({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.hint,
  });

  final String message;
  final IconData icon;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: scheme.outlineVariant),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: scheme.onSurfaceVariant)),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(hint!,
                style: TextStyle(fontSize: 12, color: scheme.outlineVariant)),
          ],
        ],
      ),
    );
  }
}

/// 错误占位（图标 + 主文案 + 重试按钮）。
class ErrorPlaceholder extends StatelessWidget {
  const ErrorPlaceholder({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: scheme.error),
          const SizedBox(height: 12),
          Text(message),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ],
      ),
    );
  }
}
