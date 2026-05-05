import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../models/progress_model.dart';
import '../widgets/common_widgets.dart';

/// Экран подтверждения повторного прохождения уже завершённого модуля.
///
/// Открывается с главного экрана при тапе на карточку модуля,
/// для которого `progress.isModuleCompleted(moduleId) == true`.
/// Защищает ребёнка от неожиданного «отката» уже пройденного
/// материала — для детей с РАС обнуление видимого результата
/// без явного согласия может быть стрессом.
///
/// «Пройти снова» делает `pushReplacement` на сам модуль (а не push),
/// чтобы кнопка «назад» из модуля вернула сразу на главный, а не на
/// этот экран.
class ModuleRestartScreen extends StatelessWidget {
  /// ID модуля: `module1` / `module2` / `module3`.
  final String moduleId;

  const ModuleRestartScreen({super.key, required this.moduleId});

  /// Метаданные модуля для отрисовки шапки. Дублируют названия
  /// и иконки с главного экрана — отдельный источник правды
  /// можно завести при появлении 4-го модуля.
  static const _meta = {
    'module1': _ModuleMeta(
      icon: '🔍',
      title: 'Знакомство',
      color: AppTheme.blue,
      lightColor: AppTheme.blueLight,
    ),
    'module2': _ModuleMeta(
      icon: '🧩',
      title: 'Конструктор',
      color: AppTheme.green,
      lightColor: AppTheme.greenLight,
    ),
    'module3': _ModuleMeta(
      icon: '📖',
      title: 'Эмоции в ситуации',
      color: AppTheme.purple,
      lightColor: AppTheme.purpleLight,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final meta = _meta[moduleId] ?? _meta['module1']!;
    final progress = context.watch<ProgressModel>();
    final correct = progress.correctInModule(moduleId);
    final total = progress.totalInModule(moduleId);
    final pct = total == 0 ? 0 : ((correct / total) * 100).round();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppTheme.cardShadow,
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(meta.title),
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          padding: EdgeInsets.symmetric(
            horizontal: context.gutter,
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const HelperCat(
                message: 'Ты уже прошёл этот модуль! '
                    'Хочешь пройти его ещё раз?',
              ),
              const SizedBox(height: 20),
              _buildModuleHeader(context, meta),
              const SizedBox(height: 16),
              if (total > 0) _buildResultCard(context, correct, total, pct),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await context
                        .read<ProgressModel>()
                        .resetModule(moduleId);
                    if (!context.mounted) return;
                    context.pushReplacement('/$moduleId');
                  },
                  child: const Text('Пройти снова'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => context.pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textMuted,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    'Вернуться',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.textMuted,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModuleHeader(BuildContext context, _ModuleMeta meta) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: AppTheme.green.withValues(alpha: 0.55),
          width: 2,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppTheme.greenLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Text(
                '✓',
                style: TextStyle(
                  fontSize: 28,
                  color: AppTheme.green,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(meta.title,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 2),
                Text(
                  'Модуль завершён',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.green,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(
      BuildContext context, int correct, int total, int pct) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.blueLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: const Color(0xFFD4E5F7), width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Твой результат',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$correct из $total',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.blue,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Text(
              '$pct%',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleMeta {
  final String icon;
  final String title;
  final Color color;
  final Color lightColor;
  const _ModuleMeta({
    required this.icon,
    required this.title,
    required this.color,
    required this.lightColor,
  });
}
