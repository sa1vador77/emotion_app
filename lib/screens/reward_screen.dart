import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../widgets/common_widgets.dart';

/// Экран-награда после завершения обучающего модуля.
///
/// Показывается через `pushReplacement` (см. `advanceTask` в
/// [ModuleTaskMixin]), чтобы кнопка «назад» не возвращала в
/// только что пройденный модуль.
///
/// Подкрепление через **положительное закрытие** активности
/// особенно важно для детей с РАС: чёткое визуальное и
/// эмоциональное завершение задачи помогает сформировать
/// ощущение успеха и мотивацию к следующему модулю.
class RewardScreen extends StatelessWidget {
  /// ID модуля, из которого пришли (`module1`/`module2`/`module3`).
  /// Передаётся через `extra` параметр GoRouter.
  final String from;

  const RewardScreen({
    super.key,
    required this.from,
  });

  /// Человекочитаемое название модуля для отображения в поздравлении.
  /// `'Модуль'` — безопасный fallback на случай неизвестного ID.
  String get _moduleTitle {
    switch (from) {
      case 'module1': return 'Знакомство';
      case 'module2': return 'Конструктор';
      case 'module3': return 'Эмоции в ситуации';
      default: return 'Модуль';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ResponsiveContainer(
          padding: EdgeInsets.symmetric(
            horizontal: context.gutter + 8, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 72)),
              const SizedBox(height: 16),
              Text(
                'Молодец!',
                style: Theme.of(context).textTheme.displayLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Ты завершил модуль «$_moduleTitle»!\nАпельсин очень рад за тебя 🐱',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              const CompletionAnimation(),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  // context.go (не push) — заменяет всю историю,
                  // чтобы из главного нельзя было «вернуться» обратно
                  // на экран награды (бессмысленно).
                  onPressed: () => context.go('/'),
                  child: const Text('На главную 🏠'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
