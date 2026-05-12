import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../models/progress_model.dart';
import '../models/diagnostic_model.dart';
import '../models/emotion.dart';

/// Экран аналитики для педагога — три вкладки: обучение, диагностика, эмоции.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📈 Аналитика'),
        bottom: TabBar(
          controller: _tab,
          labelColor: AppTheme.blue,
          unselectedLabelColor: AppTheme.textMuted,
          indicatorColor: AppTheme.blue,
          tabs: const [
            Tab(text: 'Обучение'),
            Tab(text: 'Диагностика'),
            Tab(text: 'Эмоции'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _TrainingTab(),
          _DiagnosticTab(),
          _EmotionsTab(),
        ],
      ),
    );
  }
}

/// Вкладка «Обучение».
class _TrainingTab extends StatelessWidget {
  const _TrainingTab();

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressModel>();

    return ResponsiveContainer(
      padding: EdgeInsets.symmetric(
        horizontal: context.gutter, vertical: 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionHeader(title: 'Общая статистика'),
            const SizedBox(height: 8),
            _SummaryStatsCard(progress: progress),
          const SizedBox(height: 16),

          const _SectionHeader(title: 'Активность (последние 14 дней)'),
          const SizedBox(height: 8),
          _ActivityCard(progress: progress),
          const SizedBox(height: 16),

          const _SectionHeader(title: 'Прогресс по модулям'),
          const SizedBox(height: 8),
          _ModuleProgressCard(progress: progress),
          const SizedBox(height: 16),

          const _SectionHeader(title: 'Уровень адаптивной сложности'),
          const SizedBox(height: 8),
          _DifficultyCard(progress: progress),
          const SizedBox(height: 16),

          const _SectionHeader(title: 'Среднее время реакции'),
          const SizedBox(height: 8),
          _ReactionTimeCard(progress: progress),
          const SizedBox(height: 16),

          const _InfoCard(
            icon: '📘',
            title: 'О системе адаптивности',
            text:
                'Приложение использует метод лестницы (staircase method): '
                'при точности выше 85% сложность повышается, '
                'ниже 70% — снижается. '
                'Целевой диапазон: 75–85% верных ответов.',
          ),
          ],
        ),
      ),
    );
  }
}

/// Вкладка «Диагностика» — сравнение pre/post, основной результат исследования.
class _DiagnosticTab extends StatelessWidget {
  const _DiagnosticTab();

  @override
  Widget build(BuildContext context) {
    final diag = context.watch<DiagnosticModel>();

    if (!diag.hasPreTest && !diag.hasPostTest) {
      return const _EmptyState(
        icon: '🔬',
        message:
            'Диагностика ещё не проводилась.\n\nЗапустите «До обучения» с главного экрана.',
      );
    }

    return ResponsiveContainer(
      padding: EdgeInsets.symmetric(
        horizontal: context.gutter, vertical: 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DiagnosticSummaryCard(diag: diag),
            const SizedBox(height: 16),

          if (diag.hasBothTests) ...[
            const _SectionHeader(title: 'Динамика по эмоциям (до → после)'),
            const SizedBox(height: 8),
            _EmotionComparisonTable(diag: diag),
            const SizedBox(height: 16),

            const _SectionHeader(title: 'График точности'),
            const SizedBox(height: 8),
            _AccuracyBarChart(diag: diag),
            const SizedBox(height: 16),
          ],

          const _InfoCard(
            icon: '📊',
            title: 'Для статистической обработки',
            text:
                'Данные диагностики экспортируются в CSV '
                '(раздел «Результаты диагностики»). '
                'Для проверки гипотезы используется '
                'T-критерий Вилкоксона для связанных выборок. '
                'Критический уровень значимости: p ≤ 0,05.',
          ),
          ],
        ),
      ),
    );
  }
}

/// Вкладка «Эмоции».
class _EmotionsTab extends StatelessWidget {
  const _EmotionsTab();

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressModel>();
    const emotions = EmotionData.all;

