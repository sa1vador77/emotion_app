import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../models/diagnostic_model.dart';
import '../models/emotion.dart';

/// Экран результата диагностики. Виден и ребёнку (после pre) —
/// поэтому тексты выводов щадящие, без жёстких формулировок «плохо».
class DiagnosticResultScreen extends StatelessWidget {
  /// Текущая сессия (pre или post) — переданная через GoRouter extra.
  final DiagnosticSession session;

  final String phase;

  const DiagnosticResultScreen({
    super.key,
    required this.session,
    required this.phase,
  });

  @override
  Widget build(BuildContext context) {
    final diagModel = context.watch<DiagnosticModel>();
    final preSession = diagModel.preSession;
    final postSession = diagModel.postSession;

    return Scaffold(
      appBar: AppBar(
        // Убираем кнопку «назад» — путь вперёд только через
        // «На главную», чтобы не было соблазна перепройти
        // диагностику и испортить данные исследования.
        automaticallyImplyLeading: false,
        title: Text(
          phase == 'pre' ? 'Результаты: до' : 'Результаты: после',
        ),
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          padding: EdgeInsets.symmetric(
            horizontal: context.gutter, vertical: 16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildAccuracyCard(context, session),
                const SizedBox(height: 16),
                _buildEmotionBreakdown(context, session),
                const SizedBox(height: 16),
                if (diagModel.hasBothTests) ...[
                  _buildComparison(context, preSession!, postSession!),
                  const SizedBox(height: 16),
                ],
                ElevatedButton(
                  onPressed: () => context.go('/'),
                  child: const Text('На главную 🏠'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccuracyCard(BuildContext context, DiagnosticSession s) {
    final pct = (s.accuracy * 100).round();
    final color = pct >= 75
        ? AppTheme.green
        : pct >= 50
            ? AppTheme.accent
            : AppTheme.errorText;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          // Используем академический термин («констатирующий этап»)
          // — этот текст ориентирован на педагога, не ребёнка.
          Text(
            phase == 'pre' ? '📋 Констатирующий этап' : '📊 Контрольный этап',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            '$pct%',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: color,
                  fontSize: 56,
                ),
          ),
          Text(
            'точность распознавания',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _statChip(context, '⏱',
                  '${(s.avgReactionMs / 1000).toStringAsFixed(1)} с',
                  'среднее время'),
              _statChip(context, '✓',
                  '${s.answers.where((a) => a.isCorrect).length}', 'верных'),
              _statChip(context, '✗',
                  '${s.answers.where((a) => !a.isCorrect).length}', 'ошибок'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(
      BuildContext context, String icon, String value, String label) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: AppTheme.blue)),
        Text(label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w400,
                )),
      ],
    );
  }

  /// Точность по эмоциям — педагогу видно, какие эмоции требуют
  /// дополнительной работы.
  Widget _buildEmotionBreakdown(BuildContext context, DiagnosticSession s) {
    const emotions = EmotionData.all;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Точность по эмоциям',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          ...emotions.map((e) {
            final acc = s.accuracyForEmotion(e.id);
            final pct = (acc * 100).round();
            final barColor = pct >= 75
                ? AppTheme.green
                : pct >= 50
                    ? AppTheme.accent
                    : AppTheme.errorText;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Text(e.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                      flex: 3,
                      child: Text(e.nameRu,
                          style: Theme.of(context).textTheme.bodyMedium)),
                  Expanded(
                    flex: 5,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: acc,
                        minHeight: 12,
                        backgroundColor: const Color(0xFFE8F0FA),
                        valueColor: AlwaysStoppedAnimation<Color>(barColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    // 44 dp вместо 36 — «100%» в bodyMedium w700 не
                    // помещается в 36 dp и переносит «%» на вторую строку.
                    // Та же правка, что в analytics_screen._ModuleProgressCard.
                    width: 44,
                    child: Text(
                      '$pct%',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: barColor,
                          ),
                      textAlign: TextAlign.right,
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

  /// Сравнение «до → после» — основной результат исследования.
  /// Текстовый комментарий под цифрами щадящий: при отсутствии
  /// прогресса рекомендует продолжать занятия, а не констатирует неудачу.
  Widget _buildComparison(
    BuildContext context,
    DiagnosticSession pre,
    DiagnosticSession post,
  ) {
    final diff = post.accuracy - pre.accuracy;
    final diffPct = (diff.abs() * 100).round();
    final improved = diff > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: improved ? AppTheme.greenLight : AppTheme.blueLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: improved
              ? AppTheme.green.withValues(alpha: 0.4)
              : AppTheme.blue.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('📈 Динамика (до → после)',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color:
                        improved ? const Color(0xFF2A7A4A) : AppTheme.blue,
                  )),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _compCol(context, 'До',
                  '${(pre.accuracy * 100).round()}%', AppTheme.textMuted),
              Text(
                improved
                    ? '▲ +$diffPct%'
                    : (diff < 0 ? '▼ -$diffPct%' : '= 0%'),
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: improved ? AppTheme.green : AppTheme.errorText,
                      fontSize: 28,
                    ),
              ),
              _compCol(context, 'После',
                  '${(post.accuracy * 100).round()}%', AppTheme.blue),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            improved
                ? 'Наблюдается положительная динамика в развитии навыка распознавания эмоций.'
                : diff < 0
                    ? 'Снижение точности. Рекомендуется продолжить тренировочные занятия.'
                    : 'Точность не изменилась. Рекомендуется продолжить занятия.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textMuted,
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 8),
          // Время реакции — второй ключевой показатель.
          // Снижение времени даже при той же точности означает
          // автоматизацию навыка.
          Row(
            children: [
              Text('⏱ Время реакции: ',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppTheme.textMuted)),
              Text(
                '${(pre.avgReactionMs / 1000).toStringAsFixed(1)} с → '
                '${(post.avgReactionMs / 1000).toStringAsFixed(1)} с',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _compCol(
      BuildContext context, String label, String value, Color color) {
    return Column(
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.textMuted)),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .displayMedium
                ?.copyWith(color: color, fontSize: 32)),
      ],
    );
  }
}