    // Сортируем от худшей точности к лучшей — чтобы внимание
    // педагога сразу обращалось на проблемные эмоции.
    final sorted = [...emotions]..sort((a, b) =>
        progress.accuracyForEmotion(a.id)
            .compareTo(progress.accuracyForEmotion(b.id)));

    final hasData = emotions.any(
        (e) => (progress.accuracyForEmotion(e.id)) > 0);

    if (!hasData) {
      return const _EmptyState(
        icon: '😊',
        message:
            'Данных пока нет.\n\nЗапустите занятия в модулях чтобы здесь появилась статистика.',
      );
    }

    return ResponsiveContainer(
      padding: EdgeInsets.symmetric(
        horizontal: context.gutter, vertical: 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionHeader(title: 'Точность распознавания по эмоциям'),
            const SizedBox(height: 8),
          _card(
            context,
            child: Column(
              children: sorted.map((e) {
                final acc = progress.accuracyForEmotion(e.id);
                final pct = (acc * 100).round();
                final hasData = acc > 0;
                final barColor = !hasData
                    ? AppTheme.textLight
                    : pct >= 75
                        ? AppTheme.green
                        : pct >= 50
                            ? AppTheme.accent
                            : AppTheme.errorText;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(e.emoji,
                              style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(e.nameRu,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontSize: 15)),
                          ),
                          Text(
                            hasData ? '$pct%' : '—',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: barColor,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: hasData ? acc : 0,
                          minHeight: 10,
                          backgroundColor: const Color(0xFFE8F0FA),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(barColor),
                        ),
                      ),
                      if (!hasData)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text('Нет данных',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    fontSize: 11,
                                    color: AppTheme.textLight,
                                  )),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          const _SectionHeader(title: 'Матрица путаницы'),
          const SizedBox(height: 8),
          const _ConfusionMatrixCard(),
          const SizedBox(height: 16),

          const _SectionHeader(title: 'Рекомендации'),
          const SizedBox(height: 8),
          _RecommendationsCard(progress: progress),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// Переиспользуемые виджеты экрана аналитики
// ═════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) => Text(
        title,
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontSize: 15,
          color: AppTheme.textMuted,
        ),
      );
}

/// Функция, а не виджет: stateless-обёртка вокруг переданного [child].
Widget _card(BuildContext context, {required Widget child}) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.cardShadow,
      ),
      child: child,
    );

class _EmptyState extends StatelessWidget {
  final String icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: const TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textMuted,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}

class _InfoCard extends StatelessWidget {
  final String icon;
  final String title;
  final String text;
  const _InfoCard(
      {required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.blueLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
              color: const Color(0xFFB8D9F7), width: 1.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(text,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                            color: AppTheme.textMuted,
                            height: 1.5,
                            fontSize: 13,
                          )),
                ],
              ),
            ),
          ],
        ),
      );
}

/// Сводная статистика вкладки «Обучение»: дни, ответы, процент верных.
class _SummaryStatsCard extends StatelessWidget {
  final ProgressModel progress;
  const _SummaryStatsCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    final total = progress.totalAnswers;
    final correct = progress.totalCorrect;
    final pct = total > 0 ? (correct / total * 100).round() : 0;
    final days = progress.sessionLog.length;

    return _card(
      context,
      child: Row(
        children: [
          _stat(context, '🗓', '$days', 'дней занятий'),
          _divider(),
          _stat(context, '📝', '$total', 'ответов'),
          _divider(),
          _stat(context, '✅', '$pct%', 'верных'),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String icon, String value, String label) =>
      Expanded(
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(value,
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontSize: 24,
                      color: AppTheme.blue,
                    )),
            Text(label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                    ),
                textAlign: TextAlign.center),
          ],
        ),
      );

  Widget _divider() => Container(
        width: 1, height: 48,
        color: const Color(0xFFE8F0FA),
        margin: const EdgeInsets.symmetric(horizontal: 4),
      );
}

/// Карточка активности за последние 14 дней — столбчатая
/// диаграмма. Высота столбца пропорциональна количеству
/// ответов в этот день относительно максимума.
///
/// Сегодняшний день выделен оранжевым — помогает педагогу
/// мгновенно увидеть, занимался ли ребёнок сегодня.
class _ActivityCard extends StatelessWidget {
  final ProgressModel progress;
  const _ActivityCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    final log = progress.sessionLog;
    final today = DateTime.now();

    final days = List.generate(14, (i) {
      final d = today.subtract(Duration(days: 13 - i));
      final key = d.toIso8601String().substring(0, 10);
      return (date: d, count: log[key] ?? 0);
    });

    // Максимум по всем дням — для нормализации высоты столбцов.
    final maxCount = days.map((d) => d.count).fold(0, (a, b) => a > b ? a : b);

    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: days.map((d) {
              final isEmpty = d.count == 0;
              final ratio = maxCount > 0 ? d.count / maxCount : 0.0;
              // Пустые дни — низкая полоска, иначе — пропорционально
              // (минимум 8px чтобы было видно).
              final barH = isEmpty ? 6.0 : (8 + ratio * 42).clamp(8.0, 50.0);
              final isToday = d.date.day == today.day &&
                  d.date.month == today.month;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        width: double.infinity,
                        height: barH,
                        decoration: BoxDecoration(
                          color: isEmpty
                              ? const Color(0xFFE8F0FA)
                              : isToday
                                  ? AppTheme.accent
                                  : AppTheme.blue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${d.date.day}',
                        style: TextStyle(
                          fontSize: 9,
                          color: isToday
                              ? AppTheme.accent
                              : AppTheme.textLight,
                          fontWeight: isToday
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text(
            maxCount == 0
                ? 'Занятий пока не было'
                : 'Высота столбца — количество ответов за день',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 11,
                  color: AppTheme.textLight,
                ),
          ),
        ],
      ),
    );
  }
}

class _ModuleProgressCard extends StatelessWidget {
  final ProgressModel progress;
  const _ModuleProgressCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    final modules = [
      ('module1', '🔍', 'Знакомство'),
      ('module2', '🧩', 'Конструктор'),
      ('module3', '📖', 'Ситуации'),
    ];

    return _card(
      context,
      child: Column(
        children: modules.map((m) {
          final val = progress.moduleProgress[m.$1] ?? 0.0;
          final pct = (val * 100).round();
          final ms = progress.timeByModule[m.$1] ?? 0;
          // Округляем до минут. Для коротких заходов (<60c) показываем
          // «<1 мин» вместо «0 мин» — иначе педагог думал бы, что
          // данных вообще нет, хотя ребёнок успел ответить пару раз.
          final timeLabel = ms == 0
              ? null
              : (ms < 60000 ? '<1 мин' : '${ms ~/ 60000} мин');
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Text(m.$2, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(m.$3,
                          style: Theme.of(context).textTheme.bodyMedium),
                      // Подзаголовок с суммарным временем — показываем
                      // только если ребёнок уже был в модуле. Иначе
                      // строка-плейсхолдер съедала бы вертикальное место.
                      if (timeLabel != null)
                        Text(timeLabel,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                  color: AppTheme.textLight,
                                )),
                    ],
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: val,
                      minHeight: 10,
                      backgroundColor: const Color(0xFFE8F0FA),
                      valueColor: AlwaysStoppedAnimation<Color>(
                          // Зелёный при 100% — отмечает завершение.
                          pct == 100 ? AppTheme.green : AppTheme.blue),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  // 44 dp вместо 36 — «100%» в bodyMedium w700 не помещается
                  // в 36 dp и переносит «%» на вторую строку.
                  width: 44,
                  child: Text('$pct%',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.blue,
                          ),
                      textAlign: TextAlign.right),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Текущая адаптивная сложность (1–5) по каждому модулю.
class _DifficultyCard extends StatelessWidget {
  final ProgressModel progress;
  const _DifficultyCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    final modules = [
      ('module1', '🔍', 'Знакомство'),
      ('module2', '🧩', 'Конструктор'),
      ('module3', '📖', 'Ситуации'),
    ];

    // Текстовые ярлыки уровней (индекс 0 не используется — сложность 1-based).
    final labels = ['', 'Лёгкий', 'Ниже среднего', 'Средний',
        'Выше среднего', 'Сложный'];

    return _card(
      context,
      child: Column(
        children: modules.map((m) {
          final d = progress.difficulty[m.$1] ?? 1;
          final label = labels[d.clamp(1, 5)];
          final color = d <= 2
              ? AppTheme.green
              : d <= 3
                  ? AppTheme.accent
                  : AppTheme.blue;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Text(m.$2, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(m.$3,
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
                Row(
                  children: List.generate(5, (i) => Container(
                    width: 10, height: 20,
                    margin: const EdgeInsets.only(right: 3),
                    decoration: BoxDecoration(
                      color: i < d ? color : const Color(0xFFE8F0FA),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  )),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: Text(label,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                            fontSize: 12,
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                      textAlign: TextAlign.right),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Карточка времени реакции — общий показатель и разбивка
/// по модулям. Цвет значения сигнализирует норму:
/// < 3с зелёный, < 6с оранжевый, иначе красный.
class _ReactionTimeCard extends StatelessWidget {
  final ProgressModel progress;
  const _ReactionTimeCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    final avgMs = progress.avgReactionTime;
    final avgSec = avgMs > 0 ? (avgMs / 1000).toStringAsFixed(1) : '—';
    final byModule = progress.avgReactionByModule;

    final modules = [
      ('module1', '🔍', 'Знакомство'),
      ('module2', '🧩', 'Конструктор'),
      ('module3', '📖', 'Ситуации'),
    ];

    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: const BoxDecoration(
                  color: AppTheme.blueLight,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                    child: Text('⏱', style: TextStyle(fontSize: 24))),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$avgSec с',
                      style: Theme.of(context)
                          .textTheme
                          .displayMedium
                          ?.copyWith(color: AppTheme.blue)),
                  Text('среднее по всем модулям',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppTheme.textMuted, fontSize: 12)),
                ],
              ),
            ],
          ),
          if (byModule.isNotEmpty) ...[
            const Divider(height: 20),
            ...modules.map((m) {
              final ms = byModule[m.$1];
              if (ms == null) return const SizedBox.shrink();
              final sec = (ms / 1000).toStringAsFixed(1);
              final color = ms < 3000
                  ? AppTheme.green
                  : ms < 6000
                      ? AppTheme.accent
                      : AppTheme.errorText;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Text(m.$2, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(m.$3,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ),
                    Text('$sec с',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: color,
                            )),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _DiagnosticSummaryCard extends StatelessWidget {
  final DiagnosticModel diag;
  const _DiagnosticSummaryCard({required this.diag});

  @override
  Widget build(BuildContext context) {
    final pre = diag.preSession;
    final post = diag.postSession;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _phaseCol(context, 'До обучения',
                  pre != null ? '${(pre.accuracy * 100).round()}%' : '—',
                  pre != null ? AppTheme.blue : AppTheme.textLight,
                  pre?.date)),
              Container(width: 1, height: 60, color: const Color(0xFFE8F0FA)),
              Expanded(child: _phaseCol(context, 'После обучения',
                  post != null ? '${(post.accuracy * 100).round()}%' : '—',
                  post != null ? AppTheme.blue : AppTheme.textLight,
                  post?.date)),
            ],
          ),
          if (diag.hasBothTests) ...[
            const Divider(height: 20),
            _deltaRow(context, pre!, post!),
          ],
        ],
      ),
    );
  }

  Widget _phaseCol(BuildContext context, String label, String value,
      Color color, DateTime? date) =>
      Column(
        children: [
          Text(label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textMuted, fontSize: 12,
              )),
          const SizedBox(height: 4),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .displayMedium
                  ?.copyWith(color: color, fontSize: 36)),
          if (date != null)
            Text(
              '${date.day.toString().padLeft(2, '0')}.'
              '${date.month.toString().padLeft(2, '0')}.'
              '${date.year}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 11, color: AppTheme.textLight,
              ),
            ),
        ],
      );

  /// Wrap — чтобы строка дельты переносилась на узких экранах.
  Widget _deltaRow(BuildContext context,
      DiagnosticSession pre, DiagnosticSession post) {
    final diff = post.accuracy - pre.accuracy;
    final diffPct = (diff * 100).round();
    final improved = diff > 0;
    final color =
        improved ? AppTheme.green : (diff < 0 ? AppTheme.errorText : AppTheme.textMuted);
    final arrow = improved ? '▲' : (diff < 0 ? '▼' : '=');

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        Text('Динамика: ',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textMuted,
            )),
        Text(
          '$arrow ${diffPct > 0 ? '+' : ''}$diffPct%',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: color, fontSize: 18,
          ),
        ),
        Text('Время: ',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textMuted,
            )),
        Text(
          '${(pre.avgReactionMs / 1000).toStringAsFixed(1)}с → '
          '${(post.avgReactionMs / 1000).toStringAsFixed(1)}с',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Сравнение pre/post по эмоциям; цвет Δ выделяет улучшения и ухудшения.
class _EmotionComparisonTable extends StatelessWidget {
  final DiagnosticModel diag;
  const _EmotionComparisonTable({required this.diag});

  @override
  Widget build(BuildContext context) {
    const emotions = EmotionData.all;
    final pre = diag.preSession!;
    final post = diag.postSession!;

    return _card(
      context,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const Expanded(flex: 3, child: SizedBox()),
                Expanded(
                  flex: 2,
                  child: Text('До',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center),
                ),
                Expanded(
                  flex: 2,
                  child: Text('После',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.blue,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Δ',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),
          ...emotions.map((e) {
            final preAcc = pre.accuracyForEmotion(e.id);
            final postAcc = post.accuracyForEmotion(e.id);
            final delta = postAcc - preAcc;
            final deltaPct = (delta * 100).round();
            final deltaColor = deltaPct > 0
                ? AppTheme.green
                : deltaPct < 0
                    ? AppTheme.errorText
                    : AppTheme.textMuted;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        Text(e.emoji,
                            style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(e.nameRu,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${(preAcc * 100).round()}%',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppTheme.textMuted),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${(postAcc * 100).round()}%',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                            color: AppTheme.blue,
                            fontWeight: FontWeight.w700,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${deltaPct >= 0 ? '+' : ''}$deltaPct%',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                            color: deltaColor,
                            fontWeight: FontWeight.w700,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Парный столбчатый график точности pre/post по эмоциям.
class _AccuracyBarChart extends StatelessWidget {
  final DiagnosticModel diag;
  const _AccuracyBarChart({required this.diag});

  @override
  Widget build(BuildContext context) {
    final pre = diag.preSession!;
    final post = diag.postSession!;
    const emotions = EmotionData.all;

    return _card(
      context,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(AppTheme.textMuted), const SizedBox(width: 4),
              Text('До', style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppTheme.textMuted, fontSize: 12)),
              const SizedBox(width: 16),
              _legendDot(AppTheme.blue), const SizedBox(width: 4),
              Text('После', style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppTheme.blue, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),

          // ClipRect защищает от выхода столбцов за границу при
          // высоких значениях.
          ClipRect(
            child: SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: emotions.map((e) {
                final preVal = pre.accuracyForEmotion(e.id);
                final postVal = post.accuracyForEmotion(e.id);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _bar(preVal, AppTheme.textLight, 110),
                            const SizedBox(width: 2),
                            _bar(postVal, AppTheme.blue, 110),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(e.emoji,
                            style: const TextStyle(fontSize: 14),
                            textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          ),

          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['0%', '25%', '50%', '75%', '100%']
                .map((l) => Text(l,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 10, color: AppTheme.textLight,
                    )))
                .toList(),
          ),
        ],
      ),
    );
  }

  /// Один столбец графика. Высота clamp'ится в [4; maxH],
  /// чтобы нулевое значение всё равно было видно (4px).
  Widget _bar(double value, Color color, double maxH) => Container(
        width: 14,
        height: (value * maxH).clamp(4.0, maxH),
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        ),
      );

  Widget _legendDot(Color color) => Container(
        width: 12, height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

/// Топ-3 эмоций с самой низкой точностью.
class _RecommendationsCard extends StatelessWidget {
  final ProgressModel progress;
  const _RecommendationsCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    final weak = progress.weakEmotions.take(3).toList();

    if (weak.isEmpty) {
      return const _InfoCard(
        icon: '✅',
        title: 'Данных для рекомендаций пока нет',
        text: 'После нескольких занятий здесь появятся конкретные советы.',
      );
    }

    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Требует дополнительной работы:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textMuted, fontSize: 12,
                ),
          ),
          const SizedBox(height: 10),
          ...weak.map((entry) {
            final emotion = EmotionData.getById(entry.key);
            final pct = (entry.value * 100).round();
            final color = pct < 50 ? AppTheme.errorText : AppTheme.accent;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(emotion.emoji,
                      style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(emotion.nameRu,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontSize: 15)),
                            const Spacer(),
                            Text('$pct%',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: color,
                                      fontWeight: FontWeight.w700,
                                    )),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: entry.value,
                            minHeight: 6,
                            backgroundColor: const Color(0xFFE8F0FA),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          emotion.description,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                                height: 1.4,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Источник данных для [_ConfusionMatrixCard]. Отдельный enum,
/// потому что переключатель должен помнить выбор между rebuild'ами,
/// и `String`-ключами было бы хрупко.
enum _ConfusionSource { training, diagPre, diagPost }

/// Карточка матрицы путаницы 6×6 с переключателем источника.
///
/// Строки — целевая эмоция (что должно было быть распознано),
/// столбцы — выбранная (что выбрал ребёнок). Диагональ
/// (target == selected) = правильные ответы, окрашена зелёным
/// градиентом; ошибки — розовым. Интенсивность цвета
/// пропорциональна доле от строки (row-normalized) — стандартный
/// способ визуализации confusion matrix в ML/психометрии.
///
/// Источники переключаются между обучением и двумя фазами
/// диагностики, потому что в каждом источнике своя картина:
/// в обучении больше данных (десятки/сотни ответов), в диагностике
/// — чище условия (фиксированный набор стимулов, одинаковый для всех).
class _ConfusionMatrixCard extends StatefulWidget {
  const _ConfusionMatrixCard();

  @override
  State<_ConfusionMatrixCard> createState() => _ConfusionMatrixCardState();
}

class _ConfusionMatrixCardState extends State<_ConfusionMatrixCard> {
  _ConfusionSource _source = _ConfusionSource.training;

  Map<String, Map<String, int>> _matrixForSource(BuildContext context) {
    final progress = context.watch<ProgressModel>();
    final diag = context.watch<DiagnosticModel>();
    return switch (_source) {
      _ConfusionSource.training => progress.confusionMatrixForModule(),
      _ConfusionSource.diagPre => diag.confusionMatrix(phase: 'pre'),
      _ConfusionSource.diagPost => diag.confusionMatrix(phase: 'post'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final matrix = _matrixForSource(context);
    final hasData =
        matrix.values.any((row) => row.values.any((c) => c > 0));

    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSourceSelector(context),
          const SizedBox(height: 12),
          if (!hasData)
            _buildEmptyHint(context)
          else ...[
            _buildGrid(context, matrix),
            const SizedBox(height: 8),
            _buildLegend(context),
            const SizedBox(height: 4),
            Text(
              'Строки — что показывалось, столбцы — что выбрал ребёнок. '
              'Интенсивность цвета — доля от всех ответов по строке.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 11,
                    color: AppTheme.textLight,
                    height: 1.4,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  /// Сегментный переключатель источника матрицы. На узких экранах
  /// длинные подписи вроде «Диагностика (до)» съели бы строку —
  /// поэтому компактные «Обучение / Тест: до / Тест: после».
  Widget _buildSourceSelector(BuildContext context) {
    const items = [
      (_ConfusionSource.training, 'Обучение'),
      (_ConfusionSource.diagPre, 'Тест: до'),
      (_ConfusionSource.diagPost, 'Тест: после'),
    ];
    return Row(
      children: items.map((entry) {
        final selected = _source == entry.$1;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: GestureDetector(
              onTap: () => setState(() => _source = entry.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.blue : AppTheme.bgSecondary,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                    color: selected
                        ? AppTheme.blue
                        : const Color(0xFFD4E5F7),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  entry.$2,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                        color: selected ? Colors.white : AppTheme.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Пустое сообщение под выбранный источник. Текст конкретнее
  /// общего «нет данных» — помогает педагогу понять, что нужно
  /// сделать, чтобы матрица появилась.
  Widget _buildEmptyHint(BuildContext context) {
    final text = switch (_source) {
      _ConfusionSource.training =>
        'Здесь появится матрица путаниц после ответов в обучающих модулях.',
      _ConfusionSource.diagPre =>
        'Констатирующий этап ещё не пройден.',
      _ConfusionSource.diagPost =>
        'Контрольный этап ещё не пройден.',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textMuted,
              fontSize: 13,
            ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Собственно сетка 6×6 с заголовками. [Table] выбран потому,
  /// что даёт идеальное вертикальное выравнивание строк и колонок
  /// автоматически — без него на разной длине эмодзи строки
  /// «съезжали» бы по высоте.
  Widget _buildGrid(
      BuildContext context, Map<String, Map<String, int>> matrix) {
    const emotions = EmotionData.all;

    return Table(
      defaultColumnWidth: const FlexColumnWidth(1),
      columnWidths: const {
        // Первая колонка под левый заголовок строк — фиксированная
        // ширина под эмодзи + минимальный отступ.
        0: FixedColumnWidth(28),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            const SizedBox(height: 28),
            ...emotions.map((e) => _buildHeaderCell(e.emoji)),
          ],
        ),
        ...emotions.map((target) {
          final row = matrix[target.id] ?? const {};
          final rowTotal = row.values.fold<int>(0, (a, b) => a + b);
          return TableRow(
            children: [
              _buildHeaderCell(target.emoji),
              ...emotions.map((selected) {
                final count = row[selected.id] ?? 0;
                return _buildDataCell(
                  count: count,
                  rowTotal: rowTotal,
                  isDiagonal: target.id == selected.id,
                );
              }),
            ],
          );
        }),
      ],
    );
  }

  /// Ячейка заголовка: только эмодзи. Имена эмоций не помещаются
  /// в узкие колонки на телефоне, а emoji универсально читается.
  Widget _buildHeaderCell(String emoji) => SizedBox(
        height: 32,
        child: Center(child: Text(emoji, style: const TextStyle(fontSize: 18))),
      );

  Widget _buildDataCell({
    required int count,
    required int rowTotal,
    required bool isDiagonal,
  }) {
    final intensity = rowTotal > 0 ? (count / rowTotal).clamp(0.0, 1.0) : 0.0;
    // Базовая палитра: зелёная диагональ = правильно, розовая
    // вне диагонали = ошибки. Прозрачность 0.12–0.65 даёт видимую
    // градацию, не теряя контраста с текстом.
    final base = isDiagonal ? AppTheme.green : AppTheme.errorText;
    final bg = count == 0
        ? Colors.transparent
        : base.withValues(alpha: 0.12 + intensity * 0.53);

    return Container(
      height: 32,
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFFE8F0FA),
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        count == 0 ? '·' : '$count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: count == 0 ? FontWeight.w400 : FontWeight.w700,
          color: count == 0
              ? AppTheme.textLight
              : (intensity > 0.5 ? Colors.white : AppTheme.textPrimary),
        ),
      ),
    );
  }

  /// Подпись к шкале цвета. Без неё педагог не может интерпретировать
  /// градиент: «густой розовый — это много путаниц или вообще
  /// диагональ?».
  Widget _buildLegend(BuildContext context) {
    Widget swatch(Color base) => Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: base.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(3),
          ),
        );
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: 11,
          color: AppTheme.textMuted,
        );
    return Row(
      children: [
        swatch(AppTheme.green),
        const SizedBox(width: 4),
        Text('правильно', style: style),
        const SizedBox(width: 12),
        swatch(AppTheme.errorText),
        const SizedBox(width: 4),
        Text('ошибка', style: style),
      ],
    );
  }
}
